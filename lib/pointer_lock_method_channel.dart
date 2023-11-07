import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pointer_lock_platform_interface.dart';

/// An implementation of [PointerLockPlatform] that uses method channels.
class MethodChannelPointerLock extends PointerLockPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pointer_lock');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
