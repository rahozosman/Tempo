import Cocoa
import CoreGraphics
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Tempo's usage tracking channel. It answers two questions and reports
  /// three kinds of event, and nothing else: which application is frontmost,
  /// how long the machine has gone without input, and when the machine sleeps,
  /// wakes or locks.
  ///
  /// All of it comes from public APIs that need no permission — `NSWorkspace`
  /// for the frontmost application and for sleep and wake, `CGEventSource` for
  /// the idle timer, and the distributed notification centre for screen
  /// locking. Nothing reads window titles, documents or screen contents, and
  /// Apple's own Screen Time data is not accessible to applications at all.
  private static let channelName = "tempo/usage_tracking"

  /// Input the user actually makes. The shortest time since any of them is how
  /// long the machine has been untouched.
  private static let inputEvents: [CGEventType] = [
    .mouseMoved,
    .leftMouseDown,
    .leftMouseUp,
    .rightMouseDown,
    .rightMouseUp,
    .otherMouseDown,
    .scrollWheel,
    .keyDown,
    .keyUp,
    .flagsChanged,
  ]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: MainFlutterWindow.channelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "activeApplication":
        result(MainFlutterWindow.frontmostApplication())
      case "idleSeconds":
        result(MainFlutterWindow.idleSeconds())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    observeSystemEvents(reportingTo: channel)

    super.awakeFromNib()
  }

  /// The frontmost application, grouped by bundle identifier so every window
  /// of an application is one application.
  private static func frontmostApplication() -> [String: Any]? {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return nil
    }
    let identifier =
      app.bundleIdentifier
      ?? app.executableURL?.lastPathComponent
      ?? app.localizedName
    guard let id = identifier, !id.isEmpty else {
      return nil
    }

    var payload: [String: Any] = [
      "id": id,
      "name": app.localizedName ?? id,
    ]
    if let path = app.bundleURL?.path {
      payload["path"] = path
    }
    return payload
  }

  private static func idleSeconds() -> Double {
    let times = inputEvents.map {
      CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0)
    }
    return times.min() ?? 0
  }

  /// Sleep and wake come from the workspace; locking and unlocking are
  /// announced system-wide. Each one is forwarded to Dart so measurement stops
  /// at the moment it happens rather than at the next sample.
  private func observeSystemEvents(reportingTo channel: FlutterMethodChannel) {
    let workspace = NSWorkspace.shared.notificationCenter
    let forward: (String) -> Void = { event in
      channel.invokeMethod("systemEvent", arguments: event)
    }

    workspace.addObserver(
      forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
    ) { _ in forward("sleep") }
    workspace.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { _ in forward("wake") }
    workspace.addObserver(
      forName: NSWorkspace.sessionDidResignActiveNotification, object: nil,
      queue: .main
    ) { _ in forward("lock") }
    workspace.addObserver(
      forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil,
      queue: .main
    ) { _ in forward("unlock") }

    let distributed = DistributedNotificationCenter.default()
    distributed.addObserver(
      forName: Notification.Name("com.apple.screenIsLocked"), object: nil,
      queue: .main
    ) { _ in forward("lock") }
    distributed.addObserver(
      forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil,
      queue: .main
    ) { _ in forward("unlock") }
  }
}
