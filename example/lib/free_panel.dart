import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/info_panel.dart';

class FreePanel extends StatefulWidget {
  final PointerLockCursor cursor;
  final PointerLockWindowsMode windowsMode;

  const FreePanel({
    super.key,
    required this.cursor,
    required this.windowsMode,
  });

  @override
  State<FreePanel> createState() => _FreePanelState();
}

class _FreePanelState extends State<FreePanel> {
  StreamSubscription<PointerLockMoveEvent>? _subscription;
  Offset _lastPointerDelta = Offset.zero;
  Offset _accumulation = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return _subscription == null
        ? Center(
            child: ElevatedButton(
              onPressed: _startSession,
              child: const Text("Lock pointer!"),
            ),
          )
        : Actions(
            actions: {
              DismissIntent: CallbackAction(onInvoke: (intent) {
                _stopSession();
                return null;
              })
            },
            child: Focus(
              autofocus: true,
              child: InfoPanel(
                lastPointerDelta: _lastPointerDelta,
                accumulation: _accumulation,
                additionalText: "Unlock the pointer by pressing the Escape key!",
              ),
            ),
          );
  }

  void _startSession() {
    if (_subscription != null) {
      return;
    }
    final deltaStream = pointerLock.createSession(
      windowsMode: widget.windowsMode,
      cursor: widget.cursor,
    );
    final subscription = deltaStream.listen((event) {
      _processMoveDelta(event.delta);
    });
    _setSubscription(subscription);
  }

  void _stopSession() async {
    final subscription = _subscription;
    if (subscription == null) {
      return;
    }
    _setSubscription(null);
    await subscription.cancel();
  }

  void _setSubscription(StreamSubscription<PointerLockMoveEvent>? value) {
    setState(() {
      _subscription = value;
    });
  }

  void _processMoveDelta(Offset delta) {
    if (!mounted) {
      return;
    }
    setState(() {
      _lastPointerDelta = delta;
      _accumulation += delta;
    });
  }
}
