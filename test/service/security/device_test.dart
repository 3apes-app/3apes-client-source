import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/security/device.dart';
import 'package:onexray/service/security/model.dart';

// 3 APES security check: device rows.

final now = DateTime(2026, 10, 16);

SecurityVerdict? verdictOf(List<SecurityItem> items, SecurityCheckId id) {
  for (final i in items) {
    if (i.id == id) return i.verdict;
  }
  return null;
}

void main() {
  test('patch age in months', () {
    expect(patchAgeMonths('2026-09-01', now), 1);
    expect(patchAgeMonths('2025-10-05', now), 12);
    expect(patchAgeMonths('2027-01-01', now), 0);
    expect(patchAgeMonths('2026-13-01', now), isNull);
    expect(patchAgeMonths('soon', now), isNull);
    expect(patchAgeMonths(null, now), isNull);
  });

  test('fromMap reads what Android sends', () {
    final info = DeviceInfo.fromMap({
      'screenLock': true,
      'securityPatch': '2026-09-01',
      'developerOptions': true,
      'adb': false,
      'installers': ['Files', '', 3],
      'alwaysOn': null,
      'lockdown': null,
    })!;
    expect(info.screenLock, isTrue);
    expect(info.installers, ['Files']);
    expect(info.alwaysOn, isNull);
    expect(DeviceInfo.fromMap(null), isNull);
  });

  test('a safe device is all green', () {
    final items = evaluateDevice(
      const DeviceInfo(
        screenLock: true,
        securityPatch: '2026-09-01',
        installers: [],
        alwaysOn: true,
        lockdown: true,
      ),
      now: now,
    );
    expect(items.map((i) => i.id), [
      SecurityCheckId.screenLock,
      SecurityCheckId.securityPatch,
      SecurityCheckId.developer,
      SecurityCheckId.installers,
      SecurityCheckId.alwaysOn,
    ]);
    expect(items.every((i) => i.level == SecurityLevel.ok), isTrue);
    expect(items[1].address, '2026-09-01');
  });

  test('risky device: warnings, danger and settings actions', () {
    final items = evaluateDevice(
      const DeviceInfo(
        screenLock: false,
        securityPatch: '2025-01-01',
        developerOptions: true,
        adb: true,
        installers: ['A', 'B', 'C', 'D', 'E'],
        alwaysOn: true,
        lockdown: false,
      ),
      now: now,
    );
    final lock = items.firstWhere((i) => i.id == SecurityCheckId.screenLock);
    expect(lock.verdict, SecurityVerdict.lockOff);
    expect(lock.verdict.action, SecurityAction.security);
    expect(
      verdictOf(items, SecurityCheckId.securityPatch),
      SecurityVerdict.patchVeryOld,
    );
    expect(
      verdictOf(items, SecurityCheckId.developer),
      SecurityVerdict.developerAdb,
    );
    final installers = items.firstWhere(
      (i) => i.id == SecurityCheckId.installers,
    );
    expect(installers.verdict, SecurityVerdict.installersOther);
    expect(installers.address, 'A, B, C +2');
    expect(
      verdictOf(items, SecurityCheckId.alwaysOn),
      SecurityVerdict.alwaysOnNoBlock,
    );
    expect(items.where((i) => i.isIssue).length, 5);
  });

  test('half a year old patch is a warning; developer mode alone is info', () {
    final items = evaluateDevice(
      const DeviceInfo(securityPatch: '2026-03-01', developerOptions: true),
      now: now,
    );
    expect(
      verdictOf(items, SecurityCheckId.securityPatch),
      SecurityVerdict.patchOld,
    );
    expect(
      verdictOf(items, SecurityCheckId.developer),
      SecurityVerdict.developerOn,
    );
    // No data: no lock, installers or always-on rows.
    expect(verdictOf(items, SecurityCheckId.screenLock), isNull);
    expect(verdictOf(items, SecurityCheckId.installers), isNull);
    expect(verdictOf(items, SecurityCheckId.alwaysOn), isNull);
  });

  test('fromMap reads what iOS sends', () {
    final info = DeviceInfo.fromMap({
      'screenLock': true,
      'biometry': 'Face ID',
      'osVersion': '26.6.1',
    })!;
    expect(info.screenLock, isTrue);
    expect(info.biometry, 'Face ID');
    expect(info.osVersion, '26.6.1');
    expect(info.developerKnown, isFalse);
  });

  test('current iOS major follows the September release', () {
    expect(currentIosMajor(DateTime(2026, 9, 20)), 26);
    expect(currentIosMajor(DateTime(2026, 10, 1)), 27);
    expect(currentIosMajor(DateTime(2027, 3, 1)), 27);
  });

  test('iPhone: lock with Face ID, system version, no developer row', () {
    List<SecurityItem> rows(String version) => evaluateDevice(
      DeviceInfo(
        screenLock: true,
        biometry: 'Face ID',
        osVersion: version,
        developerKnown: false,
      ),
      now: now,
    );
    final items = rows('27.0.1');
    expect(items.map((i) => i.id), [
      SecurityCheckId.screenLock,
      SecurityCheckId.osVersion,
    ]);
    expect(items[0].verdict, SecurityVerdict.lockOn);
    expect(items[0].address, 'Face ID');
    expect(items[1].verdict, SecurityVerdict.osCurrent);
    expect(items[1].address, 'iOS 27.0.1');
    expect(
      verdictOf(rows('26.6.1'), SecurityCheckId.osVersion),
      SecurityVerdict.osPrevious,
    );
    expect(
      verdictOf(rows('18.7'), SecurityCheckId.osVersion),
      SecurityVerdict.osOutdated,
    );
  });

  test('no passcode on iPhone: danger without biometry', () {
    final items = evaluateDevice(
      const DeviceInfo(
        screenLock: false,
        biometry: 'Face ID',
        developerKnown: false,
      ),
      now: now,
    );
    expect(items.single.verdict, SecurityVerdict.lockOff);
    expect(items.single.address, isNull);
  });

  test('no data off Android: no device rows', () {
    expect(evaluateDevice(null, now: now), isEmpty);
  });
}
