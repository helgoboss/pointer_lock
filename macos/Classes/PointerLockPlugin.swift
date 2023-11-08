import Cocoa
import FlutterMacOS

public class PointerLockPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    guard let flutterView = registrar.view else { return }
    guard let flutterWindow = flutterView.window else { return }

    let channel = FlutterMethodChannel(name: "pointer_lock", binaryMessenger: registrar.messenger)
    let sessionEventChannel = FlutterEventChannel(
      name: "pointer_lock_session",
      binaryMessenger: registrar.messenger
    )
    let sessionEventStreamHandler = SessionEventStreamHandler(window: flutterWindow)
    sessionEventChannel.setStreamHandler(sessionEventStreamHandler)
    let instance = PointerLockPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "lockPointer":
      CGAssociateMouseAndMouseCursorPosition(0)
      result(nil)
    case "unlockPointer":
      CGAssociateMouseAndMouseCursorPosition(1)
      result(nil)
    case "hidePointer":
      NSCursor.hide()
      result(nil)
    case "showPointer":
      NSCursor.unhide()
      result(nil)
    case "subscribeToRawInputData":
      // Not necessary on macOS. We can use CGGetLastMouseDelta() without any special preparations.
      result(nil)
    case "lastPointerDelta":
      let (x, y) = CGGetLastMouseDelta()
      let list: [Double] = [Double(x), Double(y)];
      result(list)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

class SessionEventStreamHandler: NSResponder, FlutterStreamHandler {
  private var window: NSWindow
  private var eventSink: FlutterEventSink?
  private var previousResponder: NSResponder?
  
  init(window: NSWindow) {
    self.window = window
    super.init()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    print("onListen")
    previousResponder = window.firstResponder
    window.makeFirstResponder(self)
    window.acceptsMouseMovedEvents = true
    window.ignoresMouseEvents = false
    eventSink = events
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    print("onCancel")
    window.makeFirstResponder(previousResponder)
    window.acceptsMouseMovedEvents = false
    previousResponder = nil
    eventSink = nil
    return nil
  }
  
  override func mouseMoved(with event: NSEvent) {
    print("mouseMoved")
    eventSink!("mouseMoved")
  }
  
  override func mouseDragged(with event: NSEvent) {
    print("mouseDragged")
    eventSink!("mouseDragged")
  }
  
  override func mouseDown(with event: NSEvent) {
    print("mouseDown")
    eventSink!("mouseDown")
  }
  
  override func mouseUp(with event: NSEvent) {
    print("mouseUp")
    eventSink!("mouseUp")
  }
  
  override func rightMouseDragged(with event: NSEvent) {
    print("rightMouseDragged")
    eventSink!("rightMouseDragged")
  }
  
  override func rightMouseUp(with event: NSEvent) {
    print("rightMouseUp")
    eventSink!("rightMouseUp")
  }
  
  override var acceptsFirstResponder: Bool {
    return true
  }
}
