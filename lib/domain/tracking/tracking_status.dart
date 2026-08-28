import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the usage tracking engine.
///
/// The engine itself arrives with the platform work; until then the shell
/// reports [notStarted] honestly rather than pretending to be running.
enum TrackingStatus {
  notStarted,
  active,
  paused,
  unavailable;

  String get title => switch (this) {
    TrackingStatus.notStarted => 'Tracking',
    TrackingStatus.active => 'Tracking',
    TrackingStatus.paused => 'Paused',
    TrackingStatus.unavailable => 'Tracking',
  };

  String get detail => switch (this) {
    TrackingStatus.notStarted => 'Not started yet',
    TrackingStatus.active => 'Recording activity',
    TrackingStatus.paused => 'Nothing is recorded',
    TrackingStatus.unavailable => 'Not available here',
  };

  bool get isLive => this == TrackingStatus.active;
}

class TrackingController extends Notifier<TrackingStatus> {
  @override
  TrackingStatus build() => TrackingStatus.notStarted;

  void set(TrackingStatus status) => state = status;

  void pause() {
    if (state == TrackingStatus.active) {
      state = TrackingStatus.paused;
    }
  }

  void resume() {
    if (state == TrackingStatus.paused) {
      state = TrackingStatus.active;
    }
  }
}

final NotifierProvider<TrackingController, TrackingStatus>
trackingStatusProvider =
    NotifierProvider<TrackingController, TrackingStatus>(
      TrackingController.new,
    );
