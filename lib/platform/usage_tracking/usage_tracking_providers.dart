import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics/analytics_providers.dart';
import '../../data/database/tempo_database.dart';
import '../../domain/tracking/tracking_status.dart';
import '../../domain/tracking/usage_tracking_service.dart';
import '../../features/onboarding/onboarding_controller.dart';
import '../../features/settings/preferences_controller.dart';
import 'usage_tracking_platform.dart';

/// The implementation for the machine Tempo is running on.
final Provider<UsageTrackingPlatform> usageTrackingPlatformProvider =
    Provider<UsageTrackingPlatform>(
      (Ref ref) => UsageTrackingPlatform.forThisDevice(),
    );

/// What this system requires before Tempo can measure. Windows and macOS both
/// answer "nothing"; the state is still read rather than assumed.
final FutureProvider<TrackingPermission> trackingPermissionProvider =
    FutureProvider<TrackingPermission>(
      (Ref ref) => ref.watch(usageTrackingPlatformProvider).permission(),
    );

/// The running engine.
///
/// The shell watches this, so measuring lasts exactly as long as the app is
/// open and whatever was being measured is written down on the way out.
/// Nothing starts until the first run has explained what is measured and
/// tracking has been left on.
final Provider<UsageTrackingService> usageTrackerProvider =
    Provider<UsageTrackingService>((Ref ref) {
      final TempoDatabase? database = ref.watch(databaseProvider);
      final UsageTrackingService service = UsageTrackingService(
        platform: ref.watch(usageTrackingPlatformProvider),
        usage: database?.usage,
        // Read rather than watched, so changing the timeout in Settings takes
        // effect on the next sample without restarting the engine.
        idleTimeout: () => ref.read(preferencesProvider).idleTimeout,
        onUsageChanged: () => ref.read(usageRevisionProvider.notifier).bump(),
        onStatusChanged: (TrackingStatus status) =>
            ref.read(trackingStatusProvider.notifier).set(status),
      );

      ref.onDispose(() => unawaited(service.dispose()));

      bool allowed() =>
          ref.read(onboardingCompletedProvider) &&
          ref.read(preferencesProvider).trackingEnabled;

      // Turning tracking on or off, or finishing the first run, reaches the
      // engine that is already there rather than building another one.
      ref.listen<bool>(
        preferencesProvider.select(
          (TempoPreferences value) => value.trackingEnabled,
        ),
        (bool? previous, bool next) {
          if (!ref.read(onboardingCompletedProvider)) {
            return;
          }
          unawaited(service.setEnabled(enabled: next));
        },
      );
      ref.listen<bool>(onboardingCompletedProvider, (
        bool? previous,
        bool next,
      ) {
        if (next && ref.read(preferencesProvider).trackingEnabled) {
          unawaited(service.start());
        }
      });

      // Started off this build, so the first status change never lands while
      // providers are still being created.
      Future<void>.microtask(() {
        if (allowed()) {
          return service.start();
        }
        // Tracking that was deliberately turned off reads as paused rather
        // than as something that never got going.
        if (ref.read(onboardingCompletedProvider) &&
            service.status != TrackingStatus.unavailable) {
          ref.read(trackingStatusProvider.notifier).set(TrackingStatus.paused);
        }
        return null;
      });
      return service;
    });
