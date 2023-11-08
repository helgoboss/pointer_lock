import 'package:flutter/material.dart';
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
  _Usage _usage = _Usage.manual;
  bool _hidePointer = false;

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
                // Mode
                Tooltip(
                  message: "Usage should make a difference on Windows only",
                  child: SegmentedButton<_Usage>(
                    selected: {_usage},
                    onSelectionChanged: (usages) {
                      setState(() {
                        _usage = usages.first;
                      });
                    },
                    segments: const [
                      ButtonSegment(
                        value: _Usage.manual,
                        label: Text("Manual usage"),
                      ),
                      ButtonSegment(
                        value: _Usage.stream,
                        label: Text("Stream usage"),
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
                  child: switch (_usage) {
                    _Usage.manual => ManualExample(hidePointer: _hidePointer),
                    _Usage.stream => StreamExample(hidePointer: _hidePointer),
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

enum _Usage {
  manual,
  stream,
}
