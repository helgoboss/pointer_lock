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
  SessionTrigger _sessionTrigger = SessionTrigger.drag;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Try some mouse interactions in the area below!'),
          centerTitle: true,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Tooltip(
                  message:
                      "Determines how to activate and deactivate locking.",
                  child: Row(
                    spacing: 10,
                    children: [
                      const Text("Trigger:"),
                      SegmentedButton(
                        showSelectedIcon: false,
                        selected: {_sessionTrigger},
                        onSelectionChanged: (triggers) {
                          setState(() {
                            _sessionTrigger = triggers.first;
                          });
                        },
                        segments: const [
                          ButtonSegment(
                            value: SessionTrigger.drag,
                            label: Text("Drag"),
                          ),
                          ButtonSegment(
                            value: SessionTrigger.clickAndEscape,
                            label: Text("Click/Escape"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Hide pointer
                Row(
                  spacing: 10,
                  children: [
                    const Text("Hide pointer during lock"),
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
                    message:
                        "Determines which technique is used on Windows to capture the pointer.",
                    child: Row(
                      spacing: 10,
                      children: [
                        const Text("Windows mode:"),
                        SegmentedButton(
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
                  child: PointerLockArea(
                    hidePointer: _hidePointer,
                    windowsMode: _windowsMode,
                    sessionTrigger: _sessionTrigger,
                  ),
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
