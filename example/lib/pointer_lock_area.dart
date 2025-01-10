import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

enum SessionTrigger {
  drag,
  clickAndEscape,
}

class PointerLockArea extends StatefulWidget {
  final SessionTrigger sessionTrigger;
  final bool hidePointer;
  final WindowsPointerLockMode windowsMode;

  const PointerLockArea({
    super.key,
    required this.sessionTrigger,
    required this.hidePointer,
    required this.windowsMode,
  });

  @override
  State<PointerLockArea> createState() => _PointerLockAreaState();
}

class _PointerLockAreaState extends State<PointerLockArea> {
  final _pointerLockPlugin = PointerLock();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<Offset>? _session;
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final drag = widget.sessionTrigger == SessionTrigger.drag;
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: drag
          ? null
          : (key) async {
              if (key is! KeyUpEvent) {
                return;
              }
              if (key.logicalKey == LogicalKeyboardKey.escape) {
                _stopSession();
              }
            },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _startSession(),
        onPointerUp: drag ? (_) => _stopSession() : null,
        child: InfoPanel(
          lastPointerDelta: _lastPointerDelta,
          accumulation: _accumulation,
        ),
      ),
    );
  }

  void _startSession() {
    if (_session != null) {
      return;
    }
    debugPrint("Starting session...");
    final deltaStream = _pointerLockPlugin.createSession(
      windowsMode: widget.windowsMode,
      cursor: widget.hidePointer
          ? PointerLockCursor.hidden
          : PointerLockCursor.normal,
    );
    _session = deltaStream.listen(
      (delta) {
        _setLastPointerDelta(delta);
      },
    );
  }

  void _stopSession() async {
    debugPrint("Stopping session...");
    _session?.cancel();
    _session = null;
  }

  void _setLastPointerDelta(Offset delta) {
    if (!mounted) {
      return;
    }
    setState(() {
      _lastPointerDelta = delta;
      _accumulation += delta;
    });
  }
}
