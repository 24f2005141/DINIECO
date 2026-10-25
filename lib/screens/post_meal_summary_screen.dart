import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../providers/dinieco_provider.dart';
import '../widgets/waste_progress_bar.dart';

class PostMealSummaryScreen extends StatelessWidget {
  final VoidCallback onReturnHome;
  final VoidCallback onViewAnalytics;

  const PostMealSummaryScreen({
    super.key,
    required this.onReturnHome,
    required this.onViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiniecoProvider>();
    final meal = provider.lastSavedMeal ?? (provider.meals.isNotEmpty ? provider.meals.first : null);

    if (meal == null) {
      return Scaffold(
        backgroundColor: DiniecoColors.background,
        appBar: AppBar(
          backgroundColor: DiniecoColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
            onPressed: onReturnHome,
          ),
          title: const Text(
            'Post-Meal Summary',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DiniecoColors.primary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: DiniecoColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_outlined,
                    size: 40,
                    color: DiniecoColors.outline,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Recent Meal Session',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete a meal session on your Smart Dining Pad to see your real-time waste analysis, nutrition recap, and AI feedback.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 14,
                    color: DiniecoColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onReturnHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DiniecoColors.secondary,
                    foregroundColor: DiniecoColors.primaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final initialWeight = meal.initialWeightG;
    final finalWeight = meal.remainingWeightG;
    final consumedWeight = meal.consumedWeightG;
    final consumedPercent = initialWeight > 0
        ? (consumedWeight / initialWeight * 100.0).clamp(0.0, 100.0)
        : 0.0;
    final remainingPercent = (100.0 - consumedPercent).clamp(0.0, 100.0);
    final wasteScore = meal.wasteScore;
    final leftovers = meal.leftovers;

    final nutrition = meal.nutrition;
    final observation = meal.aiObservation.isNotEmpty
        ? meal.aiObservation
        : (wasteScore >= 80
            ? 'Excellent job finishing your meal efficiently with minimal food waste!'
            : 'Consider taking slightly smaller portions initially to reduce plate waste.');

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
          onPressed: onReturnHome,
        ),
        title: const Text(
          'Post-Meal Summary',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Meal Recorded Pill Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: DiniecoColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Meal session successfully recorded for ${meal.mealName.isNotEmpty ? meal.mealName : "Meal Session"}',
                      style: const TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DiniecoColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Calibration & Device Info Pill
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: meal.isCalibrated ? const Color(0xFFECF6EC) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          meal.isCalibrated ? Icons.verified : Icons.warning_amber_rounded,
                          size: 13,
                          color: meal.isCalibrated ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          meal.isCalibrated ? 'Load-Cell: Calibrated' : 'Load-Cell: Uncalibrated',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: meal.isCalibrated ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DiniecoColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meal.plateWeightG != null
                          ? 'Plate: ${meal.plateWeightG!.toStringAsFixed(1)}g (${meal.plateWeightMode})'
                          : 'Plate: Unknown (Gross Mode)',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: DiniecoColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Unexpected Increase Banner (if flagged)
            if (meal.isFlaggedIncrease) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notice: Final weight was higher than starting weight. Food addition or plate change detected during session. Food weight reduction recorded as 0.0g.',
                        style: TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Dual Photo Display (Start and End photos)
            if (meal.startImageUrl != null && meal.endImageUrl != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Before Meal (Start)',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            meal.startImageUrl!.startsWith('http')
                                ? meal.startImageUrl!
                                : '${provider.apiService.baseUrl}${meal.startImageUrl}',
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'After Meal (End)',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            meal.endImageUrl!.startsWith('http')
                                ? meal.endImageUrl!
                                : '${provider.apiService.baseUrl}${meal.endImageUrl}',
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else if (meal.imageUrl != null && meal.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  meal.imageUrl!.startsWith('http')
                      ? meal.imageUrl!
                      : '${provider.apiService.baseUrl}${meal.imageUrl}',
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Main Sustainability & Waste Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: DiniecoColors.primary.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Food Waste Score',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECF6EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          wasteScore >= 80 ? 'Optimal' : (wasteScore >= 60 ? 'Moderate' : 'High Waste'),
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004C22),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$wasteScore',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: DiniecoColors.primary,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const Text(
                        ' / 100',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3-Column Weight Comparison
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildWeightStatCol(
                        meal.startFoodWeightG != null ? 'Initial Food' : 'Initial Gross',
                        '${(meal.startFoodWeightG ?? initialWeight).toStringAsFixed(1)}g',
                        meal.startFoodWeightG != null ? '(Net Food)' : '(Gross)',
                        DiniecoColors.onSurface,
                      ),
                      Container(width: 1, height: 40, color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
                      _buildWeightStatCol(
                        'Food Removed',
                        '${(meal.weightReductionG ?? consumedWeight).toStringAsFixed(1)}g',
                        '(${consumedPercent.toStringAsFixed(1)}%)',
                        DiniecoColors.primary,
                      ),
                      Container(width: 1, height: 40, color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
                      _buildWeightStatCol(
                        meal.endFoodWeightG != null ? 'Remaining Food' : 'Remaining Gross',
                        '${(meal.endFoodWeightG ?? finalWeight).toStringAsFixed(1)}g',
                        '(${remainingPercent.toStringAsFixed(1)}%)',
                        const Color(0xFFD97706),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Visual Consumption Ratio Bar
                  WasteProgressBar(
                    consumedPercentage: consumedPercent,
                    height: 12,
                  ),
                  const SizedBox(height: 12),

                  // Semantic distinction footnote
                  const Text(
                    'Note: Weight removed from plate is reported as food removed / weight reduction. It is not assumed to be confirmed food waste.',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 10,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Leftover Breakdown Section
            const Text(
              'Leftover Breakdown',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DiniecoColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            if (leftovers.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: DiniecoColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.eco, color: DiniecoColors.secondary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Zero plate waste recorded for this meal session! Excellent sustainability score.',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 13,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leftovers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = leftovers[index];

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: DiniecoColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.category,
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DiniecoColors.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${item.percentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DiniecoColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${item.weightG.toStringAsFixed(0)}g',
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: DiniecoColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // AI Recommendation Card ("Helpful Observation")
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: DiniecoColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Helpful Observation',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          observation,
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 13,
                            height: 1.4,
                            color: DiniecoColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nutrition Recap Section
            const Text(
              'Nutrition Recap',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DiniecoColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildNutritionPill('Calories', '${nutrition?.totalCalories ?? meal.totalCalories}', 'kcal'),
                const SizedBox(width: 8),
                _buildNutritionPill('Protein', '${(nutrition?.totalProteinG ?? meal.components.fold<double>(0.0, (s, c) => s + c.proteinG)).toStringAsFixed(0)}g', ''),
                const SizedBox(width: 8),
                _buildNutritionPill('Carbs', '${(nutrition?.totalCarbsG ?? meal.components.fold<double>(0.0, (s, c) => s + c.carbsG)).toStringAsFixed(0)}g', ''),
                const SizedBox(width: 8),
                _buildNutritionPill('Fat', '${(nutrition?.totalFatG ?? meal.components.fold<double>(0.0, (s, c) => s + c.fatG)).toStringAsFixed(0)}g', ''),
              ],
            ),

            const SizedBox(height: 32),

            // Action Buttons
            ElevatedButton(
              onPressed: onReturnHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.secondary,
                foregroundColor: DiniecoColors.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save to History & Return Home',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton(
              onPressed: onViewAnalytics,
              style: OutlinedButton.styleFrom(
                foregroundColor: DiniecoColors.primary,
                side: const BorderSide(color: DiniecoColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Detailed Waste Analytics',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightStatCol(String title, String mainValue, String subValue, Color valueColor) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Work Sans',
            fontSize: 11,
            color: DiniecoColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          mainValue,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        if (subValue.isNotEmpty)
          Text(
            subValue,
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
      ],
    );
  }

  Widget _buildNutritionPill(String title, String val, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: DiniecoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Work Sans',
                fontSize: 11,
                color: DiniecoColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.onSurface,
                ),
                children: [
                  TextSpan(text: val),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
