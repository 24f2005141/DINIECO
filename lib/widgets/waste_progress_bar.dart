import 'package:flutter/material.dart';
import '../core/theme/dinieco_colors.dart';

class WasteProgressBar extends StatelessWidget {
  final double consumedPercentage; // e.g. 75.1
  final double height;
  final bool showLegend;

  const WasteProgressBar({
    super.key,
    required this.consumedPercentage,
    this.height = 12.0,
    this.showLegend = true,
  });

  @override
  Widget build(BuildContext context) {
    final validPercentage = consumedPercentage.clamp(0.0, 100.0);
    final remainingPercentage = (100.0 - validPercentage).clamp(0.0, 100.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: const Color(0xFFFCD34D), // Remaining yellow/amber track
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: validPercentage / 100.0,
              child: Container(
                decoration: BoxDecoration(
                  color: DiniecoColors.primary,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Consumed (${validPercentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Remaining (${remainingPercentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFCD34D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}
