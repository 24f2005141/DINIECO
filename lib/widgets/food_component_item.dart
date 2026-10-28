import 'package:flutter/material.dart';
import '../core/theme/dinieco_colors.dart';
import '../models/models.dart';

class FoodComponentItemWidget extends StatelessWidget {
  final FoodComponentItem component;
  final ValueChanged<double>? onWeightChanged;
  final VoidCallback? onRemove;

  const FoodComponentItemWidget({
    super.key,
    required this.component,
    this.onWeightChanged,
    this.onRemove,
  });

  IconData _getIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('papaya') || lower.contains('cucumber') || lower.contains('fruit') ||
        lower.contains('apple') || lower.contains('banana') || lower.contains('melon') ||
        lower.contains('berry') || lower.contains('orange')) {
      return Icons.eco;
    } else if (lower.contains('rice') || lower.contains('grain') || lower.contains('oats')) {
      return Icons.rice_bowl;
    } else if (lower.contains('dal') || lower.contains('soup') || lower.contains('curry')) {
      return Icons.soup_kitchen;
    } else if (lower.contains('vegetable') || lower.contains('sabzi')) {
      return Icons.eco;
    } else if (lower.contains('paneer') || lower.contains('protein') || lower.contains('chicken') || lower.contains('egg')) {
      return Icons.egg;
    } else if (lower.contains('salad') || lower.contains('kachumber') || lower.contains('greens')) {
      return Icons.grass;
    } else if (lower.contains('roti') || lower.contains('bread') || lower.contains('naan') || lower.contains('chapati')) {
      return Icons.bakery_dining;
    } else if (lower.contains('curd') || lower.contains('yogurt') || lower.contains('milk')) {
      return Icons.local_cafe;
    }
    return Icons.restaurant;
  }

  void _showWeightEditorDialog(BuildContext context) {
    if (onWeightChanged == null) return;
    double currentVal = component.weightG;
    final controller = TextEditingController(text: currentVal.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: DiniecoColors.surface,
          title: Text(
            'Adjust ${component.name}',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: DiniecoColors.primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preparation: ${component.preparationStyle}',
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 12,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Portion Weight (g)',
                  suffixText: 'g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      final val = (double.tryParse(controller.text) ?? currentVal) - 20.0;
                      controller.text = val.clamp(0.0, 1000.0).toStringAsFixed(0);
                    },
                    child: const Text('-20g'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final val = (double.tryParse(controller.text) ?? currentVal) + 20.0;
                      controller.text = val.clamp(0.0, 1000.0).toStringAsFixed(0);
                    },
                    child: const Text('+20g'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: DiniecoColors.outline)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.secondary,
                foregroundColor: DiniecoColors.primaryContainer,
              ),
              onPressed: () {
                final parsed = double.tryParse(controller.text);
                if (parsed != null && parsed >= 0) {
                  onWeightChanged!(parsed);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save Portion'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DiniecoColors.surfaceVariant,
            ),
            child: Icon(
              _getIconForName(component.name),
              color: DiniecoColors.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        component.name,
                        style: const TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${(component.confidence * 100).toInt()}%)',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        color: DiniecoColors.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${component.caloriesKcal} kcal',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DiniecoColors.onSurfaceVariant,
                      ),
                    ),
                    if (component.uncertaintyMinKcal > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(±10%)',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 10,
                          color: DiniecoColors.outline.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onWeightChanged != null ? () => _showWeightEditorDialog(context) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: DiniecoColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    component.weightG.toStringAsFixed(0),
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'g',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  if (onWeightChanged != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: DiniecoColors.outline),
                  ],
                ],
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: DiniecoColors.outline),
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
