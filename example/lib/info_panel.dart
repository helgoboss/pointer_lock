import 'package:flutter/material.dart';

class InfoPanel extends StatelessWidget {
  final Offset lastPointerDelta;
  final Offset accumulation;
  final String? additionalText;

  const InfoPanel({
    super.key,
    required this.lastPointerDelta,
    required this.accumulation,
    this.additionalText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final additionalText = this.additionalText;
    return Column(
      spacing: 20,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pointer delta / Accumulation',
          style: theme.textTheme.headlineMedium,
        ),
        Text(
          '$lastPointerDelta / $accumulation',
          style: theme.textTheme.headlineLarge,
        ),
        if (additionalText != null)
          Text(
            additionalText,
            style: theme.textTheme.bodySmall,
          )
      ],
    );
  }
}
