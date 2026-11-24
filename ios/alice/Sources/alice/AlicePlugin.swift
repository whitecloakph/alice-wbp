import Flutter
import UIKit

/// Forwards the iOS shake gesture (`UIEvent.EventSubtype.motionShake`) to Dart
/// on the `alice/shake` event channel. iOS reports a shake once per gesture,
/// on real devices and for the Simulator's Device > Shake, so Dart does not
/// need its own accelerometer threshold on iOS.
///
/// The gesture is observed through a `motionEnded(_:with:)` override on
/// `UIWindow` that posts a notification and then runs the implementation
/// UIWindow had before, with the original selector, so the event still goes
/// up the responder chain and the app's own responders see every event.
///
/// The override is installed only when Dart starts listening, which Alice
/// does only when it is active. An app that registers the plugin but never
/// creates Alice (for example a production build) leaves UIWindow untouched.
///
/// While Dart listens, iOS's shake-to-undo ("Undo Typing") is turned off so a
/// shake only means Alice; the app's previous setting comes back when Dart
/// stops listening.
public class AlicePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  /// The app's shake-to-undo setting before Alice listened; nil when not
  /// listening.
  private var savedShakeToEdit: Bool?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AlicePlugin()
    let control = FlutterMethodChannel(
      name: "alice/shake_control", binaryMessenger: registrar.messenger())
    control.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let events = FlutterEventChannel(
      name: "alice/shake", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    UIWindow.aliceInstallShakeHook()
    if savedShakeToEdit == nil {
      savedShakeToEdit = UIApplication.shared.applicationSupportsShakeToEdit
    }
    UIApplication.shared.applicationSupportsShakeToEdit = false
    if observer == nil {
      observer = NotificationCenter.default.addObserver(
        forName: .aliceDeviceShaken, object: nil, queue: .main
      ) { [weak self] _ in
        self?.eventSink?(nil)
      }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    if let saved = savedShakeToEdit {
      UIApplication.shared.applicationSupportsShakeToEdit = saved
    }
    savedShakeToEdit = nil
    return nil
  }
}

extension Notification.Name {
  static let aliceDeviceShaken = Notification.Name("AliceDeviceShaken")
}

extension UIWindow {
  private static var aliceShakeHookInstalled = false

  /// Installs the `motionEnded(_:with:)` override on `UIWindow` once.
  ///
  /// UIWindow normally inherits the method from UIResponder, whose
  /// implementation forwards the event to the next responder using the
  /// selector it was called with. So the override must keep the original
  /// selector: it calls the previous implementation directly with
  /// `motionEnded(_:with:)` instead of swapping selectors (a swap would make
  /// UIKit forward an unknown selector up the chain and crash).
  static func aliceInstallShakeHook() {
    guard !aliceShakeHookInstalled else { return }
    aliceShakeHookInstalled = true

    let selector = #selector(UIResponder.motionEnded(_:with:))
    // UIWindow's own override if it has one, otherwise UIResponder's.
    guard let previousMethod = class_getInstanceMethod(UIWindow.self, selector) else {
      return
    }
    typealias MotionEnded = @convention(c) (
      AnyObject, Selector, UIEvent.EventSubtype, UIEvent?
    ) -> Void
    let previous = unsafeBitCast(
      method_getImplementation(previousMethod), to: MotionEnded.self)

    let hook: @convention(block) (AnyObject, UIEvent.EventSubtype, UIEvent?) -> Void = {
      window, motion, event in
      if motion == .motionShake {
        NotificationCenter.default.post(name: .aliceDeviceShaken, object: nil)
      }
      previous(window, selector, motion, event)
    }
    let hookImplementation = imp_implementationWithBlock(hook)

    // Adds the override to UIWindow only; if UIWindow already has its own,
    // replaces that one (the previous implementation is still called).
    if !class_addMethod(
      UIWindow.self, selector, hookImplementation,
      method_getTypeEncoding(previousMethod))
    {
      method_setImplementation(previousMethod, hookImplementation)
    }
  }
}
