import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/mouse_info.dart';

import 'pointer_lock_area.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _hidePointer = false;
  WindowsPointerLockMode _windowsMode = WindowsPointerLockMode.capture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Try dragging the mouse in the drag area below!'),
          centerTitle: true,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Hide pointer
                Row(
                  children: [
                    const Text("Hide pointer when dragging"),
                    _horizontalSpace,
                    Switch(
                      value: _hidePointer,
                      onChanged: (value) {
                        setState(() {
                          _hidePointer = value;
                        });
                      },
                    )
                  ],
                ),
                // Windows mode
                if (Platform.isWindows)
                  Tooltip(
                    message: "Determines which technique is used on Windows to capture the pointer.",
                    child: Row(
                      children: [
                        const Text("Mode:"),
                        _horizontalSpace,
                        SegmentedButton<WindowsPointerLockMode>(
                          showSelectedIcon: false,
                          selected: {_windowsMode},
                          onSelectionChanged: (modes) {
                            setState(() {
                              _windowsMode = modes.first;
                            });
                          },
                          segments: const [
                            ButtonSegment(
                              value: WindowsPointerLockMode.capture,
                              label: Text("Capture"),
                            ),
                            ButtonSegment(
                              value: WindowsPointerLockMode.clip,
                              label: Text("Clip"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Card(
                  margin: const EdgeInsets.all(20),
                  elevation: 1,
                  child: PointerLockArea(hidePointer: _hidePointer, windowsMode: _windowsMode),
                ),
              ),
            ),
            const MouseInfo(),
          ],
        ),
      ),
    );
  }
}

const _horizontalSpace = SizedBox(width: 10);
