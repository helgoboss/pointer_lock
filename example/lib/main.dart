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
  final _pointerLockPlugin = PointerLock();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) async {
            await _pointerLockPlugin.hidePointer();
            await _pointerLockPlugin.lockPointer();
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
            child: Text('Last pointer delta: $_lastPointerDelta'),
          ),
        ),
      ),
    );
  }
}
