import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/security/model.dart';

/// 3 APES: device state as Android or iOS reports it. Read only, stays here.
class DeviceInfo {
  final bool? screenLock;

  /// "YYYY-MM-DD" from Build.VERSION.SECURITY_PATCH.
  final String? securityPatch;
  final bool developerOptions;
  final bool adb;

  /// False on iOS: there is no public way to read developer mode there.
  final bool developerKnown;

  /// iOS: "Face ID" / "Touch ID" when enrolled; null otherwise.
  final String? biometry;

  /// iOS: system version, e.g. "26.6.1".
  final String? osVersion;

  /// Apps allowed to install other apps; null when Android did not say.
  final List<String>? installers;

  /// Known only while our VPN service runs; otherwise null.
  final bool? alwaysOn;
  final bool? lockdown;

  const DeviceInfo({
    this.screenLock,
    this.securityPatch,
    this.developerOptions = false,
    this.adb = false,
    this.developerKnown = true,
    this.biometry,
    this.osVersion,
    this.installers,
    this.alwaysOn,
    this.lockdown,
  });

  static DeviceInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    bool? flag(String key) => raw[key] is bool ? raw[key] as bool : null;
    final installers = raw['installers'];
    final patch = raw['securityPatch'];
    String? text(String key) {
      final value = raw[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return DeviceInfo(
      screenLock: flag('screenLock'),
      securityPatch: patch is String && patch.trim().isNotEmpty
          ? patch.trim()
          : null,
      developerOptions: flag('developerOptions') ?? false,
      adb: flag('adb') ?? false,
      developerKnown: raw.containsKey('developerOptions'),
      biometry: text('biometry'),
      osVersion: text('osVersion'),
      installers: installers is List
          ? installers.whereType<String>().where((s) => s.isNotEmpty).toList()
          : null,
      alwaysOn: flag('alwaysOn'),
      lockdown: flag('lockdown'),
    );
  }

  static const _channel = MethodChannel('app.threeapes.client/device');

  /// Null off Android and iOS, or when the system does not answer.
  static Future<DeviceInfo?> read() async {
    if (!AppPlatform.isAndroid && !AppPlatform.isIOS) return null;
    try {
      return fromMap(await _channel.invokeMethod<Object?>('deviceSecurity'));
    } catch (_) {
      return null;
    }
  }
}

/// Months between the patch date and [now]; null when unreadable.
int? patchAgeMonths(String? patch, DateTime now) {
  if (patch == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$').firstMatch(patch);
  if (m == null) return null;
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  final months = (now.year - year) * 12 + (now.month - month);
  return months < 0 ? 0 : months;
}

/// 3 APES: the newest iOS major version on [now]. Apple numbers iOS by the
/// coming year (iOS 26 — autumn 2025) and ships it in September; October
/// leaves a month for the release to reach everyone.
int currentIosMajor(DateTime now) => now.year - (now.month >= 10 ? 1999 : 2000);

/// Device rows in screen order; rows without data are left out.
List<SecurityItem> evaluateDevice(DeviceInfo? info, {required DateTime now}) {
  if (info == null) return const [];
  final items = <SecurityItem>[];
  final lock = info.screenLock;
  if (lock != null) {
    items.add(
      SecurityItem(
        SecurityCheckId.screenLock,
        lock ? SecurityVerdict.lockOn : SecurityVerdict.lockOff,
        address: lock ? info.biometry : null,
      ),
    );
  }
  final age = patchAgeMonths(info.securityPatch, now);
  if (age != null) {
    items.add(
      SecurityItem(
        SecurityCheckId.securityPatch,
        age > 12
            ? SecurityVerdict.patchVeryOld
            : age > 6
            ? SecurityVerdict.patchOld
            : SecurityVerdict.patchFresh,
        address: info.securityPatch,
      ),
    );
  }
  final version = info.osVersion;
  final major = int.tryParse(version?.split('.').first ?? '');
  if (version != null && major != null) {
    final current = currentIosMajor(now);
    items.add(
      SecurityItem(
        SecurityCheckId.osVersion,
        major >= current
            ? SecurityVerdict.osCurrent
            : major == current - 1
            ? SecurityVerdict.osPrevious
            : SecurityVerdict.osOutdated,
        address: 'iOS $version',
      ),
    );
  }
  if (info.developerKnown) {
    items.add(
      SecurityItem(
        SecurityCheckId.developer,
        info.adb
            ? SecurityVerdict.developerAdb
            : info.developerOptions
            ? SecurityVerdict.developerOn
            : SecurityVerdict.developerOff,
      ),
    );
  }
  final installers = info.installers;
  if (installers != null) {
    items.add(
      SecurityItem(
        SecurityCheckId.installers,
        installers.isEmpty
            ? SecurityVerdict.installersStore
            : SecurityVerdict.installersOther,
        address: installers.isEmpty ? null : _shortList(installers),
      ),
    );
  }
  final alwaysOn = info.alwaysOn;
  if (alwaysOn != null) {
    items.add(
      SecurityItem(
        SecurityCheckId.alwaysOn,
        !alwaysOn
            ? SecurityVerdict.alwaysOnOff
            : info.lockdown == true
            ? SecurityVerdict.alwaysOnFull
            : SecurityVerdict.alwaysOnNoBlock,
      ),
    );
  }
  return items;
}

String _shortList(List<String> names) => names.length <= 3
    ? names.join(', ')
    : '${names.take(3).join(', ')} +${names.length - 3}';
