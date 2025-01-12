import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'pointer_lock.dart';

class PointerLockDragArea extends StatefulWidget {
  final PointerLockCursor cursor;
  final PointerLockWindowsMode windowsMode;

  final bool Function(PointerLockDragAcceptDetails details) accept;
  final void Function(PointerLockDragStartDetails details)? onStart;
  final void Function(PointerLockDragUpdateDetails details)? onUpdate;
  final void Function(PointerLockDragEndDetails details)? onEnd;
  final Widget child;

  const PointerLockDragArea({
    super.key,
    this.cursor = PointerLockCursor.hidden,
    this.windowsMode = PointerLockWindowsMode.capture,
    this.accept = _acceptDefault,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    required this.child,
  });

  @override
  State<PointerLockDragArea> createState() => _PointerLockDragAreaState();
}

class PointerLockDragUpdateDetails {
  final PointerDownEvent trigger;
  final PointerLockMoveEvent move;

  PointerLockDragUpdateDetails({required this.trigger, required this.move});
}

class PointerLockDragStartDetails {
  final PointerDownEvent trigger;

  PointerLockDragStartDetails({required this.trigger});
}

class PointerLockDragAcceptDetails {
  final PointerDownEvent trigger;

  PointerLockDragAcceptDetails({required this.trigger});
}

class PointerLockDragEndDetails {
  final PointerDownEvent trigger;

  PointerLockDragEndDetails({required this.trigger});
}

bool _acceptDefault(PointerLockDragAcceptDetails details) {
  return details.trigger.buttons & kPrimaryButton > 0;
}

class _PointerLockDragAreaState extends State<PointerLockDragArea> {
  _Session? _session;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.onUpdate == null ? null : (event) => _onPointerDown(event),
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
      final details = PointerLockDragUpdateDetails(trigger: downEvent, move: event);
      widget.onUpdate?.call(details);
    });
    _session = _Session(downEvent: downEvent, subscription: subscription);
    widget.onStart?.call(PointerLockDragStartDetails(trigger: downEvent));
  }

  void _onPointerUp(PointerUpEvent upEvent) async {
    final session = _session;
    if (session == null) {
      return;
    }
    if (upEvent.pointer != session.downEvent.pointer) {
      return;
    }
    _session = null;
    session.subscription.cancel();
    widget.onEnd?.call(PointerLockDragEndDetails(trigger: session.downEvent));
  }
}

class _Session {
  final PointerDownEvent downEvent;
  final StreamSubscription<PointerLockMoveEvent> subscription;

  _Session({required this.downEvent, required this.subscription});
}
