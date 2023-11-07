
import 'pointer_lock_platform_interface.dart';

class PointerLock {
  Future<String?> getPlatformVersion() {
    return PointerLockPlatform.instance.getPlatformVersion();
  }
}
