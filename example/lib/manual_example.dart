import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

class ManualExample extends StatefulWidget {
  final bool hidePointer;

  const ManualExample({super.key, required this.hidePointer});

  @override
  State<ManualExample> createState() => _ManualExampleState();
}

class _ManualExampleState extends State<ManualExample> {
  final _pointerLockPlugin = PointerLock();
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  void initState() {
    // This preparation is necessary to make `lastPointerDelta` work on Windows. It comes with a caveat, so make
    // sure to read its documentation.
    _pointerLockPlugin.subscribeToRawInputData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (details) async {
        if (widget.hidePointer) {
          await _pointerLockPlugin.hidePointer();
        }
        await _pointerLockPlugin.lockPointer();
      },
      onPointerMove: (_) async {
        final delta = await _pointerLockPlugin.lastPointerDelta();
        _setLastPointerDelta(delta);
      },
      onPointerUp: (_) async {
        if (widget.hidePointer) {
          await _pointerLockPlugin.showPointer();
        }
        await _pointerLockPlugin.unlockPointer();
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
