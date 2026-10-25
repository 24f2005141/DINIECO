import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/dinieco_colors.dart';
import '../models/ble_models.dart';
import '../providers/ble_provider.dart';
import '../providers/dinieco_provider.dart';

class HardwareConnectivityScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const HardwareConnectivityScreen({super.key, this.onBack});

  @override
  State<HardwareConnectivityScreen> createState() => _HardwareConnectivityScreenState();
}

class _HardwareConnectivityScreenState extends State<HardwareConnectivityScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameFilterController;
  late TextEditingController _serviceUuidController;
  late TextEditingController _charUuidController;

  String _selectedPreset = 'esp32_test';
  bool _isAdvancedExpanded = false;
  String _selectedDataFormat = 'json';
  String _selectedWeightUnit = 'g';
  bool _isNotificationMode = true;
  bool _autoReconnect = true;
  int _timeoutSeconds = 10;

  @override
  void initState() {
    super.initState();
    final bleProvider = context.read<BleProvider>();
    final profile = bleProvider.currentProfile;

    _selectedPreset = profile.profileId;
    _nameFilterController = TextEditingController(text: profile.deviceNameFilter);
    _serviceUuidController = TextEditingController(text: profile.serviceUuid);
    _charUuidController = TextEditingController(text: profile.characteristicUuid);
    _selectedDataFormat = profile.dataFormat;
    _selectedWeightUnit = profile.weightUnit;
    _isNotificationMode = profile.isNotification;
    _autoReconnect = profile.autoReconnect;
    _timeoutSeconds = profile.timeoutSeconds;
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    _serviceUuidController.dispose();
    _charUuidController.dispose();
    super.dispose();
  }

  void _syncControllersFromProfile(BleConfigProfile profile) {
    setState(() {
      _selectedPreset = profile.profileId;
      _nameFilterController.text = profile.deviceNameFilter;
      _serviceUuidController.text = profile.serviceUuid;
      _charUuidController.text = profile.characteristicUuid;
      _selectedDataFormat = profile.dataFormat;
      _selectedWeightUnit = profile.weightUnit;
      _isNotificationMode = profile.isNotification;
      _autoReconnect = profile.autoReconnect;
      _timeoutSeconds = profile.timeoutSeconds;
    });
  }

  void _saveCustomConfiguration(BleProvider bleProvider) {
    if (_formKey.currentState?.validate() ?? false) {
      final customProfile = BleConfigProfile.custom(
        name: 'Custom Hardware Profile',
        deviceNameFilter: _nameFilterController.text.trim(),
        serviceUuid: _serviceUuidController.text.trim(),
        characteristicUuid: _charUuidController.text.trim(),
        dataFormat: _selectedDataFormat,
        isNotification: _isNotificationMode,
        weightUnit: _selectedWeightUnit,
        timeoutSeconds: _timeoutSeconds,
        autoReconnect: _autoReconnect,
      );

      bleProvider.updateCustomProfile(customProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom configuration saved. Disconnect & reconnect to apply.'),
          backgroundColor: DiniecoColors.primaryContainer,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bleProvider = context.watch<BleProvider>();
    final diniecoProvider = context.watch<DiniecoProvider>();

    // Forward telemetry into DiniecoProvider when new packets arrive
    if (bleProvider.status == BleConnectionStatus.connected && bleProvider.latestPacket != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        diniecoProvider.updateFromBleTelemetry(
          bleProvider.latestPacket!,
          isTestProfile: bleProvider.currentProfile.profileId == 'esp32_test' ||
              bleProvider.latestPacket!.isTestSource,
        );
      });
    } else if (bleProvider.status == BleConnectionStatus.disconnected &&
        diniecoProvider.padStatus.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        diniecoProvider.onBleDisconnected();
      });
    }

    return Scaffold(
      backgroundColor: DiniecoColors.background,
      appBar: AppBar(
        backgroundColor: DiniecoColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DiniecoColors.primary),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Hardware & Connectivity',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DiniecoColors.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh / Stop Scan',
            icon: Icon(
              bleProvider.status == BleConnectionStatus.scanning ? Icons.stop : Icons.refresh,
              color: DiniecoColors.primary,
            ),
            onPressed: () {
              if (bleProvider.status == BleConnectionStatus.scanning) {
                bleProvider.stopScan();
              } else {
                bleProvider.startScan();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section A: Connection Status
            _buildConnectionStatusCard(bleProvider),

            const SizedBox(height: 16),

            // Section B: Nearby Devices List
            _buildNearbyDevicesSection(bleProvider),

            const SizedBox(height: 16),

            // Section C: Device Controls
            _buildDeviceControlsSection(bleProvider),

            const SizedBox(height: 16),

            // Section D: Hardware Configuration Presets
            _buildConfigurationSection(bleProvider),

            const SizedBox(height: 16),

            // Section E: Live Telemetry Dashboard & Telemetry Log
            _buildTelemetryDashboard(bleProvider),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Section A: Connection Status Card
  // -------------------------------------------------------------
  Widget _buildConnectionStatusCard(BleProvider ble) {
    Color statusColor;
    switch (ble.status) {
      case BleConnectionStatus.connected:
        statusColor = DiniecoColors.success;
        break;
      case BleConnectionStatus.connectedNoData:
        statusColor = DiniecoColors.warning;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.discoveringServices:
      case BleConnectionStatus.reconnecting:
        statusColor = Colors.blue;
        break;
      case BleConnectionStatus.scanning:
        statusColor = Colors.purple;
        break;
      case BleConnectionStatus.bluetoothDisabled:
      case BleConnectionStatus.permissionRequired:
      case BleConnectionStatus.connectionFailed:
        statusColor = DiniecoColors.error;
        break;
      case BleConnectionStatus.readyToScan:
      case BleConnectionStatus.devicesFound:
      case BleConnectionStatus.noDevicesFound:
      case BleConnectionStatus.disconnected:
        statusColor = DiniecoColors.outline;
        break;
    }

    final hasData = ble.latestPacket != null && !ble.latestPacket!.isStale;

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
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ble.status.displayName,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasData ? DiniecoColors.secondaryContainer.withValues(alpha: 0.5) : DiniecoColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasData ? Icons.sensors : Icons.sensors_off,
                      size: 13,
                      color: hasData ? DiniecoColors.onSecondaryContainer : DiniecoColors.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasData ? 'Live Data Stream' : 'No Data Arriving',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasData ? DiniecoColors.onSecondaryContainer : DiniecoColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Device',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 11,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ble.connectedDevice?.displayName ?? ble.savedDeviceName ?? 'None Selected',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Last Connected',
                    style: TextStyle(
                      fontFamily: 'Work Sans',
                      fontSize: 11,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ble.lastConnectedTime != null
                        ? '${ble.lastConnectedTime!.hour.toString().padLeft(2, '0')}:${ble.lastConnectedTime!.minute.toString().padLeft(2, '0')}:${ble.lastConnectedTime!.second.toString().padLeft(2, '0')}'
                        : 'Never',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ble.lastError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DiniecoColors.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: DiniecoColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ble.lastError!,
                      style: const TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 11,
                        color: DiniecoColors.error,
                      ),
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

  // -------------------------------------------------------------
  // Section B: Nearby Devices Section
  // -------------------------------------------------------------
  Widget _buildNearbyDevicesSection(BleProvider ble) {
    final isScanning = ble.status == BleConnectionStatus.scanning;

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
              const Text(
                'Nearby BLE Devices',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.primary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (isScanning) {
                    ble.stopScan();
                  } else {
                    ble.startScan();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning ? DiniecoColors.error : DiniecoColors.primaryContainer,
                  foregroundColor: DiniecoColors.secondaryFixed,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                icon: isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search, size: 16),
                label: Text(
                  isScanning ? 'STOP SCAN' : 'SCAN FOR DEVICES',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Filter: "${ble.currentProfile.deviceNameFilter}"',
                style: const TextStyle(
                  fontFamily: 'Work Sans',
                  fontSize: 12,
                  color: DiniecoColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => ble.toggleShowAllDevices(),
                child: Row(
                  children: [
                    Icon(
                      ble.showAllDevices ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: DiniecoColors.primary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Show All Devices (Diag)',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        color: DiniecoColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Devices List
          if (ble.discoveredDevices.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                      size: 40,
                      color: DiniecoColors.outlineVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isScanning
                          ? 'Searching for nearby DINIECO smart pads...'
                          : 'No devices found in range. Ensure your ESP32-C3 is advertising.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 12,
                        color: DiniecoColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ble.discoveredDevices.length,
              separatorBuilder: (context, index) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final device = ble.discoveredDevices[index];
                final isConnected = ble.connectedDevice?.id == device.id &&
                    ble.status == BleConnectionStatus.connected;
                final isConnecting = ble.connectedDevice?.id == device.id &&
                    (ble.status == BleConnectionStatus.connecting ||
                        ble.status == BleConnectionStatus.discoveringServices);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? DiniecoColors.secondaryContainer.withValues(alpha: 0.5)
                          : DiniecoColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      color: isConnected ? DiniecoColors.secondary : DiniecoColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    device.displayName,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DiniecoColors.primary,
                    ),
                  ),
                  subtitle: Text(
                    'MAC: ${device.id} • Signal: ${device.rssi} dBm',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 11,
                      color: DiniecoColors.onSurfaceVariant,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: isConnecting
                        ? null
                        : () {
                            if (isConnected) {
                              ble.disconnectDevice();
                            } else {
                              ble.connectDevice(device);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? DiniecoColors.surfaceVariant : DiniecoColors.primaryContainer,
                      foregroundColor: isConnected ? DiniecoColors.primary : DiniecoColors.secondaryFixed,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: isConnecting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: DiniecoColors.secondaryFixed),
                          )
                        : Text(
                            isConnected ? 'DISCONNECT' : 'CONNECT',
                            style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Section C: Device Connection Controls
  // -------------------------------------------------------------
  Widget _buildDeviceControlsSection(BleProvider ble) {
    final isConnected = ble.connectedDevice != null;

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
          const Text(
            'Device Connection Controls',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DiniecoColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isConnected
                      ? () => ble.disconnectDevice()
                      : (ble.savedDeviceId != null
                          ? () => ble.connectDevice(BleDeviceItem(id: ble.savedDeviceId!, name: ble.savedDeviceName ?? 'Pad', rssi: -60))
                          : null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DiniecoColors.primary,
                    side: const BorderSide(color: DiniecoColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(isConnected ? Icons.link_off : Icons.link, size: 18),
                  label: Text(
                    isConnected ? 'Disconnect' : 'Reconnect',
                    style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ble.savedDeviceId != null ? () => ble.forgetDevice() : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DiniecoColors.error,
                    side: const BorderSide(color: DiniecoColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Forget Device',
                    style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Section D: Hardware Configuration Presets
  // -------------------------------------------------------------
  Widget _buildConfigurationSection(BleProvider ble) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DiniecoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hardware Configuration',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: DiniecoColors.primary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAdvancedExpanded = !_isAdvancedExpanded;
                    });
                  },
                  child: Text(
                    _isAdvancedExpanded ? 'Hide Advanced' : 'Show Advanced',
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DiniecoColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Preset Dropdown
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedPreset),
              initialValue: _selectedPreset,
              decoration: InputDecoration(
                labelText: 'Hardware Profile Preset',
                labelStyle: const TextStyle(fontFamily: 'Work Sans', fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'esp32_test',
                  child: Text('ESP32-C3 — BLE Test (JSON Stream)'),
                ),
                DropdownMenuItem(
                  value: 'dinieco_prod',
                  child: Text('DINIECO Pad — Production (GATT Stream)'),
                ),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('Custom Configuration'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPreset = val;
                  });
                  if (val == 'esp32_test') {
                    final p = BleConfigProfile.esp32Test();
                    ble.selectPreset('esp32_test');
                    _syncControllersFromProfile(p);
                  } else if (val == 'dinieco_prod') {
                    final p = BleConfigProfile.diniecoProduction();
                    ble.selectPreset('dinieco_prod');
                    _syncControllersFromProfile(p);
                  }
                }
              },
            ),

            if (_isAdvancedExpanded || _selectedPreset == 'custom') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameFilterController,
                decoration: InputDecoration(
                  labelText: 'Device Name Filter',
                  hintText: 'e.g. DINIECO_PAD_TEST',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Filter cannot be empty' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceUuidController,
                decoration: InputDecoration(
                  labelText: 'Service UUID (128-bit)',
                  hintText: 'e.g. 7b8a0001-4d2f-4a6b-9c1e-123456789001',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Service UUID required';
                  if (!BleConfigProfile.isValidUuid(val)) return 'Invalid UUID format';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _charUuidController,
                decoration: InputDecoration(
                  labelText: 'Data Characteristic UUID (128-bit)',
                  hintText: 'e.g. 7b8a0002-4d2f-4a6b-9c1e-123456789001',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Characteristic UUID required';
                  if (!BleConfigProfile.isValidUuid(val)) return 'Invalid UUID format';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_selectedDataFormat),
                      initialValue: _selectedDataFormat,
                      decoration: InputDecoration(
                        labelText: 'Data Format',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'json', child: Text('JSON Payload')),
                        DropdownMenuItem(value: 'binary_stream', child: Text('Binary Stream')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDataFormat = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_selectedWeightUnit),
                      initialValue: _selectedWeightUnit,
                      decoration: InputDecoration(
                        labelText: 'Weight Unit',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('Grams (g)')),
                        DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                        DropdownMenuItem(value: 'oz', child: Text('Ounces (oz)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWeightUnit = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-reconnect on startup', style: TextStyle(fontFamily: 'Work Sans', fontSize: 13)),
                value: _autoReconnect,
                onChanged: (val) => setState(() => _autoReconnect = val),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _saveCustomConfiguration(ble),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DiniecoColors.primaryContainer,
                  foregroundColor: DiniecoColors.secondaryFixed,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('SAVE & APPLY CONFIGURATION', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Section E: Live Telemetry Dashboard & Telemetry Log
  // -------------------------------------------------------------
  Widget _buildTelemetryDashboard(BleProvider ble) {
    final packet = ble.latestPacket;

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
              const Text(
                'Live Telemetry Dashboard',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DiniecoColors.primary,
                ),
              ),
              if (packet != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: packet.isTestSource
                        ? Colors.amber.shade100
                        : DiniecoColors.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    packet.isTestSource ? 'TEST PROFILE — SIMULATED' : 'PRODUCTION SENSOR',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: packet.isTestSource ? Colors.amber.shade900 : DiniecoColors.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Readout Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: DiniecoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Measured Weight',
                      style: TextStyle(fontFamily: 'Work Sans', fontSize: 12, color: DiniecoColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packet != null ? '${packet.weightG.toStringAsFixed(1)} ${ble.currentProfile.weightUnit}' : '— ${ble.currentProfile.weightUnit}',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: DiniecoColors.primary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Seq #${packet?.sequence ?? 0}',
                      style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 12, fontWeight: FontWeight.w600, color: DiniecoColors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packet != null && !packet.isStale ? 'Status: ${packet.status}' : 'No Recent Stream',
                      style: TextStyle(
                        fontFamily: 'Work Sans',
                        fontSize: 11,
                        color: packet != null && !packet.isStale ? DiniecoColors.success : DiniecoColors.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Telemetry Log
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Incoming Notification Log (${ble.telemetryLog.length}/30)',
                style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 13, fontWeight: FontWeight.w700, color: DiniecoColors.primary),
              ),
              if (ble.telemetryLog.isNotEmpty)
                TextButton(
                  onPressed: () => ble.clearLog(),
                  child: const Text('Clear Log', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 11, color: DiniecoColors.error)),
                ),
            ],
          ),
          const SizedBox(height: 6),

          Container(
            height: 160,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DiniecoColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: ble.telemetryLog.isEmpty
                ? const Center(
                    child: Text(
                      'No BLE notifications captured yet.\nConnect to ESP32-C3 to observe live JSON stream.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Work Sans', fontSize: 11, color: DiniecoColors.onSurfaceMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: ble.telemetryLog.length,
                    itemBuilder: (context, idx) {
                      final item = ble.telemetryLog[idx];
                      final timeStr = '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}.${item.timestamp.millisecond.toString().padLeft(3, '0')}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '[$timeStr] Seq:${item.sequence} | ${item.weightG}g | ${item.rawPayload}',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 10,
                            color: item.hasMissedSequence ? Colors.red.shade700 : (item.isDuplicate ? Colors.orange.shade700 : Colors.black87),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
