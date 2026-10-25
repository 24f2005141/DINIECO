import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../models/ble_models.dart';
import '../providers/ble_provider.dart';
import '../providers/dinieco_provider.dart';
import '../widgets/circular_weight_gauge.dart';
import '../widgets/food_component_item.dart';

class ActiveSessionScreen extends StatefulWidget {
  final VoidCallback onFinishMeal;
  final VoidCallback onCancel;

  const ActiveSessionScreen({
    super.key,
    required this.onFinishMeal,
    required this.onCancel,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _isTareInProgress = false;
  bool _isPickingImage = false;
  late final TextEditingController _manualWeightController;
  late final TextEditingController _plateWeightInputController;
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        final provider = context.read<DiniecoProvider>();
        final success = await provider.uploadAndAnalyzePhoto(picked);
        if (!success && mounted && provider.photoError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notice: ${provider.photoError}'),
              backgroundColor: DiniecoColors.primary,
            ),
          );
        } else if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${provider.aiVerified ? "AI recognized" : "Catalog estimate"}: ${provider.currentDishName} (${(provider.currentConfidence * 100).toStringAsFixed(0)}% confidence)',
              ),
              backgroundColor: DiniecoColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access camera/gallery: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      } else {
        _isPickingImage = false;
      }
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DiniecoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DiniecoColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Meal Photo',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Capture or upload an overhead photo of your plate for AI food recognition and nutrition breakdown.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Work Sans',
                    fontSize: 12,
                    color: DiniecoColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: DiniecoColors.surfaceContainerLow,
                    child: Icon(Icons.camera_alt, color: DiniecoColors.primary),
                  ),
                  title: const Text(
                    'Take Photo with Camera',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  subtitle: const Text('Capture live plate frame overhead', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: DiniecoColors.surfaceContainerLow,
                    child: Icon(Icons.photo_library, color: DiniecoColors.primary),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  subtitle: const Text('Select existing food photo from device', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _manualWeightController = TextEditingController(text: '486');
    _plateWeightInputController = TextEditingController(text: '350');
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<DiniecoProvider>();
      if (provider.hasActiveSession) {
        final session = provider.activeSession!;
        final diff = DateTime.now().difference(session.startTime).inSeconds;
        setState(() {
          _elapsedSeconds = diff > 0 ? diff : 0;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _manualWeightController.dispose();
    _plateWeightInputController.dispose();
    super.dispose();
  }

  Future<void> _handleTare() async {
    setState(() => _isTareInProgress = true);
    final provider = context.read<DiniecoProvider>();
    await provider.tarePad();
    if (mounted) {
      setState(() => _isTareInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Smart Pad tared successfully (0.0g baseline)'),
          backgroundColor: DiniecoColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleFinishMeal() async {
    final provider = context.read<DiniecoProvider>();
    final currentWeight = provider.currentWeightG;
    // Calculate remaining weight (e.g. current simulated weight or 25% leftover)
    final remaining = currentWeight > 0 ? (currentWeight * 0.25).clamp(10.0, 300.0) : 120.0;
    
    final meal = await provider.saveMealSession(remainingWeightG: remaining);
    if (meal != null && mounted) {
      widget.onFinishMeal();
    }
  }

  void _showDishPickerModal(BuildContext context) {
    final provider = context.read<DiniecoProvider>();
    final presets = [
      {'name': 'Vegetable Rice Bowl', 'desc': 'Rice, Toor Dal, Mixed Vegetables, Paneer, Kachumber'},
      {'name': 'Paneer Roti Meal', 'desc': 'Whole wheat rotis, paneer curry, vegetables, salad'},
      {'name': 'South Indian Breakfast', 'desc': 'Steamed idlis, sambar, coconut chutney'},
      {'name': 'High Protein Salad Bowl', 'desc': 'Paneer cubes, tossed vegetables, kachumber salad'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: DiniecoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DiniecoColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'AI Dish Recognition & Rescan',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Model: ${provider.aiModel} (${provider.aiVerified ? "Verified Live Gemini" : "Deterministic CV Catalog"})',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              ...presets.map((p) {
                final isSelected = provider.currentDishName == p['name'];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? DiniecoColors.secondary : DiniecoColors.outline,
                  ),
                  title: Text(
                    p['name']!,
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  subtitle: Text(
                    p['desc']!,
                    style: const TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 11,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.startNewMealSession(dishHint: p['name']!);
                  },
                );
              }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DiniecoColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DiniecoColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.startNewMealSession(dishHint: provider.currentDishName);
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Rescan Current Meal Components'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DiniecoColors.primaryContainer,
                    foregroundColor: DiniecoColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiniecoProvider>();
    final ble = context.watch<BleProvider>();

    // Forward BLE telemetry to DiniecoProvider if connected
    if (ble.status == BleConnectionStatus.connected && ble.latestPacket != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.updateFromBleTelemetry(
          ble.latestPacket!,
          isTestProfile: ble.currentProfile.profileId == 'esp32_test' || ble.latestPacket!.isTestSource,
          deviceId: ble.connectedDevice?.id,
        );
      });
    } else if (ble.status == BleConnectionStatus.disconnected && provider.padStatus.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.onBleDisconnected();
      });
    }

    if (provider.hasActiveSession) {
      return _buildLiveMeasurementScreen(context, provider, ble);
    }

    return _buildPreFlightAndSetupScreen(context, provider, ble);
  }

  Widget _buildLiveMeasurementScreen(BuildContext context, DiniecoProvider provider, BleProvider ble) {
    final session = provider.activeSession!;
    final isConnected = ble.status.isConnected;
    final isCalibrated = session.isCalibrated;
    final liveWeight = provider.smoothedWeightG;
    final currentFoodWeight = provider.currentRemainingFoodWeightG;
    final weightReduction = provider.currentWeightReductionG ?? 0.0;

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
          onPressed: () => _confirmDiscardSession(context, provider),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Meal Measurement',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DiniecoColors.primary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? DiniecoColors.secondary : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${session.mealName} • ${_formatDuration(_elapsedSeconds)}',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 11,
                    color: DiniecoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Connectivity',
            icon: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? DiniecoColors.secondary : const Color(0xFFD97706),
            ),
            onPressed: () => Navigator.of(context).pushNamed('/connectivity'),
          ),
          IconButton(
            tooltip: 'Discard Session',
            icon: const Icon(Icons.close, color: DiniecoColors.outline),
            onPressed: () => _confirmDiscardSession(context, provider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Disconnection Alert Banner
            if (!isConnected)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_searching, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smart Dining Pad Disconnected',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Auto-reconnecting... Your live meal session is safely preserved.',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontSize: 11,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/connectivity'),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Live Telemetry Badge & Calibration Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: provider.isWeightStable ? const Color(0xFFECF6EC) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: provider.isWeightStable ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isWeightStable ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isWeightStable ? 'Scale Reading Stable' : 'Scale Stabilizing (HX711)...',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: provider.isWeightStable ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCalibrated ? DiniecoColors.surfaceContainerLow : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCalibrated ? Icons.verified : Icons.warning_amber_rounded,
                        size: 13,
                        color: isCalibrated ? DiniecoColors.secondary : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCalibrated ? 'Load-Cell Calibrated' : 'Uncalibrated',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCalibrated ? DiniecoColors.primary : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Prominent Current Live Gross Weight Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  const Text(
                    'CURRENT WEIGHT ON PAD (SMOOTHED)',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        liveWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: DiniecoColors.primary,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'g',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Simulation slider in live view for tests/demo
                  Row(
                    children: [
                      const Text('Simulate Eat:', style: TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: DiniecoColors.onSurfaceVariant)),
                      Expanded(
                        child: Slider(
                          value: liveWeight.clamp(0.0, 1500.0),
                          min: 0.0,
                          max: 1500.0,
                          activeColor: DiniecoColors.secondary,
                          inactiveColor: DiniecoColors.surfaceVariant,
                          onChanged: (val) {
                            provider.setSimulatedWeight(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Prominent Food Weight Reduction Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECF6EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.trending_down, color: Color(0xFF16A34A), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weight Reduction / Food Removed',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${weightReduction.toStringAsFixed(1)}g removed from plate',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Weight reduction from plate is reported as food removed (not confirmed waste).',
                          style: TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 10,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4-Metric Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMetricTile(
                        'Initial Gross',
                        '${session.startGrossWeightG?.toStringAsFixed(1) ?? "—"}g',
                        'Total starting weight',
                        DiniecoColors.primary,
                      ),
                      Container(width: 1, height: 44, color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
                      _buildMetricTile(
                        'Plate Weight',
                        session.plateWeightG != null
                            ? '${session.plateWeightG!.toStringAsFixed(1)}g'
                            : 'Not Set',
                        session.plateWeightMode == 'measured'
                            ? 'Scale Measured'
                            : (session.plateWeightMode == 'manual' ? 'Manual Input' : 'Gross Mode'),
                        DiniecoColors.onSurface,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      _buildMetricTile(
                        'Initial Food',
                        session.startFoodWeightG != null
                            ? '${session.startFoodWeightG!.toStringAsFixed(1)}g'
                            : '—',
                        session.startFoodWeightG != null ? 'Gross minus plate' : 'Plate unknown',
                        DiniecoColors.primary,
                      ),
                      Container(width: 1, height: 44, color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
                      _buildMetricTile(
                        'Current Remaining Food',
                        currentFoodWeight != null
                            ? '${currentFoodWeight.toStringAsFixed(1)}g'
                            : '${liveWeight.toStringAsFixed(1)}g (Gross)',
                        currentFoodWeight != null ? 'Food portion remaining' : 'Gross remaining',
                        const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Starting Plate Photo preview (if available)
            if (session.startImageUrl != null || provider.selectedMealPhotoBytes != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DiniecoColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    if (provider.selectedMealPhotoBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          provider.selectedMealPhotoBytes!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: DiniecoColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.photo, color: DiniecoColors.primary),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Starting Plate Photo Attached',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DiniecoColors.primary,
                            ),
                          ),
                          Text(
                            'Captured via ${session.startImageSource == "app_camera" ? "App Camera" : "Pad Camera"}',
                            style: const TextStyle(
                              fontFamily: 'Work Sans',
                              fontSize: 11,
                              color: DiniecoColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Readings History Stream
            if (session.readingsHistory.isNotEmpty) ...[
              const Text(
                'Recent Readings Stream',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DiniecoColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: session.readingsHistory.reversed.take(5).map((r) {
                    final w = (r['gross_weight_g'] as num?)?.toDouble() ?? 0.0;
                    return Column(
                      children: [
                        Text(
                          '${w.toStringAsFixed(0)}g',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (r['stable'] == true) ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // End Meal Button
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : () => _showEndMealDialog(context, provider, ble),
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.secondary,
                foregroundColor: DiniecoColors.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: provider.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: DiniecoColors.primaryContainer))
                  : const Icon(Icons.stop_circle_outlined, size: 22, color: DiniecoColors.primaryContainer),
              label: Text(
                provider.isLoading ? 'Finalizing...' : 'End Meal & Finalize',
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _confirmDiscardSession(context, provider),
              child: const Text(
                'Discard Active Meal Session',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 13,
                  color: DiniecoColors.error,
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

  Widget _buildPreFlightAndSetupScreen(BuildContext context, DiniecoProvider provider, BleProvider ble) {
    final components = provider.detectedComponents;
    final currentWeight = provider.currentWeightG;
    final dishName = provider.currentDishName;
    final isManual = provider.weightSource == 'manual';

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
          onPressed: widget.onCancel,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Meal Session',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DiniecoColors.primary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isManual ? DiniecoColors.outline : DiniecoColors.secondary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isManual
                      ? 'Manual Weight Fallback'
                      : '${provider.padStatus.deviceId} (BLE Live)',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 11,
                    color: DiniecoColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hardware & BLE Connectivity',
            icon: Icon(
              provider.padStatus.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: provider.padStatus.isConnected ? DiniecoColors.secondary : DiniecoColors.outline,
            ),
            onPressed: () => Navigator.of(context).pushNamed('/connectivity'),
          ),
          IconButton(
            tooltip: 'Add Meal Photo',
            icon: const Icon(Icons.add_a_photo_outlined, color: DiniecoColors.primary),
            onPressed: () => _showImageSourcePicker(context),
          ),
          IconButton(
            tooltip: 'Tare Smart Pad',
            icon: _isTareInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: DiniecoColors.primary),
                  )
                : const Icon(Icons.exposure_zero, color: DiniecoColors.primary),
            onPressed: isManual || _isTareInProgress ? null : _handleTare,
          ),
          IconButton(
            tooltip: 'Rescan Dish',
            icon: const Icon(Icons.restaurant_menu, color: DiniecoColors.primary),
            onPressed: () => _showDishPickerModal(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // In-Progress Session Resume Banner (if available)
            if (provider.activeSession != null && !provider.activeSession!.isCompleted)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DiniecoColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restore, color: DiniecoColors.secondaryFixed, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'In-Progress Meal Session Found',
                            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                          ),
                          Text(
                            '${provider.activeSession!.mealName} (${provider.activeSession!.startTime.hour}:${provider.activeSession!.startTime.minute.toString().padLeft(2, '0')})',
                            style: const TextStyle(fontFamily: 'Space Grotesk', color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DiniecoColors.secondary,
                        foregroundColor: DiniecoColors.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Resume'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      onPressed: () => provider.cancelActiveMealSession(),
                    ),
                  ],
                ),
              ),

            // Mode Selector Toggle (Mode A: BLE Device vs Mode B: Manual)
            _buildModeSelector(provider),

            const SizedBox(height: 14),

            // Device Readiness Checklist Card
            _buildDeviceReadinessCard(context, provider, ble),

            const SizedBox(height: 14),

            // Plate Weight Setup Section
            _buildPlateSetupSection(context, provider, ble),

            const SizedBox(height: 14),

            // Viewfinder Camera Simulation & Dish Tag
            _buildViewfinder(provider, dishName, provider.currentConfidence),

            const SizedBox(height: 12),

            // Meal Photo Capture Action Section
            _buildPhotoActionSection(provider),

            const SizedBox(height: 16),

            // Test profile banner if ESP32 test mode is active
            if (provider.isBleTestProfile) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESP32-C3 Test Device Connected',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live weight values are simulated test data and will not be recorded as genuine food intake.',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontSize: 11,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Weight Display & Input (Contextual based on Mode A or Mode B)
            if (isManual)
              _buildManualWeightCard(provider)
            else
              _buildDeviceWeightCard(provider, currentWeight),

            const SizedBox(height: 20),

            // Start Meal Measurement Session Prominent Action Button
            ElevatedButton.icon(
              onPressed: provider.isLoading ? null : () => _startMealMeasurement(context, provider, ble),
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.secondary,
                foregroundColor: DiniecoColors.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: DiniecoColors.primaryContainer),
                    )
                  : const Icon(Icons.play_circle_outline, size: 22, color: DiniecoColors.primaryContainer),
              label: Text(
                provider.isLoading ? 'Starting Session...' : 'Start Meal Measurement Session',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Finish Meal & Record Waste (Secondary / Manual Flow)
            OutlinedButton.icon(
              onPressed: provider.isLoading ? null : _handleFinishMeal,
              style: OutlinedButton.styleFrom(
                foregroundColor: DiniecoColors.primary,
                side: const BorderSide(color: DiniecoColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text(
                'Finish Meal & Record Waste',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Detected Components Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected Components (${components.length})',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DiniecoColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${provider.totalFoodPortionG.toStringAsFixed(0)}g reconciled food',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // List of Detected Components with Edit Weights
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: components.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return FoodComponentItemWidget(
                  component: components[index],
                  onWeightChanged: (newWeight) {
                    provider.updateComponentWeight(index, newWeight);
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // Real-time Nutrition Summary with Uncertainty
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNutrientCol('Calories', '${provider.totalCalories} kcal'),
                      Container(width: 1, height: 24, color: DiniecoColors.outlineVariant),
                      _buildNutrientCol('Protein', '${provider.totalProtein.toStringAsFixed(1)}g'),
                      Container(width: 1, height: 24, color: DiniecoColors.outlineVariant),
                      _buildNutrientCol('Carbs', '${provider.totalCarbs.toStringAsFixed(1)}g'),
                      Container(width: 1, height: 24, color: DiniecoColors.outlineVariant),
                      _buildNutrientCol('Fat', '${provider.totalFat.toStringAsFixed(1)}g'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nutritional bounds: ±10% culinary variation (ICMR & USDA verified)',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 10,
                      color: DiniecoColors.outline.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!isManual)
              OutlinedButton.icon(
                onPressed: _handleTare,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DiniecoColors.primary,
                  side: const BorderSide(color: DiniecoColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.exposure_zero, size: 18),
                label: const Text(
                  'Zero / Tare Smart Pad',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () {
                  provider.setManualWeight(486.0);
                  _manualWeightController.text = '486';
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: DiniecoColors.primary,
                  side: const BorderSide(color: DiniecoColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Reset Default 486g Portion',
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

  Widget _buildDeviceReadinessCard(BuildContext context, DiniecoProvider provider, BleProvider ble) {
    final btEnabled = ble.status != BleConnectionStatus.bluetoothDisabled;
    final isConnected = ble.status == BleConnectionStatus.connected;
    final hasTelemetry = ble.latestPacket != null && !ble.latestPacket!.isStale;
    final isCalibrated = ble.latestPacket?.isCalibrated ?? true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hardware Readiness Status',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w700, color: DiniecoColors.primary),
              ),
              if (!isConnected)
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/connectivity'),
                  child: const Text('Connect Pad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildReadinessItem(
                label: 'Bluetooth',
                isOk: btEnabled,
                statusText: btEnabled ? 'Enabled' : 'Disabled',
              ),
              const SizedBox(width: 8),
              _buildReadinessItem(
                label: 'Smart Pad',
                isOk: isConnected,
                statusText: isConnected ? (ble.connectedDevice?.name ?? 'Connected') : 'Offline',
              ),
              const SizedBox(width: 8),
              _buildReadinessItem(
                label: 'Telemetry',
                isOk: hasTelemetry,
                statusText: hasTelemetry ? 'Live (<3s)' : 'No Stream',
              ),
              const SizedBox(width: 8),
              _buildReadinessItem(
                label: 'Calibration',
                isOk: isCalibrated,
                statusText: isCalibrated ? 'Calibrated' : 'Required',
              ),
            ],
          ),
          if (ble.latestPacket != null && ble.latestPacket!.isCalibrated == false) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Load-cell calibration required. Measurements may be inaccurate.',
                      style: TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadinessItem({required String label, required bool isOk, required String statusText}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isOk ? const Color(0xFFECF6EC) : DiniecoColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              isOk ? Icons.check_circle : Icons.cancel_outlined,
              size: 14,
              color: isOk ? const Color(0xFF16A34A) : DiniecoColors.outline,
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'Work Sans', fontSize: 10, color: DiniecoColors.onSurfaceVariant)),
            Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isOk ? const Color(0xFF166534) : DiniecoColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlateSetupSection(BuildContext context, DiniecoProvider provider, BleProvider ble) {
    final currentPlate = provider.setupPlateWeightG;
    final plateMode = provider.setupPlateWeightMode;
    final liveSmoothed = provider.smoothedWeightG;
    final isScaleStable = provider.isWeightStable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.dinner_dining, size: 18, color: DiniecoColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Plate Weight Setup (Optional)',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primary,
                    ),
                  ),
                ],
              ),
              if (currentPlate != null)
                TextButton(
                  onPressed: () => provider.clearSetupPlateWeight(),
                  child: const Text('Clear', style: TextStyle(fontSize: 12, color: DiniecoColors.error)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Measure your empty plate first, enter it manually, or skip to track total gross weight.',
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 11,
              color: DiniecoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Current plate status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: currentPlate != null ? const Color(0xFFECF6EC) : DiniecoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  currentPlate != null ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: currentPlate != null ? const Color(0xFF16A34A) : DiniecoColors.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentPlate != null
                        ? 'Plate: ${currentPlate.toStringAsFixed(1)}g (${plateMode == "measured" ? "Scale Measured" : "Manual Input"})'
                        : 'Plate: Not Set (Gross Weight Mode — net reduction still tracked)',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: currentPlate != null ? const Color(0xFF166534) : DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Method A: Scale Capture
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DiniecoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Method A: Measure on Scale',
                      style: TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700, color: DiniecoColors.primary),
                    ),
                    Text(
                      '${liveSmoothed.toStringAsFixed(1)}g (${isScaleStable ? "Stable" : "Settling..."})',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isScaleStable ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Place empty plate on the pad. When reading is stable, tap capture.',
                  style: TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: DiniecoColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (liveSmoothed > 10.0)
                        ? () {
                            provider.autoCapturePlateWeight();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Empty plate captured: ${provider.setupPlateWeightG?.toStringAsFixed(1)}g'),
                                backgroundColor: DiniecoColors.primary,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.scale, size: 16),
                    label: Text(
                      liveSmoothed > 10.0
                          ? 'Capture Empty Plate (${liveSmoothed.toStringAsFixed(1)}g)'
                          : 'Place Plate on Scale (>10g)',
                      style: const TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DiniecoColors.secondary,
                      foregroundColor: DiniecoColors.primaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Method B: Manual Numeric Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DiniecoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Method B: Enter Known Plate Weight',
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w700, color: DiniecoColors.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _plateWeightInputController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. 350',
                            suffixText: 'g',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(_plateWeightInputController.text);
                        if (val != null && val >= 10.0 && val <= 1500.0) {
                          provider.setSetupPlateWeight(val, 'manual');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Manual plate set: ${val.toStringAsFixed(1)}g'),
                              backgroundColor: DiniecoColors.primary,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DiniecoColors.primaryContainer,
                        foregroundColor: DiniecoColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text('Set Plate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Method C: Skip Plate Setup
          OutlinedButton(
            onPressed: () {
              provider.clearSetupPlateWeight();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Plate setup skipped. Gross weight tracking enabled.'),
                  backgroundColor: DiniecoColors.primary,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: DiniecoColors.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: const Center(
              child: Text(
                'Skip Plate Setup (Gross Weight Mode)',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w600, color: DiniecoColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String mainValue, String subValue, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            mainValue,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          Text(
            subValue,
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 10,
              color: DiniecoColors.outline.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMealMeasurement(BuildContext context, DiniecoProvider provider, BleProvider ble) async {
    // Check calibration warning
    if (ble.latestPacket != null && ble.latestPacket!.isCalibrated == false) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Load-Cell Calibration Warning'),
          content: const Text(
            'The connected Smart Dining Pad reports that load-cell calibration is required. Measurements may be inaccurate.\n\nDo you want to proceed anyway or calibrate first?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                Navigator.of(context).pushNamed('/diagnostics');
              },
              child: const Text('Calibrate First'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final dish = provider.currentDishName.isNotEmpty ? provider.currentDishName : 'Meal Session';
    final photo = provider.selectedMealPhoto;

    await provider.startMealMeasurementSession(
      mealName: dish,
      startPhoto: photo,
      imageSource: 'app_camera',
      deviceId: ble.connectedDevice?.id ?? provider.padStatus.deviceId,
      isCalibrated: ble.latestPacket?.isCalibrated ?? true,
    );

    _startTimerIfNeeded();
  }

  void _showEndMealDialog(BuildContext context, DiniecoProvider provider, BleProvider ble) {
    XFile? dialogEndPhoto;
    Uint8List? dialogEndPhotoBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DiniecoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final session = provider.activeSession;
            if (session == null) return const SizedBox.shrink();

            final liveGross = provider.smoothedWeightG;
            final startGross = session.startGrossWeightG ?? liveGross;
            final isIncrease = liveGross > startGross + 1.0;
            final weightReduction = provider.currentWeightReductionG ?? 0.0;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: DiniecoColors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'End Meal & Record Final Weight',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: DiniecoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ensure plate is still on the Smart Dining Pad to capture final stable weight and take an after-meal photo.',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 12,
                          color: DiniecoColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Final scale weight preview
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: DiniecoColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'FINAL WEIGHT ON SCALE',
                                  style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 10, fontWeight: FontWeight.w600, color: DiniecoColors.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${liveGross.toStringAsFixed(1)}g',
                                  style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 24, fontWeight: FontWeight.w800, color: DiniecoColors.primary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: provider.isWeightStable ? const Color(0xFFECF6EC) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                provider.isWeightStable ? 'Scale Stable' : 'Scale Settling...',
                                style: TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: provider.isWeightStable ? const Color(0xFF166534) : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Unexpected Increase Flag Warning
                      if (isIncrease)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Notice: Final weight (+${(liveGross - startGross).toStringAsFixed(1)}g) is higher than start weight. Extra food added or plate changed. Food weight reduction will be recorded as 0.0g.',
                                  style: const TextStyle(
                                    fontFamily: 'Work Sans',
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECF6EC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Calculated Weight Reduction / Food Removed: ${weightReduction.toStringAsFixed(1)}g',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // End Meal Photo Section
                      const Text(
                        'After-Meal Photo (Optional)',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DiniecoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (dialogEndPhotoBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                dialogEndPhotoBytes!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                  onPressed: () {
                                    setModalState(() {
                                      dialogEndPhoto = null;
                                      dialogEndPhotoBytes = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1080);
                                  if (photo != null) {
                                    final bytes = await photo.readAsBytes();
                                    setModalState(() {
                                      dialogEndPhoto = photo;
                                      dialogEndPhotoBytes = bytes;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Camera'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080);
                                  if (photo != null) {
                                    final bytes = await photo.readAsBytes();
                                    setModalState(() {
                                      dialogEndPhoto = photo;
                                      dialogEndPhotoBytes = bytes;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Gallery'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),

                      // Confirm & Finalize Button
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final meal = await provider.finalizeMealMeasurementSession(
                            endPhoto: dialogEndPhoto,
                            imageSource: 'app_camera',
                          );
                          if (meal != null && mounted) {
                            widget.onFinishMeal();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DiniecoColors.secondary,
                          foregroundColor: DiniecoColors.primaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Confirm & Save Meal Session',
                          style: TextStyle(fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDiscardSession(BuildContext context, DiniecoProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Meal Session?'),
        content: const Text('Are you sure you want to discard this live meal session? Any recorded weight data for this session will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Session'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: DiniecoColors.error),
            child: const Text('Discard Session'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.cancelActiveMealSession();
      if (mounted) {
        widget.onCancel();
      }
    }
  }

  Widget _buildModeSelector(DiniecoProvider provider) {
    final isDevice = provider.weightSource == 'device';

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => provider.setWeightSource('device'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDevice ? DiniecoColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isDevice
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth_connected,
                      size: 16,
                      color: isDevice ? DiniecoColors.primary : DiniecoColors.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mode A: Smart Pad BLE',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: isDevice ? FontWeight.w700 : FontWeight.w500,
                        color: isDevice ? DiniecoColors.primary : DiniecoColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => provider.setWeightSource('manual'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isDevice ? DiniecoColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !isDevice
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note,
                      size: 16,
                      color: !isDevice ? DiniecoColors.primary : DiniecoColors.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mode B: Manual Weight',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: !isDevice ? FontWeight.w700 : FontWeight.w500,
                        color: !isDevice ? DiniecoColors.primary : DiniecoColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualWeightCard(DiniecoProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.secondaryFixed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_document, size: 18, color: DiniecoColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Manual Net Food Weight',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DiniecoColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'No Tare Deducted',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: DiniecoColors.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter the net weight of edible food on your plate in grams (10g – 2500g):',
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 12,
              color: DiniecoColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                  decoration: InputDecoration(
                    suffixText: 'grams (g)',
                    suffixStyle: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 14,
                      color: DiniecoColors.outline,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: DiniecoColors.outlineVariant),
                    ),
                  ),
                  onSubmitted: (val) {
                    final d = double.tryParse(val);
                    if (d != null && d >= 10.0 && d <= 2500.0) {
                      provider.setManualWeight(d);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final d = double.tryParse(_manualWeightController.text);
                  if (d != null && d >= 10.0 && d <= 2500.0) {
                    provider.setManualWeight(d);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Portions reconciled for ${d.toStringAsFixed(0)}g net food'),
                        backgroundColor: DiniecoColors.primary,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DiniecoColors.secondary,
                  foregroundColor: DiniecoColors.primaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick increment chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildWeightChip(provider, -50),
              _buildWeightChip(provider, -20),
              _buildWeightChip(provider, 20),
              _buildWeightChip(provider, 50),
              _buildWeightChip(provider, 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChip(DiniecoProvider provider, double deltaG) {
    return ActionChip(
      label: Text(
        deltaG > 0 ? '+${deltaG.toInt()}g' : '${deltaG.toInt()}g',
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: DiniecoColors.surfaceContainerLow,
      side: const BorderSide(color: DiniecoColors.outlineVariant),
      onPressed: () {
        final current = double.tryParse(_manualWeightController.text) ?? provider.currentWeightG;
        final next = (current + deltaG).clamp(10.0, 2500.0);
        _manualWeightController.text = next.toStringAsFixed(0);
        provider.setManualWeight(next);
      },
    );
  }

  Widget _buildDeviceWeightCard(DiniecoProvider provider, double currentWeight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          CircularWeightGauge(
            weightGrams: currentWeight,
            maxWeightGrams: 1200,
            isStabilized: provider.isStabilized,
            netFoodWeightGrams: provider.totalFoodPortionG,
          ),
          const SizedBox(height: 16),
          // Demo Weight Slider to simulate eating and waste reduction
          Row(
            children: [
              const Text(
                'Simulate Eat:',
                style: TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 12,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Slider(
                  value: currentWeight.clamp(0.0, 1000.0),
                  min: 0.0,
                  max: 1000.0,
                  activeColor: DiniecoColors.secondary,
                  inactiveColor: DiniecoColors.surfaceVariant,
                  onChanged: (val) {
                    provider.setSimulatedWeight(val);
                  },
                ),
              ),
              Text(
                '${currentWeight.toStringAsFixed(0)}g',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DiniecoColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoActionSection(DiniecoProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(
                  provider.selectedMealPhoto != null ? 'Retake Photo' : 'Take Meal Photo',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DiniecoColors.primaryContainer,
                  foregroundColor: DiniecoColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text(
                  'From Gallery',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DiniecoColors.primary,
                  side: const BorderSide(color: DiniecoColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        if (provider.photoError != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.photoError!,
                    style: TextStyle(fontFamily: 'Work Sans', fontSize: 12, color: Colors.red.shade800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => provider.clearMealPhoto(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildViewfinder(DiniecoProvider provider, String dishName, double confidence) {
    final hasPhoto = provider.selectedMealPhoto != null;
    final isBusy = provider.isPhotoUploading || provider.isVisionAnalyzing;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.outlineVariant),
      ),
      child: Stack(
        children: [
          // Background: Real Photo or Simulated Overhead View
          if (hasPhoto && provider.selectedMealPhotoBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                provider.selectedMealPhotoBytes!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: DiniecoColors.surfaceVariant,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_outlined,
                            size: 40,
                            color: DiniecoColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Meal Photo Selected',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: DiniecoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            InkWell(
              onTap: () => _showImageSourcePicker(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      DiniecoColors.primaryContainer.withValues(alpha: 0.15),
                      DiniecoColors.surfaceContainerHigh,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 48,
                        color: DiniecoColors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to Capture or Upload Meal Photo',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports Camera & Gallery for AI Vision Analysis',
                        style: TextStyle(
                          fontFamily: 'Work Sans',
                          fontSize: 11,
                          color: DiniecoColors.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Analysis Loading Overlay
          if (isBusy)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: DiniecoColors.secondary),
                    const SizedBox(height: 12),
                    Text(
                      provider.isPhotoUploading
                          ? 'Uploading Meal Photo...'
                          : 'AI Analyzing Dish & Components...',
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reconciling with ${provider.currentWeightG > 0 ? provider.currentWeightG.toStringAsFixed(0) : "486"}g portion',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Viewfinder corner brackets
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                  left: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                  right: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                  left: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                  right: BorderSide(color: DiniecoColors.secondaryFixed, width: 3),
                ),
              ),
            ),
          ),

          // Retake & Remove pills when photo is present (top left inside brackets)
          if (hasPhoto && !isBusy)
            Positioned(
              top: 12,
              left: 40,
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _showImageSourcePicker(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DiniecoColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 14, color: DiniecoColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Retake',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: DiniecoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => provider.clearMealPhoto(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DiniecoColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Remove',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Center reticle (only when no photo)
          if (!hasPhoto && !isBusy)
            Center(
              child: Icon(
                Icons.filter_center_focus,
                size: 40,
                color: DiniecoColors.secondaryFixed.withValues(alpha: 0.6),
              ),
            ),

          // AI Recognition Badge Pill
          Positioned(
            bottom: 12,
            left: 12,
            child: InkWell(
              onTap: () => _showDishPickerModal(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: DiniecoColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 16, color: DiniecoColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      dishName.isNotEmpty ? dishName : 'Awaiting Meal Photo',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DiniecoColors.primary,
                      ),
                    ),
                    if (confidence > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DiniecoColors.secondaryFixed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(confidence * 100).toStringAsFixed(0)}% Confidence',
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: DiniecoColors.onSecondaryFixed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Engine tag top right
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DiniecoColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.aiVerified ? Icons.bolt : Icons.auto_awesome,
                    size: 12,
                    color: provider.aiVerified ? DiniecoColors.secondary : DiniecoColors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    provider.detectedComponents.isEmpty
                        ? 'Awaiting Analysis'
                        : (provider.aiVerified ? 'Live Gemini 2.5' : 'Catalog Estimate'),
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientCol(String label, String value) {
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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.onSurface,
          ),
        ),
      ],
    );
  }
}
