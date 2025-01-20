import Cocoa
import FlutterMacOS

public class PointerLockPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Method channel
    let channel = FlutterMethodChannel(name: "pointer_lock", binaryMessenger: registrar.messenger)
    let instance = PointerLockPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    // Event channel
    let eventChannel = FlutterEventChannel(name: "pointer_lock_session", binaryMessenger: registrar.messenger)
    eventChannel.setStreamHandler(PointerLockSessionStreamHandler())
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "flutterRestart":
      CGAssociateMouseAndMouseCursorPosition(1)
      NSCursor.unhide()
      result(nil)
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
    case "lastPointerDelta":
      let (x, y) = CGGetLastMouseDelta()
      let list: [Double] = [Double(x), Double(y)];
      result(list)
    case "pointerPositionOnScreen":
      let point = NSEvent.mouseLocation
      let list: [Double] = [Double(point.x), Double(point.y)];
      result(list)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

class PointerLockSessionStreamHandler: NSObject, FlutterStreamHandler {
  private var monitor: Any?
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    CGAssociateMouseAndMouseCursorPosition(0)
    var unlockOnPointerUp = false
    if let arguments = arguments as? Bool {
        unlockOnPointerUp = arguments
    }
    monitor = NSEvent.addLocalMonitorForEvents(
      matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseUp, .rightMouseUp, .otherMouseUp]
    ) { event in
      if unlockOnPointerUp && [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(event.type) {
        events(FlutterEndOfEventStream)
        return event
      }
      let (x, y) = CGGetLastMouseDelta()
      let list: [Double] = [Double(x), Double(y)];
      list.withUnsafeBufferPointer { buffer in
        let data = Data(buffer: buffer)
        events(FlutterStandardTypedData(float64: data))
      }
      return event
    }
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    unlock()
    return nil
  }

  private func unlock() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
    CGAssociateMouseAndMouseCursorPosition(1)
    NSCursor.unhide()
  }

  deinit {
    unlock()
  }
}
