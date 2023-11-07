import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pointer_lock_platform_interface.dart';

/// An implementation of [PointerLockPlatform] that uses method channels.
class MethodChannelPointerLock extends PointerLockPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pointer_lock');

  @override
  Future<void> lockPointer() {
    return methodChannel.invokeMethod<void>('lockPointer');
  }

  @override
  Future<void> unlockPointer() {
    return methodChannel.invokeMethod<void>('unlockPointer');
  }

  @override
  Future<Offset> lastPointerDelta() async {
    final list = await methodChannel.invokeListMethod<double>('lastPointerDelta');
    if (list == null || list.length < 2) {
      return Offset.zero;
    }
    return Offset(list[0], list[1]);
  }

  @override
  Future<void> showPointer() {
    return methodChannel.invokeMethod<void>('showPointer');
  }

  @override
  Future<void> hidePointer() {
    return methodChannel.invokeMethod<void>('hidePointer');
  }
}
