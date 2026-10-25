import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/dinieco_colors.dart';

class CircularWeightGauge extends StatelessWidget {
  final double weightGrams;
  final double maxWeightGrams;
  final bool isStabilized;
  final double? netFoodWeightGrams;
  final double size;

  const CircularWeightGauge({
    super.key,
    required this.weightGrams,
    this.maxWeightGrams = 1200.0,
    this.isStabilized = true,
    this.netFoodWeightGrams,
    this.size = 200.0,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (weightGrams / maxWeightGrams).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _GaugePainter(
                  progress: progress,
                  trackColor: DiniecoColors.surfaceVariant,
                  progressColor: DiniecoColors.secondaryFixed,
                  strokeWidth: 10.0,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${weightGrams.toStringAsFixed(0)}g',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Total Weight',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: DiniecoColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStabilized ? DiniecoColors.secondaryContainer : DiniecoColors.amberAccent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isStabilized ? 'Stabilized' : 'Weighing...',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (netFoodWeightGrams != null) ...[
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Work Sans',
                fontSize: 14,
                color: DiniecoColors.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: 'Net food portion: '),
                TextSpan(
                  text: '${netFoodWeightGrams!.toStringAsFixed(0)}g',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _GaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background circle
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc starting from top (-90 degrees)
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
