import 'dart:ui';

import 'pointer_lock_platform_interface.dart';

/// The entry point for everything related to pointer locking
const pointerLock = PointerLock();

/// Provides functions related to locking the pointer to its current position.
class PointerLock {
  const PointerLock();

  /// Ensures that the pointer locking system is correctly initialized.
  ///
  /// At the moment, all this method does, is to restore the original pointer after a hot Flutter restart during app
  /// development.
  ///
  /// This should ideally be called and awaited in the `main` function of the app:
  ///
  /// ```dart
  /// WidgetsFlutterBinding.ensureInitialized();
  /// await pointerLock.ensureInitialized();
  /// runApp(const MyApp());
  /// ```
  Future<void> ensureInitialized() {
    return PointerLockPlatform.instance.ensureInitialized();
  }

  /// Creates a stream which locks the pointer and emits pointer-move events as long as you subscribe to it.
  Stream<PointerLockMoveEvent> createSession({
    PointerLockWindowsMode windowsMode = PointerLockWindowsMode.capture,
    PointerLockCursor cursor = PointerLockCursor.hidden,
  }) {
    return PointerLockPlatform.instance.createSession(
      windowsMode: windowsMode,
      cursor: cursor,
    );
  }

  /// Hides the mouse pointer.
  ///
  /// Although Flutter has ways to hide the mouse pointer (via `MouseRegion` and `SystemMouseCursors.none`), it doesn't
  /// always work nicely with pointer locking. That's why this explicit function is provided.
  ///
  /// Care should be taken to not call this function repeatedly because on Windows, this uses the function `ShowCursor`
  /// which internally increments/decrements a counter to decide whether to show the pointer or not.
  ///
  /// Internally, this uses:
  ///
  /// - On Windows: `ShowCursor`
  /// - On macOS: `NSCursor.hide`
  /// - On Linux: `gdk_window_set_cursor`
  Future<void> hidePointer() {
    return PointerLockPlatform.instance.hidePointer();
  }

  /// Shows the mouse pointer.
  ///
  /// Care should be taken to not call this function repeatedly because on Windows, this uses the function `ShowCursor`
  /// which internally increments/decrements a counter to decide whether to show the pointer or not.
  ///
  /// - On Windows: `ShowCursor`
  /// - On macOS: `NSCursor.unhide`
  /// - On Linux: `gdk_window_set_cursor`
  Future<void> showPointer() {
    return PointerLockPlatform.instance.showPointer();
  }


  /// A utility function that returns the position of the pointer in screen coordinates.
  Future<Offset> pointerPositionOnScreen() {
    return PointerLockPlatform.instance.pointerPositionOnScreen();
  }
}

/// This event is emitted whenever you move the pointer while it's locked.
class PointerLockMoveEvent {
  /// The amount the pointer has been dragged in the coordinate space of the event
  /// receiver since the previous update.
  final Offset delta;

  PointerLockMoveEvent({required this.delta});
}

/// A selection of cursors that can be displayed while the pointer is locked.
enum PointerLockCursor {
  /// Displays the normal cursor.
  ///
  /// On most platforms, this is the cursor which was shown before the pointer was locked.
  normal,
  /// Hides the cursor.
  ///
  /// This is usually preferred, because on some platforms, a visible cursor can flicker when moving
  /// the pointer while it's locked.
  hidden,
}

/// Different techniques to implement pointer locking on Windows.
enum PointerLockWindowsMode {
  /// This technique uses `SetCapture`, `SetCursorPos` and `ReleaseCapture` to achieve pointer locking on Windows.
  ///
  /// Pros:
  ///
  /// - This approach doesn't rely on raw input data and therefore doesn't come with the caveats
  ///   described in [PointerLockWindowsMode.clip].
  ///
  /// Cons:
  ///
  /// - This mode relies on manually resetting the pointer position whenever the pointer moves, so you might see the
  ///   pointer moving a bit if you don't hide it. This is is not a big deal, since most likely you want to
  ///   hide the cursor anyway.
  /// - This approach can cause the Flutter Engine to emit [PointerDataPacket]s with pointer changes
  ///   [PointerChange.cancel], [PointerChange.remove] and [PointerChange.add]. As a result, some pointer events
  ///   such as button presses might not be correctly detected while the pointer is locked. However, we try to
  ///   emit those events as correctly as possible on a best-effort basis.
  ///
  /// In most cases, the cons of this approach are neglectable, so it's the commended mode!
  capture,

  /// This technique uses `ClipCursor`, `RegisterRawInputDevices` and `WM_INPUT` to achieve pointer locking on Windows.
  ///
  /// In particular, this mode invokes the Win32 function `RegisterRawInputDevices` to make the Flutter window receive
  /// raw input events from the pointer device. It also sets up a `WindowProcDelegate` to read the events and extract
  /// its delta values.
  ///
  /// Pros:
  ///
  /// - This approach should not lead to visible cursor movements.
  /// - Other pointer events such as button presses should not be influenced by it.
  ///
  /// Cons:
  ///
  /// - We have observed that pointer movements are not reported as fast as with [PointerLockWindowsMode.capture].
  /// - `RegisterRawInputDevices` comes with a caveat, which is best described by quoting the Win32 API docs:
  ///
  ///   > Only one window per raw input device class may be registered to receive raw input within a process (the window
  ///   > passed in the last call to RegisterRawInputDevices). Because of this, RegisterRawInputDevices should not be
  ///   > used from a library, as it may interfere with any raw input processing logic already present in applications
  ///   > that load it.
  clip
}
