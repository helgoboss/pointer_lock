import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

class DragPanel extends StatefulWidget {
  final PointerLockCursor cursor;
  final PointerLockWindowsMode windowsMode;

  const DragPanel({
    super.key,
    required this.cursor,
    required this.windowsMode,
  });

  @override
  State<DragPanel> createState() => _DragPanelState();
}

class _DragPanelState extends State<DragPanel> {
  bool _dragging = false;
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return PointerLockDragArea(
      cursor: widget.cursor,
      windowsMode: widget.windowsMode,
      onStart: (_) => _setDragging(true),
      onUpdate: (details) {
        _setLastPointerDelta(details.move.delta);
      },
      onEnd: (_) => _setDragging(false),
      child: switch (_dragging) {
        false => Center(
            child: Text(
              "Drag with left mouse button!",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        true => InfoPanel(
            lastPointerDelta: _lastPointerDelta,
            accumulation: _accumulation,
          ),
      },
    );
  }

  void _setDragging(bool value) {
    setState(() {
      _dragging = value;
    });
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
