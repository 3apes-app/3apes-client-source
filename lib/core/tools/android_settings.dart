import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';

/// 3 APES: system screens the app can only open, not change.
abstract final class AndroidSettings {
  static const _channel = MethodChannel('app.threeapes.client/device');

  /// Android's VPN settings, where Always-on VPN and "Block connections
  /// without VPN" are switched on. Returns false when they cannot be opened.
  static Future<bool> openVpnSettings() async {
    if (!AppPlatform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openVpnSettings') ?? false;
    } on Exception {
      return false;
    }
  }

  /// 3 APES: system screens the security check points to:
  /// "security", "developer", "unknownSources", "vpn".
  static Future<bool> open(String which) async {
    if (!AppPlatform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings', {
            'which': which,
          }) ??
          false;
    } on Exception {
      return false;
    }
  }
}
