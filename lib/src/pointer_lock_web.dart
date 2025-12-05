import 'dart:async';
import 'dart:ui';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../../src/pointer_lock.dart';
import '../../src/pointer_lock_platform_interface.dart';

class _GlobalPointerHandlers {
  final StreamController<web.PointerEvent> _pointerMoveController =
      StreamController<web.PointerEvent>.broadcast();
  final StreamController<web.PointerEvent> _pointerUpController =
      StreamController<web.PointerEvent>.broadcast();

  Stream<web.PointerEvent> get onPointerMove => _pointerMoveController.stream;
  Stream<web.PointerEvent> get onPointerUp => _pointerUpController.stream;

  /// Sets up global pointer event handlers to manage pointer movement after
  /// lock.
  ///
  /// Firefox (and like Safari) require that move and up events are already
  /// subscribed before pointer lock is requested, otherwise they won't be
  /// delivered until a new pointer down event occurs. This class enables the
  /// code below to attach a listener to an event stream from a subscription
  /// that is already active when pointer lock is requested.
  _GlobalPointerHandlers._() {
    final document = web.document;

    const web.EventStreamProvider<web.PointerEvent>('pointermove')
        .forTarget(document.body)
        .listen((event) {
      _pointerMoveController.add(event);
    });

    const web.EventStreamProvider<web.PointerEvent>('pointerup')
        .forTarget(document.body)
        .listen((event) {
      _pointerUpController.add(event);
    });
  }

  static late final _GlobalPointerHandlers instance;
  static void initialize() {
    instance = _GlobalPointerHandlers._();
  }
}

/// A web implementation of the PointerLockPlatform of the PointerLock plugin.
class PointerLockWeb extends PointerLockPlatform {
  /// Registers this class as the default instance of [PointerLockPlatform].
  static void registerWith(Registrar registrar) {
    PointerLockPlatform.instance = PointerLockWeb();
  }

  bool _isInitialized = false;

  @override
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      _isInitialized = true;
      _GlobalPointerHandlers.initialize();
    }
  }

  @override
  Stream<PointerLockMoveEvent> createSession({
    required PointerLockWindowsMode windowsMode,
    required PointerLockCursor cursor,
    required bool unlockOnPointerUp,
  }) {
    if (!_isInitialized) {
      throw Exception(
          'PointerLockWeb: Not initialized. pointerLock.ensureInitialized()'
          ' must be called in your main function before runApp().');
    }

    final controller = StreamController<PointerLockMoveEvent>();
    final document = web.document;
    final body = document.body;
    StreamSubscription? mouseMoveSubscription;
    StreamSubscription? mouseUpSubscription;
    StreamSubscription? pointerLockChangeSubscription;

    // Add a flag to track if we've successfully locked
    var hasLockedSuccessfully = false;
    Timer? lockCheckTimer;

    void cleanup() {
      mouseMoveSubscription?.cancel();
      mouseUpSubscription?.cancel();
      pointerLockChangeSubscription?.cancel();
      lockCheckTimer?.cancel();
      controller.close();
    }

    void unlock() {
      try {
        if (document.pointerLockElement == body) {
          document.exitPointerLock();
        }
      } catch (e) {
        // Ignore exit errors
      }
      cleanup();
    }

    Future<void> requestLock() async {
      try {
        body?.requestPointerLock();
      } catch (e) {
        controller.addError(Exception(
            'Failed to lock pointer. This can happen if you try to lock too quickly after unlocking. '
            'Please try again in a moment.'));
        unlock();
      }
    }

    // Check if lock was successful
    lockCheckTimer = Timer(const Duration(milliseconds: 100), () {
      if (!hasLockedSuccessfully && !controller.isClosed) {
        controller
            .addError(Exception('Failed to lock pointer. This can happen if:\n'
                '1. The browser denied the request\n'
                '2. You tried to lock too quickly after unlocking\n'
                '3. The page doesn\'t have focus'));
        unlock();
      }
    });

    pointerLockChangeSubscription = web
        .EventStreamProviders.pointerLockChangeEvent
        .forTarget(document)
        .listen((event) {
      if (document.pointerLockElement == body) {
        hasLockedSuccessfully = true;
        lockCheckTimer?.cancel();
      }
      if (document.pointerLockElement == null) {
        unlock();
      }
    });

    // Handle mouse movement
    mouseMoveSubscription =
        _GlobalPointerHandlers.instance.onPointerMove.listen((event) {
      if (document.pointerLockElement == body) {
        final mouseEvent = event;
        controller.add(
          PointerLockMoveEvent(
            delta: Offset(
              mouseEvent.movementX.toDouble(),
              mouseEvent.movementY.toDouble(),
            ),
          ),
        );
      }
    });

    // Handle mouse up if unlockOnPointerUp is true
    if (unlockOnPointerUp) {
      mouseUpSubscription =
          _GlobalPointerHandlers.instance.onPointerUp.listen((event) {
        if (document.pointerLockElement == body) {
          unlock();
        }
      });
    }

    // Initial lock request
    requestLock();

    controller.onCancel = unlock;

    return controller.stream;
  }

  @override
  Future<void> hidePointer() async {
    // Not supported on web
  }

  @override
  Future<void> showPointer() async {
    // Not supported on web
  }

  @override
  Future<Offset> pointerPositionOnScreen() async {
    return Offset(
      web.window.screenX.toDouble(),
      web.window.screenY.toDouble(),
    );
  }
}
