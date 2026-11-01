import 'package:onexray/service/shared/failure.dart';
import 'package:material_ui/material_ui.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:onexray/core/advanced_mode.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/shared/connection_action.dart';
import 'package:onexray/service/advanced/xray/data_update/state.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/shared/ping/state.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/service/settings/app_update/service.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/settings/data_cleanup.dart';
import 'package:onexray/service/settings/traffic_widget.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:onexray/service/shared/doc/helper.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPageState {
  final String appVersion;
  final String xrayVersion;
  final AppIcon appIcon;
  final bool connectOnLaunch;
  final bool hwidConsent;
  final bool loading;
  final bool saving;
  final bool checkingUpdate;
  final bool clearingData;
  final bool addingWidget;
  final Object? failure;
  const SettingsPageState({
    this.appVersion = '—',
    this.xrayVersion = '—',
    this.appIcon = AppIcon.primary,
    this.connectOnLaunch = false,
    this.hwidConsent = false,
    this.loading = true,
    this.saving = false,
    this.checkingUpdate = false,
    this.clearingData = false,
    this.addingWidget = false,
    this.failure,
  });

  SettingsPageState copyWith({
    String? appVersion,
    String? xrayVersion,
    AppIcon? appIcon,
    bool? connectOnLaunch,
    bool? hwidConsent,
    bool? loading,
    bool? saving,
    bool? checkingUpdate,
    bool? clearingData,
    bool? addingWidget,
    Object? failure,
    bool clearFailure = false,
  }) => SettingsPageState(
    appVersion: appVersion ?? this.appVersion,
    xrayVersion: xrayVersion ?? this.xrayVersion,
    appIcon: appIcon ?? this.appIcon,
    connectOnLaunch: connectOnLaunch ?? this.connectOnLaunch,
    hwidConsent: hwidConsent ?? this.hwidConsent,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    checkingUpdate: checkingUpdate ?? this.checkingUpdate,
    clearingData: clearingData ?? this.clearingData,
    addingWidget: addingWidget ?? this.addingWidget,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

enum SettingsLink {
  documentation,
  review,
  community,
  feedback,

  /// 3 APES: the provider's support link, else the app's support e-mail.
  support,
  source,
  credits,
  privacy,
}

class SettingsController extends PageCubit<SettingsPageState> {
  SettingsController() : super(const SettingsPageState()) {
    _readVersions();
    _readPreferences();
  }

  // One brand icon: OneXray alternate icon colours are not shipped (macOS: Mac-1).
  bool get showAppIcon => false;

  Future<void> addTrafficWidget(BuildContext context) async {
    if (state.addingWidget) return;
    emit(state.copyWith(addingWidget: true));
    try {
      final requested = await TrafficWidgetService().requestPin();
      if (!requested && context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.trafficWidgetManualHint,
        );
      }
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    } finally {
      emit(state.copyWith(addingWidget: false));
    }
  }

  Future<void> _readVersions() async {
    var appVersion = '—';
    var xrayVersion = '—';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (error) {
      // Optional display facts remain unavailable instead of using demo values.
    }
    try {
      final version = await AppHostApi().xrayVersion();
      if (version.isNotEmpty) xrayVersion = version;
    } catch (error) {
      // App metadata can still be shown when the native version call fails.
    }
    emit(state.copyWith(appVersion: appVersion, xrayVersion: xrayVersion));
  }

  Future<void> _readPreferences() async {
    try {
      final connect = await PreferencesKey().readConnectOnAppLaunch();
      final hwidConsent = await PreferencesKey().readHwidConsent();
      final icon = showAppIcon
          ? AppIcon.fromString(await AppHostApi().getCurrentAppIcon())
          : null;
      emit(
        state.copyWith(
          connectOnLaunch: connect,
          hwidConsent: hwidConsent,
          appIcon: icon ?? AppIcon.primary,
          loading: false,
        ),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, failure: error));
    }
  }

  Future<void> openSetting(
    BuildContext context,
    AppPageDestination destination,
  ) async {
    await context.pushScoped(destination);
    if (isPageActive && destination == AppPageDestination.appIcon) {
      await _readPreferences();
    }
  }

  Future<void> setConnectOnLaunch(BuildContext context, bool value) async {
    if (state.saving || state.loading) return;
    emit(state.copyWith(saving: true, clearFailure: true));
    try {
      await PreferencesKey().saveConnectOnAppLaunch(value);
      emit(state.copyWith(connectOnLaunch: value));
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  /// 3 APES: device ID consent for all subscriptions, current and new.
  Future<void> setHwidConsent(BuildContext context, bool value) async {
    if (state.saving || state.loading) return;
    emit(state.copyWith(saving: true, clearFailure: true));
    try {
      await PreferencesKey().saveHwidConsent(value);
      await SubscriptionService().applyHwidConsent(value);
      emit(state.copyWith(hwidConsent: value));
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  Future<void> checkUpdate(BuildContext context) async {
    if (state.checkingUpdate) return;
    emit(state.copyWith(checkingUpdate: true));
    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!context.mounted) return;
      switch (result.status) {
        case AppUpdateCheckStatus.available:
          final update = result.updateInfo!;
          AppEventBus.instance.updateAppUpdateInfo(update);
          await context.pushAppUpdateDialog(update);
        case AppUpdateCheckStatus.upToDate:
          AppEventBus.instance.updateAppUpdateInfo(null);
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.appUpdateAlreadyLatest,
          );
        case AppUpdateCheckStatus.failed:
          ContextAlert.showToast(
            context,
            appFailureMessage(
              AppLocalizations.of(context)!,
              result.error,
              operation: AppLocalizations.of(context)!.appUpdateCheckFailed,
            ),
          );
      }
    } catch (error) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          appFailureMessage(
            AppLocalizations.of(context)!,
            error,
            operation: AppLocalizations.of(context)!.appUpdateCheckFailed,
          ),
        );
      }
    } finally {
      emit(state.copyWith(checkingUpdate: false));
    }
  }

  Future<void> clearData(BuildContext context) async {
    if (state.clearingData) return;
    final l10n = AppLocalizations.of(context)!;
    emit(state.copyWith(clearingData: true, clearFailure: true));
    try {
      if (!await AppConfirmationDialog(
            title: l10n.prototypeClearAllDataQuestion,
            content: l10n.prototypeClearAllDataWarning,
            cancelLabel: l10n.prototypeCancel,
            confirmLabel: l10n.prototypeConfirmClearData,
            destructive: true,
            barrierDismissible: false,
            compact: true,
          ).show(context) ||
          !context.mounted) {
        return;
      }
      if (await AppDataCleanupService().clearFromSettings()) {
        AppStartupService().suppressConnectOnAppLaunch();
        emit(state.copyWith(connectOnLaunch: false));
        if (!context.mounted) return;
        // 3 APES: say what happened and lead back to adding a subscription
        // (the main screen shows paste and QR when there is none).
        await AppConfirmationDialog(
          title: l10n.dataClearedTitle,
          content: l10n.dataClearedText,
          cancelLabel: null,
          confirmLabel: l10n.dataClearedAction,
          compact: true,
          barrierDismissible: false,
        ).show(context);
        if (context.mounted) {
          context.goPrimaryRoot(AppPrimaryDestination.connect);
        }
      } else if (context.mounted) {
        _showUnavailable(context);
      }
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    } finally {
      emit(state.copyWith(clearingData: false));
    }
  }

  Future<void> setAdvancedMode(bool value) => AdvancedMode.set(value);

  /// 3 APES: one way back if someone changed settings and the VPN stopped
  /// working — connection settings, latency check, update periods, launch
  /// connect and advanced mode go back to defaults. Subscriptions, servers,
  /// language and theme stay.
  Future<void> resetSettings(BuildContext context) async {
    if (state.saving || state.loading) return;
    final l10n = AppLocalizations.of(context)!;
    if (!await AppConfirmationDialog(
          title: l10n.settingsResetQuestion,
          content: l10n.settingsResetWarning,
          cancelLabel: l10n.prototypeCancel,
          confirmLabel: l10n.settingsResetConfirm,
          destructive: true,
          compact: true,
        ).show(context) ||
        !context.mounted) {
      return;
    }
    emit(state.copyWith(saving: true, clearFailure: true));
    try {
      final coordinator = ConnectionCoordinator.instance;
      final current = await coordinator.configuration;
      final next = ConnectionConfiguration();
      if (next.encode() != current.encode() && context.mounted) {
        final applied = await runConnectionAction(
          context,
          coordinator,
          () => coordinator.apply(
            next,
            expectedConfiguration: current.encode(),
            allowReconnect:
                coordinator.state.value.phase == ConnectionPhase.connected,
          ),
        );
        if (!applied) return;
      }
      await PingState().saveToPreferences();
      await AutoUpdateState().saveToPreferences();
      await PreferencesKey().saveConnectOnAppLaunch(false);
      await AdvancedMode.set(false);
      emit(state.copyWith(connectOnLaunch: false));
      if (context.mounted) {
        // 3 APES: a short summary instead of a toast that is easy to miss.
        await AppConfirmationDialog(
          title: l10n.settingsResetDone,
          content: l10n.settingsResetDoneText,
          cancelLabel: null,
          confirmLabel: l10n.prototypeDone,
          compact: true,
        ).show(context);
      }
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  Future<void> setTheme(BuildContext context, ThemeCode theme) async {
    emit(state.copyWith(clearFailure: true));
    try {
      await AppEventBus.instance.updateThemeCode(theme);
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    }
  }

  Future<void> openLink(BuildContext context, SettingsLink link) async {
    emit(state.copyWith(clearFailure: true));
    final uri = switch (link) {
      SettingsLink.documentation => DocURLHelper.docUri(),
      SettingsLink.review => null,
      SettingsLink.community => Uri.parse('https://t.me/YuanDevTeam'),
      SettingsLink.feedback => Uri.parse('mailto:support@3apes.app'),
      SettingsLink.support =>
        await _providerSupportUri() ?? Uri.parse('mailto:support@3apes.app'),
      // 3 APES: licenses page (OneXray, GPL-3.0, components, source).
      SettingsLink.source => Uri.parse('https://3apes.app/licenses'),
      SettingsLink.credits => DocURLHelper.creditsUri(),
      SettingsLink.privacy => DocURLHelper.privacyUri(),
    };
    try {
      if (uri == null) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        } else if (context.mounted) {
          _showUnavailable(context);
        }
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          _showUnavailable(context, 'No application could open this link.');
        }
      }
    } catch (error) {
      if (context.mounted) _showUnavailable(context, error);
    }
  }

  static Future<Uri?> _providerSupportUri() async {
    try {
      for (final row in await AppDatabase().subscriptionDao.allRows) {
        final uri = Uri.tryParse(row.supportUrl ?? '');
        if (uri != null && uri.hasScheme) return uri;
      }
    } catch (_) {
      // Fall back to the app's support address.
    }
    return null;
  }

  void _showUnavailable(BuildContext context, [Object? error]) {
    if (context.mounted) {
      emit(state.copyWith(failure: error));
      ContextAlert.showToast(
        context,
        appFailureMessage(AppLocalizations.of(context)!, error),
      );
    }
  }
}
