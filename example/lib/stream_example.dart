import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

class StreamExample extends StatefulWidget {
  final bool hidePointer;
  final WindowsPointerLockMode windowsMode;

  const StreamExample({
    super.key,
    required this.hidePointer,
    required this.windowsMode,
  });

  @override
  State<StreamExample> createState() => _StreamExampleState();
}

class _StreamExampleState extends State<StreamExample> {
  final _pointerLockPlugin = PointerLock();
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (details) async {
        if (widget.hidePointer) {
          await _pointerLockPlugin.hidePointer();
        }
        _pointerLockPlugin.startPointerLockSession(windowsMode: widget.windowsMode).listen(
          (delta) {
            _setLastPointerDelta(delta);
          },
          onDone: () async {
            if (widget.hidePointer) {
              await _pointerLockPlugin.showPointer();
            }
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
