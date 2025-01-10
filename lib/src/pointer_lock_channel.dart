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
  Future<Offset> pointerPositionOnScreen() async {
    final list =
        await methodChannel.invokeListMethod<double>('pointerPositionOnScreen');
    return _convertListToOffset(list);
  }

  @override
  Stream<Offset> createSession({
    required WindowsPointerLockMode windowsMode,
    required PointerLockCursor cursor,
  }) {
    return _decorateRawStream(
      cursor: cursor,
      rawStream:
          Platform.isWindows && windowsMode == WindowsPointerLockMode.capture
              ? _createRawCaptureStream()
              : _createRawNormalStream(),
    );
  }

  /// Decorates the given raw stream with hide/show cursor logic.
  Stream<Offset> _decorateRawStream({
    required PointerLockCursor cursor,
    required Stream<Offset> rawStream,
  }) {
    final controller = StreamController<Offset>();
    StreamSubscription<Offset>? rawStreamSubscription;
    controller.onListen = () async {
      if (cursor == PointerLockCursor.hidden) {
        await _hidePointer();
      }
      // Reacting to onDone is not necessary because the raw stream is infinite
      rawStreamSubscription = rawStream.listen(
        controller.add,
        cancelOnError: false,
        onError: (Object error) => controller.addError(error),
      );
    };
    controller.onCancel = () async {
      await rawStreamSubscription?.cancel();
    };
    controller.done.whenComplete(() async {
      if (cursor == PointerLockCursor.hidden) {
        await _showPointer();
      }
    });
    return controller.stream;
  }

  /// Taps pointer events from the usual Flutter processing, emitting them as a stream.
  Stream<Offset> _createRawNormalStream() {
    final previousCallback = PlatformDispatcher.instance.onPointerDataPacket!;
    final controller = StreamController<Offset>();
    controller.onListen = () async {
      await _subscribeToRawInputData();
      await _lockPointer();
      PlatformDispatcher.instance.onPointerDataPacket = (packet) async {
        final isMove = packet.data.any((d) => d.change == PointerChange.move);
        if (isMove) {
          final delta = await _lastPointerDelta();
          controller.add(delta);
        }
        previousCallback(packet);
      };
    };
    controller.done.whenComplete(() async {
      PlatformDispatcher.instance.onPointerDataPacket = previousCallback;
      await _unlockPointer();
    });
    return controller.stream;
  }

  Stream<Offset> _createRawCaptureStream() {
    Offset convertEventToOffset(dynamic event) {
      if (event == null || event is! Float64List || event.length < 2) {
        return Offset.zero;
      }
      return Offset(event[0], event[1]);
    }

    return sessionEventChannel
        .receiveBroadcastStream()
        .map(convertEventToOffset);
  }

  Future<void> _lockPointer() {
    return methodChannel.invokeMethod<void>('lockPointer');
  }

  Future<void> _unlockPointer() {
    return methodChannel.invokeMethod<void>('unlockPointer');
  }

  Future<void> _showPointer() {
    return methodChannel.invokeMethod<void>('showPointer');
  }

  Future<void> _hidePointer() {
    return methodChannel.invokeMethod<void>('hidePointer');
  }

  Future<void> _subscribeToRawInputData() async {
    if (!Platform.isWindows) {
      return;
    }
    return methodChannel.invokeMethod<void>('subscribeToRawInputData');
  }

  Future<Offset> _lastPointerDelta() async {
    final list =
        await methodChannel.invokeListMethod<double>('lastPointerDelta');
    return _convertListToOffset(list);
  }
}

Offset _convertListToOffset(List<double>? list) {
  if (list == null || list.length < 2) {
    return Offset.zero;
  }
  return Offset(list[0], list[1]);
}
