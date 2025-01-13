import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'pointer_lock.dart';
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
  Stream<PointerLockMoveEvent> createSession({
    required PointerLockWindowsMode windowsMode,
    required PointerLockCursor cursor,
    required bool unlockOnPointerUp,
  }) {
    return _decorateRawStream(
      cursor: cursor,
      rawStream: _createRawStream(
        windowsMode: windowsMode,
        unlockOnPointerUp: unlockOnPointerUp,
      ),
    );
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
  Future<Offset> pointerPositionOnScreen() async {
    final list =
        await methodChannel.invokeListMethod<double>('pointerPositionOnScreen');
    return _convertListToOffset(list);
  }

  /// Decorates the given raw stream with hide/show cursor logic.
  Stream<PointerLockMoveEvent> _decorateRawStream({
    required PointerLockCursor cursor,
    required Stream<PointerLockMoveEvent> rawStream,
  }) {
    final controller = StreamController<PointerLockMoveEvent>();
    StreamSubscription<PointerLockMoveEvent>? rawStreamSubscription;
    controller.onListen = () async {
      if (cursor == PointerLockCursor.hidden) {
        await _hidePointer();
      }
      // Reacting to onDone is not necessary because the raw stream is infinite
      rawStreamSubscription = rawStream.listen(
        controller.add,
        cancelOnError: false,
        onError: (Object error) => controller.addError(error),
        // This will only be called if the raw stream was created with unlockOnPointerUp (automatic unlocking)
        onDone: () => controller.close(),
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
  Stream<PointerLockMoveEvent> _createRawStreamDart({
    required bool unlockOnPointerUp,
  }) {
    final previousCallback = PlatformDispatcher.instance.onPointerDataPacket!;
    final controller = StreamController<PointerLockMoveEvent>();
    controller.onListen = () async {
      await _subscribeToRawInputData();
      await _lockPointer();
      PlatformDispatcher.instance.onPointerDataPacket = (packet) async {
        var unlock = false;
        var containsMotionEvents = false;
        // Inspect events in packet, maybe filtering out some of them so that they are not forwarded to the
        // Flutter widgets.
        packet.data.retainWhere((data) {
          switch (data.change) {
            case PointerChange.up:
              if (unlockOnPointerUp) {
                if (unlock) {
                  // A previous pointer-up event in the same packet triggered an unlock. Forward this one.
                  return true;
                } else {
                  // This is the event which unlocks the pointer!
                  unlock = true;
                  return false;
                }
              } else {
                // Without automatic unlocking, we should always forward pointer-up events!
                return true;
              }
            case PointerChange.down:
              // Forward if there's no automatic unlocking or if a previous pointer-up event already triggered an unlock.
              return !unlockOnPointerUp || unlock;
            case PointerChange.move:
            case PointerChange.hover:
              containsMotionEvents = true;
              // Forward only if a previous pointer-up event in the same packet triggered an unlock.
              // Emitting motion events while the pointer is locked is undesired. It would lead to
              // hover effects being triggered.
              return unlock;
            // Forward all other events
            default:
              return true;
          }
        });
        // Maybe unlock
        if (unlock) {
          // It's important to await here, otherwise it could happen that order of
          // forwarded packets changes (this forwarded package overtaking a previous
          // forwarded package). The method channel should nicely serialize everything.
          await controller.close();
        }
        // Maybe emit move event
        if (containsMotionEvents) {
          final delta = await _lastPointerDelta();
          if (!controller.isClosed) {
            final event = PointerLockMoveEvent(delta: delta);
            controller.add(event);
          }
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

  Stream<PointerLockMoveEvent> _createRawStream({
    required PointerLockWindowsMode windowsMode,
    required bool unlockOnPointerUp,
  }) {
    if (Platform.isWindows) {
      switch (windowsMode) {
        case PointerLockWindowsMode.capture:
          // Capture mode needs to be controlled from the native code because the Flutter Engine doesn't receive mouse
          // events anymore while we are capturing them.
          return _createRawStreamNative(unlockOnPointerUp: unlockOnPointerUp);
        case PointerLockWindowsMode.clip:
          // In clip mode, the Flutter Engine still receives mouse events, so we can control the stream from Dart.
          return _createRawStreamDart(unlockOnPointerUp: unlockOnPointerUp);
      }
    } else if (Platform.isMacOS) {
      // On macOS, we need to put the native code in control, otherwise we would only receive deltas while a mouse
      // button is pressed. If the mouse button is not pressed, macOS generates mouse-move events instead of mouse-drag
      // events. The Flutter Engine forwards mouse-move events to Dart only if the pointer coordinates change. But
      // when doing locking the pointer via CGAssociateMouseAndMouseCursorPosition(0), the absolute coordinates don't
      // change anymore.
      return _createRawStreamNative(unlockOnPointerUp: unlockOnPointerUp);
    } else {
      // On Linux, we are fine with Dart-controlled streams.
      return _createRawStreamDart(unlockOnPointerUp: unlockOnPointerUp);
    }
  }

  /// Creates a Stream that is driven by the native code.
  Stream<PointerLockMoveEvent> _createRawStreamNative({
    required bool unlockOnPointerUp,
  }) {
    Offset convertEventToOffset(dynamic event) {
      if (event == null || event is! Float64List || event.length < 2) {
        return Offset.zero;
      }
      return Offset(event[0], event[1]);
    }

    return sessionEventChannel
        .receiveBroadcastStream(unlockOnPointerUp)
        .map((evt) => PointerLockMoveEvent(delta: convertEventToOffset(evt)));
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
