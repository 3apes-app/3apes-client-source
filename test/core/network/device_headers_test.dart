import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/network/device_headers.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

void main() {
  group('DeviceHeaders.hwidFromId', () {
    test('is the salted SHA-256 in UUID format (same on Android and iOS)', () {
      expect(
        DeviceHeaders.hwidFromId('abc'),
        'ead63e9f-b483-088e-5c86-0669c92a41f4',
      );
    });

    test('is stable for one ID and differs between IDs', () {
      final a = DeviceHeaders.hwidFromId('device-1');
      expect(DeviceHeaders.hwidFromId('device-1'), a);
      expect(DeviceHeaders.hwidFromId('device-2'), isNot(a));
      expect(a, matches(_uuid));
    });
  });
}
