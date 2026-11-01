import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/servers/subscription/failure.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/servers/subscription/user_info.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:url_launcher/url_launcher.dart';

enum SubscriptionEndReason { expired, traffic }

/// 3 APES: «Подписка закончилась» on the phone main screen. Shown instead of
/// [child] while [enabled] (VPN off, nothing pending) and every subscription
/// has ended by date or by traffic, as the provider last reported.
class SubscriptionExpiredGate extends StatefulWidget {
  const SubscriptionExpiredGate({
    super.key,
    required this.enabled,
    required this.child,
    this.showRenew = true,
  });

  final bool enabled;

  /// «Продлить» — only in the site build: store builds must not point to
  /// payment outside the store (see [AppBuild.site]).
  final bool showRenew;
  final Widget child;

  /// Null while at least one subscription can still be used, or while any
  /// subscription has no provider data (then nothing is known for sure).
  static SubscriptionEndReason? reason(
    Iterable<SubscriptionData> rows,
    DateTime now,
  ) {
    if (rows.isEmpty) return null;
    var byDate = true;
    for (final row in rows) {
      final info = SubscriptionUserInfo.fromSubscription(row);
      if (info == null) return null;
      final expired = info.isExpired(now);
      if (!expired && !info.exhausted) return null;
      if (!expired) byDate = false;
    }
    return byDate
        ? SubscriptionEndReason.expired
        : SubscriptionEndReason.traffic;
  }

  static const botUrl = AppBuild.botUrl;

  /// The provider's page from the headers, else its support link, else the
  /// 3 APES bot.
  static Uri renewUri(Iterable<SubscriptionData> rows) {
    for (final row in rows) {
      for (final value in [row.webPageUrl, row.supportUrl]) {
        final uri = Uri.tryParse(value?.trim() ?? '');
        if (uri != null &&
            (uri.scheme == 'https' ||
                uri.scheme == 'http' ||
                uri.scheme == 'tg') &&
            (uri.scheme == 'tg' || uri.host.isNotEmpty)) {
          return uri;
        }
      }
    }
    return Uri.parse(botUrl);
  }

  static bool telegram(Uri uri) =>
      uri.scheme == 'tg' || uri.host == 't.me' || uri.host == 'telegram.me';

  @override
  State<SubscriptionExpiredGate> createState() =>
      _SubscriptionExpiredGateState();
}

class _SubscriptionExpiredGateState extends State<SubscriptionExpiredGate> {
  StreamSubscription<List<SubscriptionData>>? _stream;
  List<SubscriptionData> _rows = const [];
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    _stream = AppDatabase().subscriptionDao.allRowsStream.listen(
      (rows) {
        if (mounted) setState(() => _rows = rows);
      },
      onError: (Object _) {
        // The main screen must not fail because of this check.
      },
    );
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  Future<void> _renew() async {
    final l = AppLocalizations.of(context)!;
    final uri = SubscriptionExpiredGate.renewUri(_rows);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ContextAlert.showToast(context, l.subscriptionExpiredLinkFailed);
      }
    } catch (_) {
      if (mounted) {
        ContextAlert.showToast(context, l.subscriptionExpiredLinkFailed);
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _refreshing = true);
    String? failure;
    try {
      for (final row in List.of(_rows)) {
        final result = await SubscriptionService().refreshSubscriptionResult(
          row,
        );
        if (!result.success && !result.superseded) {
          failure ??= subscriptionFailureMessage(
            l,
            result.status,
            error: result.error,
            updating: true,
          );
        }
      }
      final rows = await AppDatabase().subscriptionDao.allRows;
      if (!mounted) return;
      setState(() => _rows = rows);
      if (SubscriptionExpiredGate.reason(rows, DateTime.now()) != null) {
        ContextAlert.showToast(context, failure ?? l.subscriptionExpiredStill);
      }
    } catch (error) {
      if (mounted) ContextAlert.showToast(context, appFailureMessage(l, error));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.enabled
        ? SubscriptionExpiredGate.reason(_rows, DateTime.now())
        : null;
    if (reason == null) return widget.child;
    return SubscriptionExpiredView(
      reason: reason,
      telegram: SubscriptionExpiredGate.telegram(
        SubscriptionExpiredGate.renewUri(_rows),
      ),
      refreshing: _refreshing,
      onRenew: widget.showRenew ? _renew : null,
      onRefresh: _refresh,
    );
  }
}

class SubscriptionExpiredView extends StatelessWidget {
  const SubscriptionExpiredView({
    super.key,
    required this.reason,
    required this.telegram,
    required this.refreshing,
    required this.onRenew,
    required this.onRefresh,
  });

  final SubscriptionEndReason reason;
  final bool telegram;
  final bool refreshing;

  /// Null hides «Продлить» (store builds); «Я уже продлил — обновить» then
  /// becomes the main button.
  final VoidCallback? onRenew;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final coral = connectionModeStyle(context, ConnectionMode.abroad);
    // 3 APES: the ring stays bright in the dark theme.
    final coralRing = connectionModeGlow(context, ConnectionMode.abroad);
    final primary = FilledButton.styleFrom(
      shape: const StadiumBorder(),
      backgroundColor: palette.running,
      foregroundColor: palette.runningForeground,
      disabledBackgroundColor: palette.running.withValues(alpha: 0.5),
      disabledForegroundColor: palette.runningForeground,
      minimumSize: const Size.fromHeight(52),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    Widget refreshIcon(Color color) => refreshing
        ? SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        : const Icon(LucideIcons.refreshCw, size: 16);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            minHeight: constraints.maxHeight,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                const SizedBox(height: 22),
                Text(
                  '3 APES',
                  style: AppTypography.setupBrand.copyWith(
                    color: palette.foreground,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 64,
                  height: 2,
                  decoration: BoxDecoration(
                    color: palette.running,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 20),
                ExcludeSemantics(
                  child: Container(
                    key: const ValueKey('subscription-expired-ring'),
                    width: 220,
                    height: 220,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: coral.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: coralRing.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        width: 142,
                        height: 142,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.card,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: coralRing.withValues(alpha: 0.25),
                              offset: const Offset(0, 6),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.power,
                          size: 52,
                          color: coralRing,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    reason == SubscriptionEndReason.expired
                        ? l.subscriptionExpiredTitle
                        : l.subscriptionTrafficOutTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.connectStatusTitle.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  onRenew == null
                      ? l.subscriptionExpiredHintStore
                      : l.subscriptionExpiredHint,
                  textAlign: TextAlign.center,
                  style: AppTypography.connectStatusDetail.copyWith(
                    fontSize: 14,
                    color: palette.mutedForeground,
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onRenew != null) ...[
                        FilledButton.icon(
                          key: const ValueKey('subscription-expired-renew'),
                          onPressed: onRenew,
                          icon: Icon(
                            telegram
                                ? LucideIcons.send
                                : LucideIcons.externalLink,
                            size: 18,
                          ),
                          label: Text(
                            telegram
                                ? l.subscriptionExpiredRenewTelegram
                                : l.subscriptionExpiredRenew,
                          ),
                          style: primary,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('subscription-expired-refresh'),
                          onPressed: refreshing ? null : onRefresh,
                          icon: refreshIcon(palette.mutedForeground),
                          label: Text(l.subscriptionExpiredRefresh),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: palette.card,
                            foregroundColor: palette.foreground,
                            side: BorderSide(color: palette.border),
                            minimumSize: const Size.fromHeight(48),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ] else
                        FilledButton.icon(
                          key: const ValueKey('subscription-expired-refresh'),
                          onPressed: refreshing ? null : onRefresh,
                          icon: refreshIcon(palette.runningForeground),
                          label: Text(l.subscriptionExpiredRefresh),
                          style: primary,
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 20),
                ConnectMonkeys(
                  covered: false,
                  haptic: false,
                  holdOnDrop: false,
                  showLabels: false,
                  labels: [l.monkeySee, l.monkeySpeak, l.monkeyHear],
                  labelColors: [
                    for (final m in ConnectionMode.values)
                      connectionModeStyle(context, m).strong,
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
