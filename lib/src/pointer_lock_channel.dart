import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../pointer_lock.dart';
import 'pointer_lock_platform_interface.dart';
import 'dart:io' show Platform;

/// An implementation of [PointerLockPlatform] that uses channels.
class ChannelPointerLock extends PointerLockPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pointer_lock');

  /// The event channel used to interact with the native platform.
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
  Future<void> subscribeToRawInputData() async {
    if (!Platform.isWindows) {
      return;
    }
    return methodChannel.invokeMethod<void>('subscribeToRawInputData');
  }

  @override
  Future<Offset> lastPointerDelta() async {
    final list = await methodChannel.invokeListMethod<double>('lastPointerDelta');
    return _convertListToOffset(list);
  }

  @override
  Future<Offset> pointerPositionOnScreen() async {
    final list = await methodChannel.invokeListMethod<double>('pointerPositionOnScreen');
    return _convertListToOffset(list);
  }

  @override
  Stream<Offset> startPointerLockSession({
    required WindowsPointerLockMode windowsMode,
    required PointerLockCursor cursor,
  }) {
    if (Platform.isWindows) {
      switch (windowsMode) {
        case WindowsPointerLockMode.capture:
          // With capture mode, we pass control to the platform-specific code for the length
          // of the complete session.
          // TODO-high CONTINUE Somehow pass cursor argument or manually hide cursor at start AND show at end of stream
          return sessionEventChannel.receiveBroadcastStream().map((event) {
            if (event == null || event is! Float64List || event.length < 2) {
              return Offset.zero;
            }
            return Offset(event[0], event[1]);
          });
        case WindowsPointerLockMode.clip:
          // With clip mode, Dart stays in control during the session.
          subscribeToRawInputData();
          return _synthesizePointerLockSession(cursor: cursor);
      }
    } else {
      return _synthesizePointerLockSession(cursor: cursor);
    }
  }

  Stream<Offset> _synthesizePointerLockSession({
    required PointerLockCursor cursor,
  }) async* {
    if (cursor == PointerLockCursor.hidden) {
      await hidePointer();
    }
    await lockPointer();
    await for (final packet in _getPointerDataPacketStream()) {
      var isMove = false;
      for (final data in packet.data) {
        switch (data.change) {
          case PointerChange.move:
            // We must not stop the search for other events here!
            // Otherwise we risk missing the pointer-up event.
            isMove = true;
          case PointerChange.up:
            // Releasing a button is our sign for ending the session
            await unlockPointer();
            if (cursor == PointerLockCursor.hidden) {
              await showPointer();
            }
            return;
          default:
        }
      }
      if (isMove) {
        yield await lastPointerDelta();
      }
    }
  }
}

/// Taps pointer events from the usual Flutter processing, emitting them as a stream.
Stream<PointerDataPacket> _getPointerDataPacketStream() {
  final previousCallback = PlatformDispatcher.instance.onPointerDataPacket!;
  void restorePreviousCallback() {
    PlatformDispatcher.instance.onPointerDataPacket = previousCallback;
  }

  final controller = StreamController<PointerDataPacket>(
    onCancel: () => restorePreviousCallback(),
  );
  controller.onListen = () {
    PlatformDispatcher.instance.onPointerDataPacket = (packet) {
      previousCallback(packet);
      controller.add(packet);
    };
  };
  return controller.stream;
}

Offset _convertListToOffset(List<double>? list) {
  if (list == null || list.length < 2) {
    return Offset.zero;
  }
  return Offset(list[0], list[1]);
}
