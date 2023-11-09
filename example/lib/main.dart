import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/manual_example.dart';

import 'stream_example.dart';

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
  _UsageMode _usageMode = _UsageMode.stream;
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
                // Usage mode
                SegmentedButton<_UsageMode>(
                  showSelectedIcon: false,
                  selected: {_usageMode},
                  onSelectionChanged: (modes) {
                    setState(() {
                      _usageMode = modes.first;
                    });
                  },
                  segments: const [
                    ButtonSegment(
                      value: _UsageMode.stream,
                      label: Text("Stream usage"),
                    ),
                    ButtonSegment(
                      value: _UsageMode.manual,
                      label: Text("Manual usage"),
                    ),
                  ],
                ),
                // Windows mode
                if (_usageMode == _UsageMode.stream) Tooltip(
                  message: "Windows mode should make a difference on Windows only",
                  child: Row(
                    children: [
                      const Text("Windows mode:"),
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
                  child: switch (_usageMode) {
                    _UsageMode.manual => ManualExample(hidePointer: _hidePointer),
                    _UsageMode.stream => StreamExample(hidePointer: _hidePointer, windowsMode: _windowsMode),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _UsageMode {
  manual,
  stream,
}

const _horizontalSpace = SizedBox(width: 10);