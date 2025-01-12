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

  var _initialized = false;

  @override
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await methodChannel.invokeMethod<void>('flutterRestart');
  }

  @override
  Future<Offset> pointerPositionOnScreen() async {
    final list = await methodChannel.invokeListMethod<double>('pointerPositionOnScreen');
    return _convertListToOffset(list);
  }

  @override
  Stream<Offset> createSession({
    required WindowsPointerLockMode windowsMode,
    required PointerLockCursor cursor,
  }) {
    return _decorateRawStream(
      cursor: cursor,
      rawStream: _createRawStream(windowsMode: windowsMode),
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

  /// Creates a Stream via Dart by tapping into the pointer events that are emitted by Flutter anyway.
  ///
  /// Also calls necessary platform methods for locking and unlocking the pointer.
  Stream<Offset> _createRawStreamDart() {
    final previousCallback = PlatformDispatcher.instance.onPointerDataPacket!;
    final controller = StreamController<Offset>();
    controller.onListen = () async {
      await _subscribeToRawInputData();
      await _lockPointer();
      PlatformDispatcher.instance.onPointerDataPacket = (packet) async {
        const motions = [PointerChange.move, PointerChange.hover];
        final isMotion = packet.data.any((d) => motions.contains(d.change));
        if (isMotion) {
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

  Stream<Offset> _createRawStream({required WindowsPointerLockMode windowsMode}) {
    if (Platform.isWindows) {
      switch (windowsMode) {
        case WindowsPointerLockMode.capture:
          // Capture mode needs to be controlled from the native code because the Flutter Engine doesn't receive mouse
          // events anymore while we are capturing them.
          return _createRawStreamNative();
        case WindowsPointerLockMode.clip:
          // In clip mode, the Flutter Engine still receives mouse events, so we can control the stream from Dart.
          return _createRawStreamDart();
      }
    } else if (Platform.isMacOS) {
      // On macOS, we need to put the native code in control, otherwise we would only receive deltas while a mouse
      // button is pressed. If the mouse button is not pressed, macOS generates mouse-move events instead of mouse-drag
      // events. The Flutter Engine forwards mouse-move events to Dart only if the pointer coordinates change. But
      // when doing locking the pointer via CGAssociateMouseAndMouseCursorPosition(0), the absolute coordinates don't
      // change anymore.
      return _createRawStreamNative();
    } else {
      // On Linux (at least X11, Wayland is not implemented yet), we are fine with Dart-controlled streams.
      return _createRawStreamDart();
    }
  }

  /// Creates a Stream that is driven by the native code.
  Stream<Offset> _createRawStreamNative() {
    Offset convertEventToOffset(dynamic event) {
      if (event == null || event is! Float64List || event.length < 2) {
        return Offset.zero;
      }
      return Offset(event[0], event[1]);
    }

    return sessionEventChannel.receiveBroadcastStream().map(convertEventToOffset);
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
    final list = await methodChannel.invokeListMethod<double>('lastPointerDelta');
    return _convertListToOffset(list);
  }
}

Offset _convertListToOffset(List<double>? list) {
  if (list == null || list.length < 2) {
    return Offset.zero;
  }
  return Offset(list[0], list[1]);
}
