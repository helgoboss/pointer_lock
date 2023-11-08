import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pointer_lock/pointer_lock.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Offset _lastPointerDelta = Offset.zero;
  Stream<Offset>? _pointerLockSessionStream;
  final _pointerLockPlugin = PointerLock();

  @override
  void initState() {
    _pointerLockSessionStream = _pointerLockPlugin.startPointerLockSession();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _pointerLockSessionStream;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (details) async {
            if (details.buttons == kSecondaryMouseButton) {
              await _pointerLockPlugin.hidePointer();
              await _pointerLockPlugin.lockPointer();
            } else {
              // setState(() {
              //   _pointerLockSessionStream = _pointerLockPlugin.startPointerLockSession();
              // });
            }
          },
          onPointerMove: (_) async {
            final delta = await _pointerLockPlugin.lastPointerDelta();
            if (!mounted) {
              return;
            }
            setState(() {
              _lastPointerDelta = delta;
            });
          },
          onPointerUp: (_) async {
            await _pointerLockPlugin.unlockPointer();
            await _pointerLockPlugin.showPointer();
          },
          child: Center(
            child: Column(
              children: [
                Text('Last pointer delta: $_lastPointerDelta'),
                if (stream != null)
                  StreamBuilder(
                    stream: stream,
                    builder: (context, snapshot) {
                      return Text('Error: ${snapshot.error}, Last offset: ${snapshot.data}');
                    },
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
