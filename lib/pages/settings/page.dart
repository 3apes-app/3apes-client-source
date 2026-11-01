import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/pages/settings/controller.dart';
import 'package:onexray/pages/settings/widgets.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/settings/desktop/controller.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/event_bus/state.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:onexray/core/advanced_mode.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/service/settings/backup/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Row metrics shared by the settings page and the app pane in Advanced.
class _RowMetrics {
  final bool mobile;
  const _RowMetrics(this.mobile);

  double get rowHeight => mobile ? 43.0 : 56.0;
  double get sectionGap => mobile ? 25.0 : 28.0;
  EdgeInsets get rowPadding =>
      EdgeInsets.symmetric(horizontal: mobile ? 13 : 14, vertical: 10);

  static _RowMetrics of(BuildContext context) => _RowMetrics(
    MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint,
  );
}

Widget _startupSection(
  BuildContext context,
  SettingsController controller,
  SettingsPageState state,
) {
  final l10n = AppLocalizations.of(context)!;
  return SettingSection(
    title: l10n.prototypeStartup,
    icon: LucideIcons.power,
    padding: EdgeInsets.zero,
    dividerIndent: 0,
    children: [
      _StartupSettingRow(
        title: l10n.prototypeConnectAfterAppLaunch,
        subtitle: l10n.prototypeConnectAfterAppLaunchHint,
        value: state.connectOnLaunch,
        onChanged: state.loading || state.saving
            ? null
            : (value) => controller.setConnectOnLaunch(context, value),
      ),
      if (AppPlatform.isDesktop)
        BlocProvider(
          create: (_) => DesktopSettingsController(),
          child: const _DesktopStartupRows(),
        ),
    ],
  );
}

/// 3 APES: the full import (server links, files, JSON, encrypted
/// subscriptions) — off the simple «Новая подписка» on the phone.
Widget _importSection(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final m = _RowMetrics.of(context);
  return SettingSection(
    title: l10n.advancedImportSection,
    icon: LucideIcons.fileInput,
    padding: EdgeInsets.zero,
    dividerIndent: 0,
    children: [
      SettingRow(
        key: const ValueKey('advanced-import'),
        title: l10n.advancedImportRow,
        subtitle: l10n.advancedImportHint,
        minHeight: m.rowHeight,
        contentPadding: m.rowPadding,
        titleStyle: AppTypography.settingsRow,
        showChevron: true,
        onTap: () => context.pushScoped(AppPageDestination.serversImport),
      ),
    ],
  );
}

Widget _dataSection(
  BuildContext context,
  SettingsController controller,
  SettingsPageState state, {
  bool includeWidget = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final palette = ColorManager.palette(context);
  final m = _RowMetrics.of(context);
  return SettingSection(
    title: l10n.prototypeData,
    icon: LucideIcons.hardDrive,
    padding: EdgeInsets.zero,
    dividerIndent: 0,
    children: [
      if (includeWidget && AppPlatform.isAndroid)
        _trafficWidgetRow(context, controller, state),
      if (BackupService.supported)
        SettingRow(
          title: l10n.backupTitle,
          minHeight: m.rowHeight,
          contentPadding: m.rowPadding,
          titleStyle: AppTypography.settingsRow,
          showChevron: true,
          onTap: () =>
              controller.openSetting(context, AppPageDestination.backup),
        ),
      SettingRow(
        title: l10n.prototypeClearData,
        minHeight: m.rowHeight,
        contentPadding: m.rowPadding,
        titleStyle:
            (m.mobile
                    ? AppTypography.settingsDanger
                    : AppTypography.desktopSettingsDanger)
                .copyWith(color: palette.destructive),
        trailing: state.clearingData
            ? const ButtonProgressIndicator(size: 20)
            : null,
        onTap: state.clearingData ? null : () => controller.clearData(context),
      ),
    ],
  );
}

Widget _trafficWidgetRow(
  BuildContext context,
  SettingsController controller,
  SettingsPageState state,
) {
  final m = _RowMetrics.of(context);
  return SettingRow(
    title: AppLocalizations.of(context)!.trafficWidgetAdd,
    minHeight: m.rowHeight,
    contentPadding: m.rowPadding,
    titleStyle: AppTypography.settingsRow,
    trailing: state.addingWidget
        ? const ButtonProgressIndicator(size: 20)
        : null,
    showChevron: true,
    onTap: state.addingWidget
        ? null
        : () => controller.addTrafficWidget(context),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SettingsController(),
    child: BlocBuilder<SettingsController, SettingsPageState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final controller = context.read<SettingsController>();
        return Scaffold(
          appBar: PageAppBar.tab(l10n.prototypeSettings),
          body: SafeArea(
            child: BlocBuilder<AppEventBus, AppEventBusState>(
              builder: (context, preferences) {
                final m = _RowMetrics.of(context);
                final mobile = m.mobile;
                final palette = ColorManager.palette(context);
                final rowHeight = m.rowHeight;
                final sectionGap = m.sectionGap;
                final rowPadding = m.rowPadding;
                // The theme is always dark, so only platform rows remain here.
                final appearanceRows = [
                  if (AppPlatform.isAndroid)
                    _trafficWidgetRow(context, controller, state),
                  if (controller.showAppIcon)
                    SettingRow(
                      title: l10n.prototypeAppIcon,
                      value: appIconLabel(l10n, state.appIcon),
                      minHeight: mobile ? 52 : 56,
                      titleStyle: AppTypography.settingsRow,
                      valueStyle:
                          (mobile
                                  ? AppTypography.settingsVersion
                                  : AppTypography.desktopSettingsRowValue)
                              .copyWith(color: palette.mutedStrong),
                      contentPadding: rowPadding,
                      decorateLeading: false,
                      showChevron: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.compact),
                        child:
                            (AppPlatform.isMacOS
                                    ? state.appIcon.dockAssetImage
                                    : state.appIcon.assetImage)
                                .image(width: 26, height: 26),
                      ),
                      onTap: () => controller.openSetting(
                        context,
                        AppPageDestination.appIcon,
                      ),
                    ),
                ];
                final appearance = SettingSection(
                  title: l10n.prototypeAppearance,
                  icon: LucideIcons.palette,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: appearanceRows,
                );
                final language = SettingSection(
                  title: l10n.prototypeLanguage,
                  icon: LucideIcons.languages,
                  padding: EdgeInsets.zero,
                  children: [
                    SettingRow(
                      title: languageNativeLabel(
                        l10n,
                        preferences.languageCode,
                      ),
                      minHeight: rowHeight,
                      contentPadding: rowPadding,
                      titleStyle: AppTypography.settingsRow,
                      showChevron: true,
                      onTap: () => controller.openSetting(
                        context,
                        AppPageDestination.language,
                      ),
                    ),
                  ],
                );
                final startup = _startupSection(context, controller, state);
                final data = _dataSection(context, controller, state);
                final about = SettingSection(
                  title: l10n.prototypeAbout,
                  icon: LucideIcons.info,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: [
                    Semantics(
                      label: preferences.appUpdateInfo == null
                          ? null
                          : l10n.prototypeAboutUpdateAvailable,
                      child: SettingRow(
                        minHeight: rowHeight,
                        contentPadding: rowPadding,
                        title: l10n.prototypeAboutOneXray,
                        titleStyle: AppTypography.settingsRow,
                        titleTrailing: preferences.appUpdateInfo == null
                            ? null
                            : const SettingsUpdateDot(),
                        showChevron: true,
                        onTap: () => controller.openSetting(
                          context,
                          AppPageDestination.aboutOneXray,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        SettingsVersionRow(
                          label: l10n.prototypeAppVersion,
                          value: state.appVersion,
                          compact: true,
                          style: mobile
                              ? null
                              : AppTypography.desktopSettingsVersion,
                        ),
                        SettingsVersionRow(
                          label: 'Xray-core',
                          value: state.xrayVersion,
                          compact: true,
                          style: mobile
                              ? null
                              : AppTypography.desktopSettingsVersion,
                        ),
                      ],
                    ),
                  ],
                );
                // Phone: only what a regular user needs. Startup, data and the
                // widget live in Advanced → App.
                // 3 APES: the phone list of the new design (soft cards).
                final phone = [
                  _PhoneHero(
                    // 3 APES: the Xray version lives in About.
                    version: '3 APES · v${state.appVersion}',
                  ),
                  _PhoneGroup(
                    title: l10n.prototypeSubscriptions,
                    children: [
                      _PhoneSwitchRow(
                        icon: LucideIcons.keyRound,
                        title: l10n.hwidConsentTitle,
                        subtitle: l10n.hwidConsentSettingsHint,
                        value: state.hwidConsent,
                        onChanged: state.loading || state.saving
                            ? null
                            : (value) =>
                                  controller.setHwidConsent(context, value),
                      ),
                    ],
                  ),
                  // 3 APES: advanced settings appear only with the switch on.
                  ValueListenableBuilder<bool>(
                    valueListenable: AdvancedMode.enabled,
                    builder: (context, advanced, _) => _PhoneGroup(
                      title: l10n.settingsSectionApp,
                      children: [
                        _PhoneRow(
                          icon: LucideIcons.languages,
                          title: l10n.prototypeLanguage,
                          value: languageNativeLabel(
                            l10n,
                            preferences.languageCode,
                          ),
                          onTap: () => controller.openSetting(
                            context,
                            AppPageDestination.language,
                          ),
                        ),
                        // 3 APES: theme — system (default), light or dark.
                        _PhoneRow(
                          icon: LucideIcons.palette,
                          title: l10n.themePageTitle,
                          value: switch (preferences.themeCode) {
                            ThemeCode.system => l10n.themePageSystem,
                            ThemeCode.light => l10n.themePageLight,
                            ThemeCode.dark => l10n.themePageDark,
                          },
                          onTap: () => controller.openSetting(
                            context,
                            AppPageDestination.theme,
                          ),
                        ),
                        _PhoneSwitchRow(
                          icon: LucideIcons.power,
                          title: l10n.prototypeConnectAfterAppLaunch,
                          subtitle: l10n.prototypeConnectAfterAppLaunchHint,
                          value: state.connectOnLaunch,
                          onChanged: state.loading || state.saving
                              ? null
                              : (value) => controller.setConnectOnLaunch(
                                  context,
                                  value,
                                ),
                        ),
                        if (AppBuild.advancedToggle)
                          _PhoneSwitchRow(
                            key: const ValueKey('settings-advanced-mode'),
                            icon: LucideIcons.wrench,
                            title: l10n.advancedModeTitle,
                            subtitle: l10n.advancedModeHint,
                            value: advanced,
                            onChanged: state.saving
                                ? null
                                : controller.setAdvancedMode,
                          ),
                        if (advanced)
                          _PhoneRow(
                            icon: LucideIcons.slidersHorizontal,
                            title: l10n.prototypeAdvanced,
                            onTap: () => controller.openSetting(
                              context,
                              AppPageDestination.advanced,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _PhoneGroup(
                    title: l10n.prototypeData,
                    children: [
                      if (BackupService.supported)
                        _PhoneRow(
                          icon: LucideIcons.archive,
                          title: l10n.backupTitle,
                          onTap: () => controller.openSetting(
                            context,
                            AppPageDestination.backup,
                          ),
                        ),
                      _PhoneRow(
                        key: const ValueKey('settings-reset'),
                        icon: LucideIcons.rotateCcw,
                        title: l10n.settingsResetTitle,
                        onTap: () => controller.resetSettings(context),
                      ),
                      _PhoneRow(
                        icon: LucideIcons.trash2,
                        title: l10n.prototypeClearData,
                        destructive: true,
                        onTap: () {
                          if (!state.clearingData) {
                            controller.clearData(context);
                          }
                        },
                      ),
                    ],
                  ),
                  _PhoneGroup(
                    title: l10n.settingsSectionHelp,
                    children: [
                      _PhoneRow(
                        icon: LucideIcons.circleHelp,
                        title: l10n.settingsSupportContact,
                        onTap: () =>
                            controller.openLink(context, SettingsLink.support),
                      ),
                      _PhoneRow(
                        icon: LucideIcons.info,
                        title: l10n.prototypeAboutOneXray,
                        titleTrailing: preferences.appUpdateInfo == null
                            ? null
                            : const SettingsUpdateDot(),
                        onTap: () => controller.openSetting(
                          context,
                          AppPageDestination.aboutOneXray,
                        ),
                      ),
                    ],
                  ),
                ];
                final wideLeft = [
                  if (appearanceRows.isNotEmpty) appearance,
                  language,
                  startup,
                ];
                final wideRight = [data, about];
                List<Widget> spaced(List<Widget> sections) => [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) SizedBox(height: sectionGap),
                    sections[i],
                  ],
                ];
                return SettingsPageScroll(
                  desktopMaxWidth: AppLayout.settingsMaxWidth,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      mobile ? 16 : AppSpacing.page,
                      mobile ? 4 : 43,
                      mobile ? 16 : AppSpacing.page,
                      mobile ? 20 : 42,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.failure case final failure?)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: SelectableText(
                                appFailureMessage(l10n, failure),
                                style: AppTypography.supporting.copyWith(
                                  color: palette.destructive,
                                ),
                              ),
                            ),
                          ),
                        if (mobile)
                          ...phone
                        else
                          Builder(
                            builder: (context) =>
                                MediaQuery.sizeOf(context).width >
                                    AppLayout.compactDesktopBreakpoint
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: spaced(wideLeft),
                                        ),
                                      ),
                                      const SizedBox(width: 56),
                                      Expanded(
                                        child: Column(
                                          children: spaced(wideRight),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: spaced([
                                      ...wideLeft,
                                      ...wideRight,
                                    ]),
                                  ),
                          ),
                        if (!mobile)
                          Container(
                            padding: const EdgeInsets.only(top: 19, bottom: 3),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: palette.border),
                              ),
                            ),
                            child: Text(
                              l10n.prototypeSettingsLocationNote,
                              style: AppTypography.desktopSettingsNote.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

/// Startup, widget and data settings for the phone, shown as the "App" tab
/// of Advanced so the main settings stay minimal.
class AppSettingsPane extends StatelessWidget {
  const AppSettingsPane({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SettingsController(),
    child: BlocBuilder<SettingsController, SettingsPageState>(
      builder: (context, state) {
        final controller = context.read<SettingsController>();
        final m = _RowMetrics.of(context);
        return SettingsPageScroll(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 20, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _startupSection(context, controller, state),
                SizedBox(height: m.sectionGap),
                _importSection(context),
                SizedBox(height: m.sectionGap),
                _dataSection(context, controller, state, includeWidget: true),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _StartupSettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _StartupSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return SettingRow(
      title: title,
      subtitle: subtitle,
      minHeight: mobile ? 58 : 64,
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: mobile ? 13 : 14,
        vertical: mobile ? 7 : 9,
      ),
      titleStyle: mobile
          ? AppTypography.settingsFieldTitle
          : AppTypography.settingsRow,
      subtitleStyle:
          (mobile
                  ? AppTypography.settingsHint
                  : AppTypography.desktopSettingsHint)
              .copyWith(color: ColorManager.secondaryText(context)),
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: ShadSwitch(
        value: value,
        width: mobile ? 40 : 46,
        height: mobile ? 23 : 27,
        enabled: onChanged != null,
        onChanged: onChanged,
      ),
    );
  }
}

class _DesktopStartupRows extends StatelessWidget {
  const _DesktopStartupRows();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DesktopSettingsController, DesktopSettingsPageState>(
        builder: (context, state) {
          final controller = context.read<DesktopSettingsController>();
          final l10n = AppLocalizations.of(context)!;
          return Column(
            children: [
              _StartupSettingRow(
                title: l10n.prototypeLaunchAtLogin,
                subtitle: l10n.prototypeLaunchAtLoginHint,
                value: state.launchAtLogin.enabled,
                onChanged: state.launchToggleEnabled && !state.requiresApproval
                    ? (value) => controller.updateLaunchAtLogin(context, value)
                    : null,
              ),
              const Divider(height: 1),
              _StartupSettingRow(
                title: l10n.prototypeStartHidden,
                subtitle: l10n.prototypeStartHiddenHint,
                value: state.startHidden,
                onChanged: state.behaviorSettingsEnabled
                    ? (value) =>
                          controller.updateStartHidden(value, context: context)
                    : null,
              ),
              if (AppPlatform.isMacOS) ...[
                const Divider(height: 1),
                _StartupSettingRow(
                  title: l10n.prototypeHideDockIcon,
                  subtitle: l10n.prototypeHideDockIconHint,
                  value: state.hideDockIcon,
                  onChanged: state.behaviorSettingsEnabled
                      ? (value) => controller.updateHideDockIcon(
                          value,
                          context: context,
                        )
                      : null,
                ),
              ],
              if (state.requiresApproval) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.prototypeSystemApprovalRequired),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: state.changingLaunchAtLogin
                                ? null
                                : () => controller.updateLaunchAtLogin(
                                    context,
                                    false,
                                  ),
                            child: ButtonProgress(
                              busy: state.changingLaunchAtLogin,
                              child: Text(l10n.prototypeCancelRequest),
                            ),
                          ),
                          TextButton(
                            onPressed: state.openingSystemSettings
                                ? null
                                : () => controller.openSystemSettings(context),
                            child: ButtonProgress(
                              busy: state.openingSystemSettings,
                              child: Text(l10n.prototypeOpenSystemSettings),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );
}

/// 3 APES: mint card on top of the phone settings — the three monkeys with
/// their words and the versions. A tap makes them open and cover again.
class _PhoneHero extends StatefulWidget {
  const _PhoneHero({required this.version});

  final String version;

  @override
  State<_PhoneHero> createState() => _PhoneHeroState();
}

class _PhoneHeroState extends State<_PhoneHero> {
  bool _covered = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final home = connectionModeStyle(context, ConnectionMode.home);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: home.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _covered = !_covered),
          child: Padding(
            // 3 APES: a lower block with the monkeys closer together.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                ConnectMonkeys(
                  covered: _covered,
                  height: 90,
                  stepFactor: 0.66,
                  haptic: false,
                  holdOnDrop: false,
                  labels: [l.monkeySee, l.monkeySpeak, l.monkeyHear],
                  labelColors: [
                    for (final mode in ConnectionMode.values)
                      connectionModeStyle(context, mode).strong,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.version,
                  textAlign: TextAlign.center,
                  style: AppTypography.settingsNote.copyWith(
                    color: home.strong,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 3 APES: a section of the phone settings — spaced capitals, then a white
/// rounded card with a soft shadow and thin dividers.
class _PhoneGroup extends StatelessWidget {
  const _PhoneGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 24, 10, 10),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.serverSectionTitle.copyWith(
              color: palette.mutedForeground,
              letterSpacing: 1.6,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F161B33),
                offset: Offset(0, 6),
                blurRadius: 22,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, child) in children.indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 66,
                        color: palette.border,
                      ),
                    child,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Round mint icon in front of a settings row.
class _PhoneIcon extends StatelessWidget {
  const _PhoneIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final home = connectionModeStyle(context, ConnectionMode.home);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: home.surface, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: home.strong),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.titleTrailing,
    this.destructive = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? titleTrailing;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
          child: Row(
            children: [
              _PhoneIcon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.settingsRow.copyWith(
                          color: destructive
                              ? palette.destructive
                              : palette.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (titleTrailing != null) ...[
                      const SizedBox(width: 8),
                      titleTrailing!,
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Text(
                  value!,
                  style: AppTypography.settingsRow.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRightDir,
                size: 18,
                color: palette.mutedStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneSwitchRow extends StatelessWidget {
  const _PhoneSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          children: [
            _PhoneIcon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.settingsRow.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.settingsHint.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ShadSwitch(
              value: value,
              width: 44,
              height: 26,
              enabled: onChanged != null,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
