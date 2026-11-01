import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';

/// 3 APES: device description sent together with `x-hwid`, in the format
/// Happ uses and Remnawave stores (shown to the user in the bot's device list).
/// Only read when the user has allowed the device ID.
abstract final class DeviceHeaders {
  static const names = ['x-device-os', 'x-ver-os', 'x-device-model'];

  static Future<Map<String, String>>? _cached;

  static Future<Map<String, String>> read() => _cached ??= _read();

  static Future<Map<String, String>> _read() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (AppPlatform.isAndroid) {
        final info = await plugin.androidInfo;
        final stableHwid = await _stableHwid('androidId');
        return _clean({
          // Перекрывает случайный HWID подписки: одно устройство — одно место.
          'x-hwid': ?stableHwid,
          'x-device-os': 'Android',
          'x-ver-os': info.version.release,
          'x-device-model': _model(info.manufacturer, info.model),
        });
      }
      if (AppPlatform.isIOS) {
        final info = await plugin.iosInfo;
        final stableHwid = await _stableHwid('iosDeviceId');
        return _clean({
          // Как на Android: одно устройство — одно место, и после переустановки.
          'x-hwid': ?stableHwid,
          'x-device-os': 'iOS',
          'x-ver-os': info.systemVersion,
          'x-device-model': info.utsname.machine,
        });
      }
    } catch (_) {
      // The device ID still works without a description.
    }
    return const {};
  }

  static const _channel = MethodChannel('app.threeapes.client/device');

  /// 3 APES: постоянный HWID — хеш системного ID устройства с солью
  /// приложения в формате UUID. Источник: Android — ANDROID_ID (`androidId`),
  /// iOS — случайный UUID в Keychain только этого iPhone (`iosDeviceId`).
  /// Не меняется при переустановке приложения (только при сбросе телефона),
  /// поэтому устройство занимает в панели одно место.
  static Future<String?> _stableHwid(String method) async {
    try {
      final id = await _channel.invokeMethod<String>(method);
      if (id == null || id.isEmpty) return null;
      return hwidFromId(id);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static String hwidFromId(String id) {
    final hex = sha256.convert(utf8.encode('3apes-hwid-v1:$id')).toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static String _model(String manufacturer, String model) =>
      model.toLowerCase().startsWith(manufacturer.toLowerCase())
      ? model
      : '$manufacturer $model';

  // HTTP header values must be printable ASCII.
  static Map<String, String> _clean(Map<String, String> headers) => {
    for (final MapEntry(:key, :value) in headers.entries)
      if (value.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim() case final clean
          when clean.isNotEmpty)
        key: clean,
  };
}
