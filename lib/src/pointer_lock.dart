import 'dart:ui';

import 'pointer_lock_platform_interface.dart';

const pointerLock = PointerLock();

/// Provides functions related to locking the mouse pointer to its current position. This is useful for widgets
/// such as knobs, drag fields and zoom controls.
class PointerLock {
  const PointerLock();

  /// Ensures that the pointer is restored after hot restart.
  Future<void> ensureInitialized() {
    return PointerLockPlatform.instance.ensureInitialized();
  }

  /// Returns the position of the mouse pointer in screen coordinates.
  Future<Offset> pointerPositionOnScreen() {
    return PointerLockPlatform.instance.pointerPositionOnScreen();
  }

  /// Locks the pointer and returns a stream of deltas as the mouse is being moved.
  ///
  /// The pointer lock session ends as soon as a mouse button is released. Consequently, you should start the session
  /// in response to a `PointerDownEvent`.
  ///
  /// On macOS, this uses `CGAssociateMouseAndMouseCursorPosition`. On Windows, it depends on the mode that you can pass
  /// as argument. The default one is [PointerLockWindowsMode.capture] because it doesn't come with the danger of
  /// stealing raw input focus from other parts of the application.
  Stream<PointerLockMoveEvent> createSession({
    PointerLockWindowsMode windowsMode = PointerLockWindowsMode.capture,
    PointerLockCursor cursor = PointerLockCursor.hidden,
  }) {
    return PointerLockPlatform.instance.createSession(
      windowsMode: windowsMode,
      cursor: cursor,
    );
  }
}

class PointerLockMoveEvent {
  final Offset delta;

  PointerLockMoveEvent({required this.delta});
}

enum PointerLockCursor {
  normal,
  hidden,
}

/// On Windows, there are multiple ways to achieve pointer locking and each one comes with its own set of disadvantages.
enum PointerLockWindowsMode {
  /// Use `SetCapture`, `SetCursorPos` and `ReleaseCapture` to achieve pointer locking on Windows.
  ///
  /// This mode doesn't rely on raw input data and therefore doesn't come with the caveat described in
  /// [PointerLock._subscribeToRawInputData]. However, since this approach relies on manually resetting the pointer
  /// position whenever the mouse moves, it's probably better to hide the pointer before starting the session,
  /// otherwise it's possible that you see the pointer moving a bit.
  ///
  /// **Attention:** With this mode, Flutter will not be able to receive messages while the session is active.
  capture,

  /// Use `ClipCursor`, `RegisterRawInputDevices` and `WM_INPUT` to achieve pointer locking on Windows.
  ///
  /// This mode comes with a caveat described in [PointerLock._subscribeToRawInputData].
  clip
}
