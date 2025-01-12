import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'pointer_lock.dart';

/// A widget that locks the pointer when you press a mouse button and unlocks it as soon as you release it.
///
/// This is useful as a basic building block for widgets such as knobs, drag fields and zoom controls.
class PointerLockDragArea extends StatefulWidget {
  /// Which cursor to display while the pointer is locked.
  final PointerLockCursor cursor;

  /// Which pointer locking approach to use on Windows (doesn't affect other platforms).
  final PointerLockWindowsMode windowsMode;

  /// This is called when receiving a pointer-down event and lets you decide whether you want to lock the pointer or
  /// not, based on that event. By default, the widget locks the pointer only if the primary button is pressed.
  final bool Function(PointerLockDragAcceptDetails details) accept;

  /// This is called when locking the pointer (after the trigger button has been pressed and accepted).
  final void Function(PointerLockDragLockDetails details)? onLock;

  /// This is called whenever you move the pointer. If not set, pointer locking is disabled.
  final void Function(PointerLockDragMoveDetails details)? onMove;

  /// This is called when unlocking the pointer (after the trigger button has been released).
  final void Function(PointerLockDragUnlockDetails details)? onUnlock;

  /// The child widget. The effective size of the child widget determines the area in which the drag takes place.
  final Widget child;

  /// Creates the drag area.
  const PointerLockDragArea({
    super.key,
    this.cursor = PointerLockCursor.hidden,
    this.windowsMode = PointerLockWindowsMode.capture,
    this.accept = _acceptDefault,
    this.onLock,
    this.onMove,
    this.onUnlock,
    required this.child,
  });

  @override
  State<PointerLockDragArea> createState() => _PointerLockDragAreaState();
}

class PointerLockDragMoveDetails {
  /// The pointer-down event which triggered the pointer-lock session.
  final PointerDownEvent trigger;

  /// The event containing information about this pointer move.
  final PointerLockMoveEvent move;

  PointerLockDragMoveDetails({required this.trigger, required this.move});
}

class PointerLockDragLockDetails {
  /// The pointer-down event which triggered the pointer-lock session.
  final PointerDownEvent trigger;

  PointerLockDragLockDetails({required this.trigger});
}

class PointerLockDragAcceptDetails {
  /// The pointer-down event which triggered the pointer-lock session.
  final PointerDownEvent trigger;

  PointerLockDragAcceptDetails({required this.trigger});
}

class PointerLockDragUnlockDetails {
  /// The pointer-down event which triggered the pointer-lock session.
  final PointerDownEvent trigger;

  PointerLockDragUnlockDetails({required this.trigger});
}

bool _acceptDefault(PointerLockDragAcceptDetails details) {
  return details.trigger.buttons & kPrimaryButton > 0;
}

class _PointerLockDragAreaState extends State<PointerLockDragArea> {
  _Session? _session;

  @override
  void dispose() {
    _session?.subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown:
          widget.onMove == null ? null : (event) => _onPointerDown(event),
      onPointerUp: (event) => _onPointerUp(event),
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent downEvent) {
    if (_session != null) {
      return;
    }
    if (!widget.accept(PointerLockDragAcceptDetails(trigger: downEvent))) {
      return;
    }
    final deltaStream = pointerLock.createSession(
      windowsMode: widget.windowsMode,
      cursor: widget.cursor,
    );
    final subscription = deltaStream.listen((event) {
      final details =
          PointerLockDragMoveDetails(trigger: downEvent, move: event);
      widget.onMove?.call(details);
    });
    _session = _Session(downEvent: downEvent, subscription: subscription);
    final details = PointerLockDragLockDetails(trigger: downEvent);
    widget.onLock?.call(details);
  }

  void _onPointerUp(PointerUpEvent upEvent) async {
    final session = _session;
    if (session == null) {
      return;
    }
    final checkPointer = !Platform.isWindows ||
        widget.windowsMode == PointerLockWindowsMode.clip;
    if (checkPointer && upEvent.pointer != session.downEvent.pointer) {
      // The up event doesn't belong to the previous down event.
      //
      // On Windows, we don't do that check because it's hard to figure out
      // whether the pointer-up event belongs to the pointer-down event.
      // When using capture mode, the pointer-up event will
      // will be disassociated from the original pointer-down event, because
      // SetCapture was called in-between. Instead, the pointer-up event
      // will be associated with a synthesized pointer-down event. It's a
      // bit hacky. Hope this can be improved in the future.
      return;
    }
    _session = null;
    session.subscription.cancel();
    final details = PointerLockDragUnlockDetails(trigger: session.downEvent);
    widget.onUnlock?.call(details);
  }
}

class _Session {
  final PointerDownEvent downEvent;
  final StreamSubscription<PointerLockMoveEvent> subscription;

  _Session({required this.downEvent, required this.subscription});
}
