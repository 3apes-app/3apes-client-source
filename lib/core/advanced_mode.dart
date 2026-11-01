import 'package:flutter/foundation.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/core/constants/preferences.dart';

/// 3 APES: whether advanced settings are shown — the Xray and tunnel tabs,
/// server JSON editing, original share links and Age keys.
///
/// Starts as `true` so widget tests (which never call [load]) see the full
/// interface; the app calls [load] before the first frame, and for people
/// the stored default is off.
abstract final class AdvancedMode {
  static final enabled = ValueNotifier<bool>(true);

  static Future<void> load() async {
    enabled.value =
        AppBuild.advancedToggle && await PreferencesKey().readAdvancedMode();
  }

  static Future<void> set(bool value) async {
    final next = AppBuild.advancedToggle && value;
    await PreferencesKey().saveAdvancedMode(next);
    enabled.value = next;
  }
}
