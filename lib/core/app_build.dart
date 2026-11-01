/// 3 APES: what kind of build this is, set at build time with
/// `--dart-define=SITE_BUILD=true`.
abstract final class AppBuild {
  /// The APK from 3apes.app, outside the stores: it may send people to the
  /// 3 APES bot to get or renew a subscription. Store builds (the default)
  /// must not point to payment outside the store — App Store 3.1.1(a) and
  /// the Google Play payments policy — so they only add and refresh links.
  static const site = bool.fromEnvironment('SITE_BUILD');

  /// Where the site build gets and renews subscriptions.
  static const botUrl = 'https://t.me/Apes3VPNbot';

  /// How advanced settings are offered (`--dart-define=ADVANCED_SETTINGS=…`):
  /// `toggle` (default) — a «Расширенный режим» switch in Settings, off at
  /// first; `none` — no way in from the interface (the code stays). Never a
  /// remote flag or a hidden gesture: App Store 2.3.1.
  static const advancedSettings = String.fromEnvironment(
    'ADVANCED_SETTINGS',
    defaultValue: 'toggle',
  );

  static bool get advancedToggle => advancedSettings != 'none';

  /// Badge of «За границей» without servers in Russia
  /// (`--dart-define=ABROAD_BADGE=…`): `soon` (default) — «Скоро»; `tariff` —
  /// «Нет в вашем тарифе», once the mode is sold as a plan.
  static const abroadBadge = String.fromEnvironment(
    'ABROAD_BADGE',
    defaultValue: 'soon',
  );
}
