import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pointer_lock/pointer_lock.dart';
import 'package:pointer_lock_example/free_example.dart';
import 'package:pointer_lock_example/drag_example.dart';
import 'package:pointer_lock_example/mouse_info.dart';

void main() async {
  // This initializes binary messengers etc. Important to execute before doing method channel things.
  WidgetsFlutterBinding.ensureInitialized();
  await pointerLock.ensureInitialized();
  // _debugIncomingPointerPackets();
  runApp(const MyApp());
}

// ignore: unused_element
void _debugIncomingPointerPackets() {
  var binding = WidgetsFlutterBinding.ensureInitialized();
  final previousCallback = binding.platformDispatcher.onPointerDataPacket!;
  binding.platformDispatcher.onPointerDataPacket = (packet) async {
    for (final p in packet.data) {
      debugPrint("${p.change}");
    }
    previousCallback(packet);
  };
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PointerLockCursor _cursor = PointerLockCursor.hidden;
  PointerLockWindowsMode _windowsMode = PointerLockWindowsMode.capture;
  _Mode _mode = _Mode.drag;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Pointer Lock Example'),
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
                        selected: {_mode},
                        onSelectionChanged: (triggers) {
                          setState(() {
                            _mode = triggers.first;
                          });
                        },
                        segments: const [
                          ButtonSegment(
                            value: _Mode.drag,
                            label: Text("Drag"),
                          ),
                          ButtonSegment(
                            value: _Mode.free,
                            label: Text("Free"),
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
                      value: _cursor == PointerLockCursor.hidden,
                      onChanged: (value) {
                        setState(() {
                          _cursor = value ? PointerLockCursor.hidden : PointerLockCursor.normal;
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
                              value: PointerLockWindowsMode.capture,
                              label: Text("Capture"),
                            ),
                            ButtonSegment(
                              value: PointerLockWindowsMode.clip,
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
                  child: switch (_mode) {
                    _Mode.drag => DragExample(
                      cursor: _cursor,
                      windowsMode: _windowsMode,
                    ),
                    // TODO: Handle this case.
                    _Mode.free => FreeExample(
                      cursor: _cursor,
                      windowsMode: _windowsMode,
                    ),
                  },
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

enum _Mode {
  drag,
  free,
}
