import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/dinieco_provider.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback onStartMeal;
  final VoidCallback onViewAnalytics;
  final VoidCallback onViewDiagnostics;

  const HomeDashboardScreen({
    super.key,
    required this.onStartMeal,
    required this.onViewAnalytics,
    required this.onViewDiagnostics,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiniecoProvider>();
    final auth = context.watch<AuthProvider>();
    final meals = provider.meals;
    final isConnected = provider.padStatus.isConnected;
    final deviceId = provider.padStatus.deviceId;

    // Current user identity
    final userName = auth.currentUser?.fullName ?? 'Dining User';
    final initial = userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'U';

    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    // Genuine today's meal metrics
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayMeals = meals.where((m) => m.endTime.isAfter(todayStart)).toList();

    final todayCalories = todayMeals.fold<int>(0, (sum, m) => sum + m.totalCalories);
    final todayIntakeKg = todayMeals.fold<double>(0.0, (sum, m) => sum + (m.initialWeightG / 1000.0));
    final todayWasteG = todayMeals.fold<double>(0.0, (sum, m) => sum + m.remainingWeightG);
    final wasteScore = todayMeals.isNotEmpty
        ? (todayMeals.fold<int>(0, (sum, m) => sum + m.wasteScore) ~/ todayMeals.length)
        : (meals.isNotEmpty ? meals.first.wasteScore : 100);

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface.withValues(alpha: 0.95),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'DINIECO',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DiniecoColors.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Sign Out Action
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: DiniecoColors.primary, size: 22),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out of DINIECO?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DiniecoColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await auth.logout();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: GestureDetector(
              onTap: onViewDiagnostics,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DiniecoColors.secondaryContainer,
                  border: Border.all(color: DiniecoColors.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.init(),
        color: DiniecoColors.secondary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                child: Text(
                  '$timeGreeting, $userName',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DiniecoColors.onSurface,
                      ),
                ),
              ),

              // Smart Pad Hero Card
              _buildSmartPadHeroCard(context, deviceId, isConnected),

              const SizedBox(height: 24),

              // Today's Summary Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Summary",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAnalytics,
                    child: const Text(
                      'View Trends',
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DiniecoColors.surfaceTint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2x2 Bento Grid
              _buildBentoGrid(
                calories: todayCalories,
                intakeKg: todayIntakeKg,
                wasteG: todayWasteG,
                wasteScore: wasteScore,
                mealCount: todayMeals.length,
                hasMeals: todayMeals.isNotEmpty || meals.isNotEmpty,
              ),

              const SizedBox(height: 12),

              // Macro Footer Pill
              _buildMacroFooterPill(todayMeals),

              const SizedBox(height: 24),

              // AI Insight Card
              _buildAiInsightCard(provider),

              const SizedBox(height: 24),

              // Recent Meals Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Meals',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.onSurface,
                    ),
                  ),
                  if (meals.isNotEmpty)
                    TextButton(
                      onPressed: onViewAnalytics,
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.surfaceTint,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              _buildRecentMealsList(context, meals),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartPadHeroCard(BuildContext context, String deviceId, bool isConnected) {
    return Container(
      decoration: BoxDecoration(
        color: DiniecoColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DiniecoColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.scale_outlined,
              size: 160,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DINIECO Smart Pad',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$deviceId • ${isConnected ? "Live Connected" : "Pad Standby"}',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: DiniecoColors.inversePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? DiniecoColors.secondary : DiniecoColors.error,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'Connected' : 'Offline',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ready to track your meal?',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.secondaryFixed,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Place your meal on the DINIECO Pad or add a meal photo to analyze nutrition automatically.',
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onStartMeal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DiniecoColors.secondary,
                          foregroundColor: DiniecoColors.primaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, size: 18, color: DiniecoColors.primaryContainer),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Start Meal Session',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        isConnected ? 'Load Sensor Ready' : 'Manual / BLE Mode',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.inversePrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid({
    required int calories,
    required double intakeKg,
    required double wasteG,
    required int wasteScore,
    required int mealCount,
    required bool hasMeals,
  }) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        // Calories Card
        _buildBentoCard(
          icon: Icons.local_fire_department,
          label: 'Calories',
          value: '$calories',
          unit: 'kcal',
          progress: hasMeals ? (calories / 2200.0).clamp(0.0, 1.0) : 0.0,
          progressColor: DiniecoColors.amberAccent,
        ),
        // Food Intake Card
        _buildBentoCard(
          icon: Icons.restaurant,
          label: 'Intake',
          value: intakeKg.toStringAsFixed(2),
          unit: 'kg',
          subtext: hasMeals ? '$mealCount meals today' : 'No meals today',
        ),
        // Food Waste Card
        _buildBentoCard(
          icon: Icons.delete_outline,
          label: 'Waste',
          value: wasteG.toStringAsFixed(0),
          unit: 'g',
          subtext: hasMeals ? 'Today leftover' : '0g leftover',
        ),
        // Waste Score Card
        _buildBentoCard(
          icon: Icons.eco,
          label: 'Score',
          value: hasMeals ? '$wasteScore/100' : '--/100',
          unit: '',
          subtext: hasMeals ? (wasteScore >= 80 ? 'OPTIMAL' : 'MODERATE') : 'NO DATA',
          subtextColor: hasMeals ? DiniecoColors.secondary : DiniecoColors.outline,
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    double? progress,
    Color? progressColor,
    String? subtext,
    Color? subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DiniecoColors.surfaceTint),
              const SizedBox(width: 6),
              Text(
                label,
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.onSurface,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DiniecoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: DiniecoColors.surfaceTint.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? DiniecoColors.secondary),
                minHeight: 6,
              ),
            )
          else if (subtext != null)
            Text(
              subtext,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subtextColor ?? DiniecoColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildMacroFooterPill(List<MealRecord> todayMeals) {
    double protein = 0.0;
    double carbs = 0.0;
    double fat = 0.0;

    for (var m in todayMeals) {
      if (m.nutrition != null) {
        protein += m.nutrition!.totalProteinG;
        carbs += m.nutrition!.totalCarbsG;
        fat += m.nutrition!.totalFatG;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMacroItem('Protein', '${protein.toStringAsFixed(0)}g'),
          Container(width: 1, height: 20, color: DiniecoColors.outlineVariant),
          _buildMacroItem('Carbs', '${carbs.toStringAsFixed(0)}g'),
          Container(width: 1, height: 20, color: DiniecoColors.outlineVariant),
          _buildMacroItem('Fat', '${fat.toStringAsFixed(0)}g'),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Work Sans',
            fontSize: 11,
            color: DiniecoColors.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(DiniecoProvider provider) {
    String insightTitle = 'AI Dining Assistant';
    String insightMsg = 'No meal data available yet. Start your first meal session with the Smart Pad or take a photo to generate personalized insights.';

    if (provider.insights.isNotEmpty) {
      final first = provider.insights.first;
      insightTitle = first['title'] as String? ?? 'AI Dining Assistant';
      insightMsg = first['message'] as String? ?? insightMsg;
    } else if (provider.analytics['insights'] != null && (provider.analytics['insights'] as List).isNotEmpty) {
      insightMsg = (provider.analytics['insights'] as List).first.toString();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DiniecoColors.surfaceContainerLowest,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: DiniecoColors.primaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightTitle,
                  style: const TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insightMsg,
                  style: const TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 13,
                    height: 1.4,
                    color: DiniecoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentMealsList(BuildContext context, List<MealRecord> meals) {
    if (meals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: DiniecoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: DiniecoColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu, size: 32, color: DiniecoColors.outline),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Meals Recorded Yet',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DiniecoColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start your first meal session or capture a photo to begin tracking nutrition.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Work Sans',
                fontSize: 13,
                color: DiniecoColors.outline,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onStartMeal,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Start Meal Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.secondary,
                foregroundColor: DiniecoColors.primaryContainer,
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: meals.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final meal = meals[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DiniecoColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: DiniecoColors.surfaceContainerLow,
                ),
                child: const Icon(Icons.dinner_dining, color: DiniecoColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.mealName,
                      style: const TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DiniecoColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meal.initialWeightG.toStringAsFixed(0)}g • ${meal.totalCalories} kcal',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        color: DiniecoColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DiniecoColors.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Score ${meal.wasteScore}',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: DiniecoColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.wastePercentage.toStringAsFixed(1)}% waste',
                    style: const TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 11,
                      color: DiniecoColors.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
