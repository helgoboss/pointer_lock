import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pointer_lock_platform_interface.dart';

/// An implementation of [PointerLockPlatform] that uses method channels.
class MethodChannelPointerLock extends PointerLockPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pointer_lock');

  /// An event channel used to interact with the native platform.
  @visibleForTesting
  final sessionEventChannel = const EventChannel('pointer_lock_session');

  @override
  Future<void> lockPointer() {
    return methodChannel.invokeMethod<void>('lockPointer');
  }

  @override
  Future<void> unlockPointer() {
    return methodChannel.invokeMethod<void>('unlockPointer');
  }

  @override
  Future<void> showPointer() {
    return methodChannel.invokeMethod<void>('showPointer');
  }

  @override
  Future<void> hidePointer() {
    return methodChannel.invokeMethod<void>('hidePointer');
  }

  @override
  Future<void> subscribeToRawInputData() {
    return methodChannel.invokeMethod<void>('subscribeToRawInputData');
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
  Stream<Offset> startPointerLockSession() {
    return sessionEventChannel.receiveBroadcastStream().map((event) {
      if (event == null || event is! Float64List || event.length < 2) {
        return Offset.zero;
      }
      return Offset(event[0], event[1]);
    });
  }
}
