import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics/analytics_providers.dart';
import '../../data/database/settings_dao.dart';
import '../../data/database/tempo_database.dart';

/// Whether the person has been shown what Tempo measures.
///
/// Nothing is recorded before this is true: the first run explains the
/// measurement and asks, rather than starting quietly in the background.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(storedSettingsProvider)[SettingsKeys.onboardingCompleted] ==
      'true';

  void complete() {
    if (state) {
      return;
    }
    state = true;
    final TempoDatabase? database = ref.read(databaseProvider);
    if (database != null) {
      unawaited(
        database.settings.set(SettingsKeys.onboardingCompleted, 'true'),
      );
    }
  }
}

final NotifierProvider<OnboardingController, bool> onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
