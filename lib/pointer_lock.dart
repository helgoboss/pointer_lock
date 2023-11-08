
import 'dart:ui';

import 'pointer_lock_platform_interface.dart';

class PointerLock {
  Future<void> lockPointer() {
    return PointerLockPlatform.instance.lockPointer();
  }

  Future<void> unlockPointer() {
    return PointerLockPlatform.instance.unlockPointer();
  }

  Future<Offset> lastPointerDelta() {
    return PointerLockPlatform.instance.lastPointerDelta();
  }

  Future<void> hidePointer() {
    return PointerLockPlatform.instance.hidePointer();
  }

  Future<void> showPointer() {
    return PointerLockPlatform.instance.showPointer();
  }

  Stream<Offset> startPointerLockSession() {
    return PointerLockPlatform.instance.startPointerLockSession();
  }
}
