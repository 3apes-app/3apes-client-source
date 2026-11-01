import 'dart:async';

import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:quick_actions/quick_actions.dart';

enum ShortCutAction {
  startVpn,
  stopVpn,
  chooseConfiguration,
  updateSubscriptions,

  /// 3 APES: opens the «Проверка» tab.
  securityCheck,
}

/// Mobile launcher integration only. The shell attaches business actions after
/// normal startup; a cold-launch action must not race automatic Connect.
final class ShortCutService {
  static final ShortCutService _instance = ShortCutService._();
  factory ShortCutService() => _instance;
  ShortCutService._()
    : _suppressAutoConnect = AppStartupService().suppressConnectOnAppLaunch;
  ShortCutService.forTesting({required this._suppressAutoConnect});

  final void Function() _suppressAutoConnect;

  final _quickActions = const QuickActions();
  Future<void>? _initializing;
  Future<void> Function(ShortCutAction)? _handler;
  ShortCutAction? _pending;
  final _running = <ShortCutAction>{};

  Future<void> initialize() async {
    if (!AppPlatform.isMobile) return;
    try {
      await (_initializing ??= _quickActions.initialize(receive));
    } catch (error, stackTrace) {
      _initializing = null;
      ygLogger('Initialize quick actions failed: $error\n$stackTrace');
    }
  }

  Future<void> receive(String type) async {
    final action = ShortCutAction.values
        .where((item) => item.name == type)
        .firstOrNull;
    if (action == null) return;
    final handler = _handler;
    if (handler == null) {
      _pending = action;
      _suppressAutoConnect();
      return;
    }
    if (!_running.add(action)) return;
    try {
      await handler(action);
    } catch (error, stackTrace) {
      ygLogger('Quick action failed: $error\n$stackTrace');
    } finally {
      _running.remove(action);
    }
  }

  void attach(Future<void> Function(ShortCutAction) handler) {
    _handler = handler;
    final pending = _pending;
    _pending = null;
    if (pending != null) unawaited(receive(pending.name));
  }

  void detach() => _handler = null;

  /// 3 APES: long press on the icon — Подключить, Отключить, Проверка
  /// безопасности, Обновить подписки. [ShortCutAction.chooseConfiguration]
  /// stays handled for shortcuts pinned by older versions.
  static List<ShortcutItem> items(AppLocalizations l) => [
    ShortcutItem(
      type: ShortCutAction.startVpn.name,
      localizedTitle: l.shortcutConnect,
      icon: 'start_vpn',
    ),
    ShortcutItem(
      type: ShortCutAction.stopVpn.name,
      localizedTitle: l.shortcutDisconnect,
      icon: 'stop_vpn',
    ),
    ShortcutItem(
      type: ShortCutAction.securityCheck.name,
      localizedTitle: l.securityPromoTitle,
      icon: 'shortcut_check',
    ),
    ShortcutItem(
      type: ShortCutAction.updateSubscriptions.name,
      localizedTitle: l.menuShortcutUpdateSubscriptions,
      icon: 'update_subscriptions',
    ),
  ];

  Future<void> refresh(AppLocalizations l) async {
    if (!AppPlatform.isMobile) return;
    try {
      await _quickActions.setShortcutItems(items(l));
    } catch (error, stackTrace) {
      ygLogger('Publish quick actions failed: $error\n$stackTrace');
    }
  }
}
