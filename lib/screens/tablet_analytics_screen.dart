import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../providers/dinieco_provider.dart';

class TabletAnalyticsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const TabletAnalyticsScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<TabletAnalyticsScreen> createState() => _TabletAnalyticsScreenState();
}

class _TabletAnalyticsScreenState extends State<TabletAnalyticsScreen> {
  String _selectedRange = '7 Days';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiniecoProvider>();
    final analytics = provider.analytics;

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.primary,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Time Range Filter
                _buildHeaderAndFilter(isWide),

                const SizedBox(height: 20),

                // 4 Metric Overview Cards
                _buildMetricCardsRow(analytics),

                const SizedBox(height: 24),

                // Split Layout for Left and Right Columns
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildDailyWasteChartCard(analytics),
                            const SizedBox(height: 20),
                            _buildCategoryBreakdownCard(analytics),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          children: [
                            _buildDailyAveragesCard(analytics),
                            const SizedBox(height: 20),
                            _buildSustainabilityImpactCard(analytics),
                            const SizedBox(height: 20),
                            _buildAiInsightsSection(analytics, provider),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildDailyWasteChartCard(analytics),
                      const SizedBox(height: 20),
                      _buildCategoryBreakdownCard(analytics),
                      const SizedBox(height: 20),
                      _buildDailyAveragesCard(analytics),
                      const SizedBox(height: 20),
                      _buildSustainabilityImpactCard(analytics),
                      const SizedBox(height: 20),
                      _buildAiInsightsSection(analytics, provider),
                    ],
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderAndFilter(bool isWide) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Food Waste & Nutrition Trends',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DiniecoColors.primary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Monitor your genuine dining data, waste reduction, and nutrition.',
              style: TextStyle(
                fontFamily: 'Work Sans',
                fontSize: 14,
                color: DiniecoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: DiniecoColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['7 Days', '30 Days', '3 Months'].map((range) {
              final isSelected = _selectedRange == range;
              return GestureDetector(
                onTap: () => setState(() => _selectedRange = range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? DiniecoColors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCardsRow(Map<String, dynamic> analytics) {
    final todayWaste = (analytics['today_waste_g'] as num?)?.toDouble() ?? 0.0;
    final weeklyWaste = (analytics['weekly_waste_g'] as num?)?.toDouble() ?? 0.0;
    final monthlyWaste = (analytics['monthly_waste_kg'] as num?)?.toDouble() ?? 0.0;
    final wasteScore = (analytics['waste_score'] as num?)?.toInt() ?? 100;
    final scoreLabel = analytics['waste_score_label'] as String? ?? 'No Data';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: [
        _buildMetricTile(
          title: "TODAY'S WASTE",
          value: '${todayWaste.toStringAsFixed(0)}g',
          delta: todayWaste > 0 ? 'Today' : 'No leftovers',
        ),
        _buildMetricTile(
          title: 'WEEKLY WASTE',
          value: '${weeklyWaste.toStringAsFixed(0)}g',
          delta: weeklyWaste > 0 ? 'Past 7 days' : 'Zero waste',
        ),
        _buildMetricTile(
          title: 'MONTHLY PROJECTED',
          value: '${monthlyWaste.toStringAsFixed(1)} kg',
          delta: 'Projected',
        ),
        _buildMetricTile(
          title: 'WASTE SCORE',
          value: '$wasteScore/100',
          badgeText: scoreLabel,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    String? delta,
    String? badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiniecoColors.primaryContainer.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: DiniecoColors.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: DiniecoColors.primary,
                ),
              ),
              if (delta != null)
                Text(
                  delta,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.outline,
                  ),
                )
              else if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DiniecoColors.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyWasteChartCard(Map<String, dynamic> analytics) {
    final rawTrends = analytics['daily_trends'] as List<dynamic>? ?? [];
    double maxVal = 100.0;
    for (var t in rawTrends) {
      final w = (t['waste_g'] as num?)?.toDouble() ?? 0.0;
      if (w > maxVal) maxVal = w;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.primaryContainer.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Daily Waste Trend (Past 7 Days)',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (rawTrends.isEmpty)
            Container(
              height: 140,
              alignment: Alignment.center,
              child: const Text(
                'No recorded meal sessions in this period.',
                style: TextStyle(color: DiniecoColors.outline),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: rawTrends.map((t) {
                  final grams = (t['waste_g'] as num?)?.toDouble() ?? 0.0;
                  final day = t['day_name'] as String? ?? 'Day';
                  final heightFactor = (grams / maxVal).clamp(0.05, 1.0);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${grams.toStringAsFixed(0)}g',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 120 * heightFactor,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              DiniecoColors.primaryContainer,
                              DiniecoColors.secondary,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        day,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.primary,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(Map<String, dynamic> analytics) {
    final rawCats = analytics['category_breakdown'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.primaryContainer.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Waste Breakdown',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DiniecoColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (rawCats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No food category leftover records yet.',
                  style: TextStyle(color: DiniecoColors.outline),
                ),
              ),
            )
          else
            ...rawCats.map((c) {
              final name = c['category'] as String? ?? 'Category';
              final percent = (c['percentage'] as num?)?.toDouble() ?? 0.0;
              final colorHex = c['color_hex'] as String? ?? '#003315';
              Color color = DiniecoColors.primaryContainer;
              try {
                color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
              } catch (_) {}

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: DiniecoColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100.0,
                        backgroundColor: DiniecoColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDailyAveragesCard(Map<String, dynamic> analytics) {
    final calories = (analytics['avg_calories'] as num?)?.toInt() ?? 0;
    final protein = (analytics['avg_protein_g'] as num?)?.toDouble() ?? 0.0;
    final carbs = (analytics['avg_carbs_g'] as num?)?.toDouble() ?? 0.0;
    final fat = (analytics['avg_fat_g'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.primaryContainer.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Nutritional Averages',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DiniecoColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          _buildAvgRow('Calories', '$calories kcal'),
          const Divider(height: 16, color: DiniecoColors.surfaceContainerHigh),
          _buildAvgRow('Protein', '${protein.toStringAsFixed(0)}g'),
          const Divider(height: 16, color: DiniecoColors.surfaceContainerHigh),
          _buildAvgRow('Carbohydrates', '${carbs.toStringAsFixed(0)}g'),
          const Divider(height: 16, color: DiniecoColors.surfaceContainerHigh),
          _buildAvgRow('Fat', '${fat.toStringAsFixed(0)}g'),
        ],
      ),
    );
  }

  Widget _buildAvgRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Work Sans',
            fontSize: 14,
            color: DiniecoColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSustainabilityImpactCard(Map<String, dynamic> analytics) {
    final weeklyWaste = (analytics['weekly_waste_g'] as num?)?.toDouble() ?? 0.0;
    // Standard UN FAO environmental estimate: ~2.5 kg CO2e per kg food waste avoided
    final co2AvoidedKg = (weeklyWaste > 0 ? (weeklyWaste * 0.0025) : 0.0).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sustainability Impact',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            weeklyWaste > 0
                ? 'Tracking your meals has helped identify leftovers and avoid approximately $co2AvoidedKg kg of CO2 equivalent emissions this week.'
                : 'Log meals with the DINIECO Smart Pad to generate your environmental and carbon footprint savings metrics.',
            style: const TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 13,
              color: DiniecoColors.inverseOnSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightsSection(Map<String, dynamic> analytics, DiniecoProvider provider) {
    List<String> insightList = [];
    if (provider.insights.isNotEmpty) {
      insightList = provider.insights.map((i) => i['message'] as String? ?? '').where((m) => m.isNotEmpty).toList();
    } else if (analytics['insights'] != null) {
      insightList = (analytics['insights'] as List).map((i) => i.toString()).toList();
    }

    if (insightList.isEmpty) {
      insightList = [
        'Place your meal on the Smart Pad to generate real-time AI food waste and portion recommendations.'
      ];
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, size: 20, color: DiniecoColors.secondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DINIECO AI Insights',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insightList.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 13,
                    color: DiniecoColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
