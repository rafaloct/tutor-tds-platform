import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Assinatura cromática institucional do Tutor TDS.
class TdsBrandStripe extends StatelessWidget {
  const TdsBrandStripe({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Row(
        children: [
          Expanded(child: ColoredBox(color: AppTheme.primary)),
          Expanded(child: ColoredBox(color: AppTheme.secondary)),
          Expanded(child: ColoredBox(color: AppTheme.accent)),
          Expanded(child: ColoredBox(color: AppTheme.success)),
        ],
      ),
    );
  }
}
