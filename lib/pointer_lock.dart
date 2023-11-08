
import 'dart:ui';

import 'pointer_lock_platform_interface.dart';

class PointerLock {
  Future<void> lockPointer() {
    return PointerLockPlatform.instance.lockPointer();
  }

  Future<void> unlockPointer() {
    return PointerLockPlatform.instance.unlockPointer();
  }

  Future<void> hidePointer() {
    return PointerLockPlatform.instance.hidePointer();
  }

  Future<void> showPointer() {
    return PointerLockPlatform.instance.showPointer();
  }

  /// This should be called once in order to make [PointerLock.lastPointerDelta] work.
  ///
  /// This is necessary on Windows only. It will invoke the Win32 function `RegisterRawInputDevices` to make the
  /// Flutter window receive raw input events from the mouse device. It also sets up a `WindowProcDelegate` to read
  /// those events and extract the delta values.
  ///
  /// This is exposed as an explicit function because `RegisterRawInputDevices` comes with a caveat, which is best
  /// described by citing the Win32 API docs: "Only one window per raw input device class may be registered to receive
  /// raw input within a process (the window passed in the last call to RegisterRawInputDevices). Because of this,
  /// RegisterRawInputDevices should not be used from a library, as it may interfere with any raw input processing
  /// logic already present in applications that load it."
  Future<void> subscribeToRawInputData() {
    return PointerLockPlatform.instance.subscribeToRawInputData();
  }

  Future<Offset> lastPointerDelta() {
    return PointerLockPlatform.instance.lastPointerDelta();
  }

  Stream<Offset> startPointerLockSession() {
    return PointerLockPlatform.instance.startPointerLockSession();
  }
}
