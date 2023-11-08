import 'package:flutter/material.dart';

class InfoPanel extends StatelessWidget {
  final Offset lastPointerDelta;

  const InfoPanel({super.key, required this.lastPointerDelta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pointer delta:',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Text(
          '$lastPointerDelta',
          style: theme.textTheme.headlineLarge,
        ),
      ],
    );
  }
}
