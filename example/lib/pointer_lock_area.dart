import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

class PointerLockArea extends StatefulWidget {
  final bool hidePointer;
  final WindowsPointerLockMode windowsMode;

  const PointerLockArea({
    super.key,
    required this.hidePointer,
    required this.windowsMode,
  });

  @override
  State<PointerLockArea> createState() => _PointerLockAreaState();
}

class _PointerLockAreaState extends State<PointerLockArea> {
  final _pointerLockPlugin = PointerLock();
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (details) async {
        final session = _pointerLockPlugin.startPointerLockSession(
          windowsMode: widget.windowsMode,
          cursor: widget.hidePointer ? PointerLockCursor.hidden : PointerLockCursor.normal,
        );
        session.listen(
          (delta) {
            _setLastPointerDelta(delta);
          },
        );
      },
      child: InfoPanel(
        lastPointerDelta: _lastPointerDelta,
        accumulation: _accumulation,
      ),
    );
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
