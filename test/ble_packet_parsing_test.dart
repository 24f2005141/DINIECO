import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/models/ble_models.dart';

void main() {
  group('BLE Telemetry Packet Parsing & Validation Tests', () {
    test('Parses valid ESP32-C3 test JSON packet with exact specifications', () {
      const raw = '{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 1}';
      final packet = BleTelemetryPacket.parseJson(raw);

      expect(packet, isNotNull);
      expect(packet!.status, 'ok');
      expect(packet.source, 'test');
      expect(packet.weightG, 102.5);
      expect(packet.sequence, 1);
      expect(packet.isTestSource, isTrue);
      expect(packet.hasMissedSequence, isFalse);
      expect(packet.isDuplicate, isFalse);
      expect(packet.isStale, isFalse);
    });

    test('Parses integer weight values correctly as double', () {
      const raw = '{"status": "ok", "source": "test", "weight_g": 250, "sequence": 2}';
      final packet = BleTelemetryPacket.parseJson(raw);

      expect(packet, isNotNull);
      expect(packet!.weightG, 250.0);
      expect(packet.sequence, 2);
    });

    test('Parses zero and decimal weights accurately', () {
      const raw1 = '{"status": "ok", "source": "test", "weight_g": 0.0, "sequence": 3}';
      final p1 = BleTelemetryPacket.parseJson(raw1);
      expect(p1!.weightG, 0.0);

      const raw2 = '{"status": "ok", "source": "test", "weight_g": 486.234, "sequence": 4}';
      final p2 = BleTelemetryPacket.parseJson(raw2);
      expect(p2!.weightG, 486.234);
    });

    test('Detects sequence gap when sequence number jumps', () {
      const rawPrev = '{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 1}';
      final prev = BleTelemetryPacket.parseJson(rawPrev)!;

      const rawNext = '{"status": "ok", "source": "test", "weight_g": 103.0, "sequence": 4}';
      final next = BleTelemetryPacket.parseJson(rawNext, previousSequence: prev.sequence)!;

      expect(next.sequence, 4);
      expect(next.hasMissedSequence, isTrue);
      expect(next.isDuplicate, isFalse);
    });

    test('Detects duplicate packet when sequence does not increment', () {
      const raw1 = '{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 5}';
      final p1 = BleTelemetryPacket.parseJson(raw1)!;

      const raw2 = '{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 5}';
      final p2 = BleTelemetryPacket.parseJson(raw2, previousSequence: p1.sequence)!;

      expect(p2.sequence, 5);
      expect(p2.isDuplicate, isTrue);
      expect(p2.hasMissedSequence, isFalse);
    });

    test('Rejects missing weight_g or sequence fields safely without throwing', () {
      expect(BleTelemetryPacket.parseJson('{"weight_g": 88.0}'), isNull);
      expect(BleTelemetryPacket.parseJson('{"sequence": 1}'), isNull);
    });

    test('Rejects malformed, truncated, or non-JSON payloads gracefully without throwing', () {
      expect(BleTelemetryPacket.parseJson(''), isNull);
      expect(BleTelemetryPacket.parseJson('not a json string'), isNull);
      expect(BleTelemetryPacket.parseJson('{"status": "ok", weight_g}'), isNull);
      expect(BleTelemetryPacket.parseJson('{"weight_g": "not_a_number", "sequence": 1}'), isNull);
    });

    test('markStale marks telemetry packet as stale while preserving data', () {
      const raw = '{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 1}';
      final packet = BleTelemetryPacket.parseJson(raw)!;
      expect(packet.isStale, isFalse);

      final stalePacket = packet.markStale();
      expect(stalePacket.isStale, isTrue);
      expect(stalePacket.weightG, 102.5);
      expect(stalePacket.sequence, 1);
    });
  });

  group('BleConfigProfile Preset and UUID Validation Tests', () {
    test('ESP32-C3 Test Preset matches exact specification', () {
      final p = BleConfigProfile.esp32Test();

      expect(p.profileId, 'esp32_test');
      expect(p.deviceNameFilter, 'DINIECO_PAD_TEST');
      expect(p.serviceUuid, '7b8a0001-4d2f-4a6b-9c1e-123456789001');
      expect(p.characteristicUuid, '7b8a0002-4d2f-4a6b-9c1e-123456789001');
      expect(p.dataFormat, 'json');
      expect(p.isNotification, isTrue);
      expect(p.weightUnit, 'g');
    });

    test('DINIECO Production Preset matches production backend protocol', () {
      final p = BleConfigProfile.diniecoProduction();

      expect(p.profileId, 'dinieco_prod');
      expect(p.deviceNameFilter, 'DINIECO-PAD');
      expect(p.serviceUuid, '0000ffe0-0000-1000-8000-00805f9b34fb');
      expect(p.characteristicUuid, '0000ffe1-0000-1000-8000-00805f9b34fb');
      expect(p.dataFormat, 'binary_stream');
      expect(p.isNotification, isTrue);
    });

    test('UUID Validation correctly identifies 128-bit and 16-bit UUID formats', () {
      // Valid 128-bit UUIDs
      expect(BleConfigProfile.isValidUuid('7b8a0001-4d2f-4a6b-9c1e-123456789001'), isTrue);
      expect(BleConfigProfile.isValidUuid('0000ffe0-0000-1000-8000-00805f9b34fb'), isTrue);
      expect(BleConfigProfile.isValidUuid('7B8A0001-4D2F-4A6B-9C1E-123456789001'), isTrue);

      // Valid 16-bit UUIDs
      expect(BleConfigProfile.isValidUuid('ffe0'), isTrue);
      expect(BleConfigProfile.isValidUuid('180D'), isTrue);
      expect(BleConfigProfile.isValidUuid('0xFFE0'), isTrue);

      // Invalid UUIDs
      expect(BleConfigProfile.isValidUuid(''), isFalse);
      expect(BleConfigProfile.isValidUuid('not-a-uuid'), isFalse);
      expect(BleConfigProfile.isValidUuid('7b8a0001-4d2f-4a6b-9c1e-12345678900Z'), isFalse);
      expect(BleConfigProfile.isValidUuid('123'), isFalse);
    });

    test('Custom profile serializes and deserializes to/from JSON cleanly', () {
      final custom = BleConfigProfile.custom(
        name: 'Lab Prototype',
        deviceNameFilter: 'DINIECO_LAB',
        serviceUuid: '12345678-1234-1234-1234-1234567890ab',
        characteristicUuid: '12345678-1234-1234-1234-1234567890cd',
        dataFormat: 'json',
        weightUnit: 'kg',
        timeoutSeconds: 15,
        autoReconnect: false,
      );

      final jsonStr = jsonEncode(custom.toJson());
      final decoded = BleConfigProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(decoded.name, 'Lab Prototype');
      expect(decoded.deviceNameFilter, 'DINIECO_LAB');
      expect(decoded.serviceUuid, '12345678-1234-1234-1234-1234567890ab');
      expect(decoded.characteristicUuid, '12345678-1234-1234-1234-1234567890cd');
      expect(decoded.weightUnit, 'kg');
      expect(decoded.timeoutSeconds, 15);
      expect(decoded.autoReconnect, isFalse);
    });
  });

  group('BleDeviceItem Model Tests', () {
    test('Formats displayName with fallback to device ID when advertised name is empty', () {
      final devWithName = BleDeviceItem(
        id: 'AA:BB:CC:DD:EE:FF',
        name: 'DINIECO_PAD_TEST',
        rssi: -62,
      );
      expect(devWithName.displayName, 'DINIECO_PAD_TEST');

      final devWithoutName = BleDeviceItem(
        id: '11:22:33:44:55:66',
        name: '',
        rssi: -78,
      );
      expect(devWithoutName.displayName, 'Unnamed Peripheral (11:22:33:44:55:66)');
    });
  });
}
