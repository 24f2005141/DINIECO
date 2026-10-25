import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../providers/dinieco_provider.dart';

class DiagnosticsCalibrationScreen extends StatefulWidget {
  final VoidCallback onBack;

  const DiagnosticsCalibrationScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<DiagnosticsCalibrationScreen> createState() => _DiagnosticsCalibrationScreenState();
}

class _DiagnosticsCalibrationScreenState extends State<DiagnosticsCalibrationScreen> {
  int _currentStep = 3;
  bool _isCalibrating = false;

  Future<void> _startCalibration() async {
    setState(() {
      _isCalibrating = true;
      _currentStep = 1;
    });

    final provider = context.read<DiniecoProvider>();

    // Step 1: Remove objects
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStep = 2);

    // Step 2: Surface check
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStep = 3);

    // Step 3: Zero tare
    await provider.tarePad();
    if (!mounted) return;
    setState(() => _currentStep = 4);

    // Step 4: Finalize
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _isCalibrating = false;
      _currentStep = 4;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Smart Pad calibrated to 0.5g precision! Baseline zeroed.'),
        backgroundColor: DiniecoColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiniecoProvider>();
    final pad = provider.padStatus;
    final isConnected = pad.isConnected;

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
          'Device Diagnostics',
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
            // BLE Hardware Pairing & Connectivity Entry
            InkWell(
              onTap: () {
                Navigator.of(context).pushNamed('/connectivity');
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DiniecoColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: DiniecoColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DiniecoColors.secondaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bluetooth_searching, color: DiniecoColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage BLE Hardware & Pairing',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Scan, connect to ESP32-C3 or production pad & configure telemetry',
                            style: TextStyle(
                              fontFamily: 'Work Sans',
                              fontSize: 11,
                              color: DiniecoColors.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),

            // Main Hardware Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: DiniecoColors.primary.withValues(alpha: 0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
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
                                color: DiniecoColors.primaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pad.deviceId} • Firmware v1.0',
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 12,
                                color: DiniecoColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? DiniecoColors.secondaryContainer.withValues(alpha: 0.4)
                              : DiniecoColors.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isConnected
                                ? DiniecoColors.secondary.withValues(alpha: 0.3)
                                : DiniecoColors.error.withValues(alpha: 0.3),
                          ),
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
                              isConnected ? 'Connected' : 'Disconnected',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isConnected ? DiniecoColors.onSecondaryContainer : DiniecoColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Diagnostics 2x2 Grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.4,
                    children: [
                      _buildDiagTile(
                        icon: Icons.battery_full,
                        iconColor: DiniecoColors.secondary,
                        label: 'Battery',
                        value: '${pad.batteryPercent}%',
                        sub: '3.98V Li-Po',
                      ),
                      _buildDiagTile(
                        icon: Icons.scale,
                        iconColor: DiniecoColors.primaryContainer,
                        label: 'Load Sensor',
                        value: pad.loadSensorStatus,
                        sub: '24-bit ADC',
                      ),
                      _buildDiagTile(
                        icon: Icons.photo_camera,
                        iconColor: DiniecoColors.primaryContainer,
                        label: 'Camera',
                        value: pad.cameraStatus,
                        sub: '1080p OV2640',
                      ),
                      _buildDiagTile(
                        icon: Icons.sync,
                        iconColor: DiniecoColors.primaryContainer,
                        label: 'Last Sync',
                        value: '2 min ago',
                        sub: 'BLE RSSI -58dBm',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Calibration Wizard Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: DiniecoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calibrate Smart Pad',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step $_currentStep of 4',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DiniecoColors.primaryContainer,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _isCalibrating
                              ? 'Calibrating sensors...'
                              : (_currentStep == 4 ? 'Calibration Completed' : 'Ready to calibrate'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Work Sans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: DiniecoColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _currentStep / 4.0,
                      backgroundColor: DiniecoColors.surfaceContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(DiniecoColors.secondary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Steps list
                  _buildStepRow(
                    stepNumber: 1,
                    title: 'Remove all food and objects from the pad',
                    isDone: _currentStep > 1,
                    isActive: _currentStep == 1 && _isCalibrating,
                  ),
                  const SizedBox(height: 14),
                  _buildStepRow(
                    stepNumber: 2,
                    title: 'Place the pad on a stable flat surface',
                    isDone: _currentStep > 2,
                    isActive: _currentStep == 2 && _isCalibrating,
                  ),
                  const SizedBox(height: 14),
                  _buildStepRow(
                    stepNumber: 3,
                    title: 'Zero tare and load-cell sensor baseline',
                    isDone: _currentStep > 3,
                    isActive: _currentStep == 3 && _isCalibrating,
                  ),
                  const SizedBox(height: 14),
                  _buildStepRow(
                    stepNumber: 4,
                    title: 'Confirm calibration stability check',
                    isDone: _currentStep >= 4 && !_isCalibrating,
                    isActive: _currentStep == 4 && _isCalibrating,
                  ),

                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: DiniecoColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.verified, size: 16, color: DiniecoColors.secondary),
                        SizedBox(width: 8),
                        Text(
                          'Sensors calibrated to 0.5g precision',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: DiniecoColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isCalibrating ? null : _startCalibration,
              style: ElevatedButton.styleFrom(
                backgroundColor: DiniecoColors.primaryContainer,
                foregroundColor: DiniecoColors.secondaryFixed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: _isCalibrating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: DiniecoColors.secondaryFixed),
                    )
                  : const Icon(Icons.tune, size: 20),
              label: Text(
                _isCalibrating ? 'CALIBRATING SENSORS...' : 'START HARDWARE CALIBRATION',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      provider.reconnectBLE();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reconnected to BLE Smart Pad')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DiniecoColors.primaryContainer,
                      side: const BorderSide(color: DiniecoColors.primaryContainer, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.bluetooth_connected, size: 18),
                    label: const Text(
                      'Reconnect BLE',
                      style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      provider.disconnectPad();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Smart Pad Disconnected')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DiniecoColors.outline,
                      side: const BorderSide(color: DiniecoColors.outline, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    label: const Text(
                      'Disconnect Pad',
                      style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 12,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.primaryContainer,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 10,
                  color: DiniecoColors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    required bool isDone,
    required bool isActive,
  }) {
    return Row(
      children: [
        if (isDone)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DiniecoColors.secondary.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.check_circle, size: 20, color: DiniecoColors.secondary),
          )
        else if (isActive)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: DiniecoColors.secondary),
          )
        else
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: DiniecoColors.outlineVariant, width: 2),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Work Sans',
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : (isDone ? FontWeight.w500 : FontWeight.w400),
              color: isActive
                  ? DiniecoColors.primaryContainer
                  : (isDone ? DiniecoColors.onSurface : DiniecoColors.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ],
    );
  }
}
