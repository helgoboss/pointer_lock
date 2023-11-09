import 'dart:ui';

import 'pointer_lock_platform_interface.dart';

/// Provides functions related to locking the mouse pointer to its current position. This is useful for widgets
/// such as knobs, drag fields and zoom controls.
class PointerLock {
  /// Locks the mouse pointer to its current position until [PointerLock.unlockPointer] is called.
  ///
  /// While the pointer is locked, Flutter will not receive any meaningful mouse move deltas. You need to call
  /// [PointerLock.lastPointerDelta] for acquiring the last delta.
  ///
  /// On Windows, this uses `ClipCursor`. On macOS, this uses `CGAssociateMouseAndMouseCursorPosition`.
  Future<void> lockPointer() {
    return PointerLockPlatform.instance.lockPointer();
  }

  /// Unlocks the pointer.
  ///
  /// On Windows, this uses `ClipCursor`. On macOS, this uses `CGAssociateMouseAndMouseCursorPosition`.
  Future<void> unlockPointer() {
    return PointerLockPlatform.instance.unlockPointer();
  }

  /// Hides the mouse pointer.
  ///
  /// Although Flutter has ways to hide the mouse pointer (via `MouseRegion` and `SystemMouseCursors.none`), it doesn't
  /// always work nicely with pointer locking. That's why this explicit function is provided.
  ///
  /// Care should be taken to not call this function repeatedly because on Windows, this uses the function `ShowCursor`
  /// which internally increments/decrements a counter to decide whether to show the pointer or not.
  ///
  /// On Windows, this uses `ShowCursor`. On macOS, this uses `NSCursor.hide`.
  Future<void> hidePointer() {
    return PointerLockPlatform.instance.hidePointer();
  }

  /// Shows the mouse pointer.
  ///
  /// Care should be taken to not call this function repeatedly because on Windows, this uses the function `ShowCursor`
  /// which internally increments/decrements a counter to decide whether to show the pointer or not.
  ///
  /// On Windows, this uses `ShowCursor`. On macOS, this uses `NSCursor.unhide`.
  Future<void> showPointer() {
    return PointerLockPlatform.instance.showPointer();
  }

  /// Invokes the Win32 function `RegisterRawInputDevices` to make the Flutter window receive raw input events from the
  /// mouse device. It also sets up a `WindowProcDelegate` to read the events and extract its delta values.
  ///
  /// This function should be called at initialization time if you are targeting Windows and use
  /// [PointerLock.lastPointerDelta]. Calling it on other operating systems or calling it multiple times is okay,
  /// it will not do anything in this case.
  ///
  /// **Attention:** It's exposed as an explicit function because `RegisterRawInputDevices` comes with a caveat, which
  /// is best described by citing the Win32 API docs: "Only one window per raw input device class may be registered to
  /// receive raw input within a process (the window passed in the last call to RegisterRawInputDevices). Because of
  /// this, RegisterRawInputDevices should not be used from a library, as it may interfere with any raw input processing
  /// logic already present in applications that load it."
  Future<void> subscribeToRawInputData() {
    return PointerLockPlatform.instance.subscribeToRawInputData();
  }

  /// Returns the last mouse move delta.
  ///
  /// On Windows, it's necessary to call [PointerLock.subscribeToRawInputData] before calling this.
  ///
  /// On Windows, this reports values received in `WM_INPUT` messages. On macOS, this uses `CGGetLastMouseDelta`.
  Future<Offset> lastPointerDelta() {
    return PointerLockPlatform.instance.lastPointerDelta();
  }

  /// Locks the pointer and returns a stream of deltas as the mouse is being moved.
  ///
  /// The pointer lock session ends as soon as a mouse button is released. Consequently, you should start the session
  /// in response to a `PointerDownEvent`.
  ///
  /// On macOS, this uses `CGAssociateMouseAndMouseCursorPosition`. On Windows, it depends on the mode that you can pass
  /// as argument. The default one is [WindowsPointerLockMode.capture] because it doesn't come with the danger of
  /// stealing raw input focus from other parts of the application.
  Stream<Offset> startPointerLockSession({
    WindowsPointerLockMode windowsMode = WindowsPointerLockMode.capture,
  }) {
    return PointerLockPlatform.instance.startPointerLockSession(windowsMode: windowsMode);
  }
}

/// On Windows, there are multiple ways to achieve pointer locking and each one comes with its own set of disadvantages.
enum WindowsPointerLockMode {
  /// Use `SetCapture`, `SetCursorPos` and `ReleaseCapture` to achieve pointer locking on Windows.
  ///
  /// This mode doesn't rely on raw input data and therefore doesn't come with the caveat described in
  /// [PointerLock.subscribeToRawInputData]. However, since this approach relies on manually resetting the pointer
  /// position whenever the mouse moves, it's probably better to hide the pointer before starting the session,
  /// otherwise it's possible that you see the pointer moving a bit.
  ///
  /// **Attention:** With this mode, Flutter will not be able to receive messages while the session is active.
  capture,
  /// Use `ClipCursor`, `RegisterRawInputDevices` and `WM_INPUT` to achieve pointer locking on Windows.
  ///
  /// This mode comes with a caveat described in [PointerLock.subscribeToRawInputData].
  clip
}
