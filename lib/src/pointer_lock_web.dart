import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../../src/pointer_lock.dart';
import '../../src/pointer_lock_platform_interface.dart';

/// A web implementation of the PointerLockPlatform of the PointerLock plugin.
class PointerLockWeb extends PointerLockPlatform {
  /// Registers this class as the default instance of [PointerLockPlatform].
  static void registerWith(Registrar registrar) {
    PointerLockPlatform.instance = PointerLockWeb();
  }

  @override
  Future<void> ensureInitialized() async {
    // Not required on web
  }

  @override
  Stream<PointerLockMoveEvent> createSession({
    required PointerLockWindowsMode windowsMode,
    required PointerLockCursor cursor,
    required bool unlockOnPointerUp,
  }) {
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
        web.EventStreamProviders.mouseMoveEvent.forTarget(body).listen((event) {
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
          web.EventStreamProviders.mouseUpEvent.forTarget(body).listen((event) {
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
