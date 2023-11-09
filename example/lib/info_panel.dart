import 'package:flutter/material.dart';

class InfoPanel extends StatelessWidget {
  final Offset lastPointerDelta;
  final Offset accumulation;

  const InfoPanel({
    super.key,
    required this.lastPointerDelta,
    required this.accumulation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pointer delta / Accumulation',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 20),
        Text(
          '$lastPointerDelta / $accumulation',
          style: theme.textTheme.headlineLarge,
        ),
      ],
    );
  }
}
