import Cocoa
import FlutterMacOS

public class PointerLockPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pointer_lock", binaryMessenger: registrar.messenger)
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
