import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/traffic_format.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/servers/subscription/user_info.dart';

/// 3 APES: «Подписки» of the new design — one card per subscription with
/// traffic, expiry, server count and a refresh button, then «Добавить
/// подписку». The «Подписки» bottom tab on the phone.
class SubscriptionCardsView extends StatelessWidget {
  const SubscriptionCardsView({
    super.key,
    required this.controller,
    required this.scroll,
  });

  final ServersController controller;
  final ScrollController scroll;

  /// The subscription of the running connection, if there is one.
  int? _activeSourceId() {
    final view = controller.connectionView;
    if (view.phase != ConnectionPhase.connected) return null;
    final id = view.runtime?.entries.firstOrNull?.id;
    if (id == null) return null;
    return controller.servers.where((row) => row.id == id).firstOrNull?.subId;
  }

  Future<void> _openActions(
    BuildContext context,
    SubscriptionData source,
  ) async {
    final action = await showSourceActionsMenu(
      context,
      name: source.name,
      count: controller.sourceCount(source.id),
    );
    if (action != null && context.mounted) {
      await controller.sourceAction(context, source, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final active = _activeSourceId();
    final groups = controller.groups(l, filter: false);
    final manual = groups
        .where((group) => group.id == 'subscription:0')
        .firstOrNull;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        for (final source in controller.sources) ...[
          _SubscriptionCard(
            key: ValueKey('subscription-card-${source.id}'),
            controller: controller,
            source: source,
            active: source.id == active,
            // Tap: the servers of this subscription; «⋯»: its actions.
            onTap: () {
              final group = groups
                  .where((group) => group.id == 'subscription:${source.id}')
                  .firstOrNull;
              if (group != null) {
                controller.browse(context, group, mobile: true);
              } else if (!controller.sourceBusy(source.id)) {
                _openActions(context, source);
              }
            },
            onMore: controller.sourceBusy(source.id)
                ? null
                : () => _openActions(context, source),
            onRefresh: controller.sourceBusy(source.id)
                ? null
                : () => controller.sourceAction(
                    context,
                    source,
                    SourceAction.update,
                  ),
          ),
          const SizedBox(height: 14),
        ],
        if (manual != null) ...[
          _ManualCard(
            name: manual.name,
            detail: l.prototypeServerCount(manual.rows.length),
            onTap: () => controller.browse(context, manual, mobile: true),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey('subscriptions-add'),
            onPressed: () => controller.addServers(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(l.subscriptionsAdd),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              foregroundColor: palette.runningText,
              side: BorderSide(color: palette.running, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          [l.monkeySee, l.monkeySpeak, l.monkeyHear].join(' · '),
          textAlign: TextAlign.center,
          style: AppTypography.settingsNote.copyWith(
            color: palette.mutedForeground,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    super.key,
    required this.controller,
    required this.source,
    required this.active,
    required this.onTap,
    required this.onMore,
    required this.onRefresh,
  });

  final ServersController controller;
  final SubscriptionData source;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final home = connectionModeStyle(context, ConnectionMode.home);
    final coral = connectionModeStyle(context, ConnectionMode.abroad);
    final busy = controller.sourceBusy(source.id);
    final error = controller.sourceErrors[source.id];
    final info = SubscriptionUserInfo.fromSubscription(source);
    final now = DateTime.now();

    String? traffic;
    var trafficBad = false;
    String? expiry;
    var expiryBad = false;
    if (info != null) {
      final remaining = info.remainingBytes;
      if (info.unlimited) {
        traffic = l.subscriptionsUnlimited;
      } else if (info.exhausted) {
        traffic = l.subscriptionsTrafficOut;
        trafficBad = true;
      } else if (remaining != null && info.totalBytes != null) {
        traffic = l.subscriptionsTrafficLeft(
          formatTrafficFor(l, remaining),
          formatTrafficFor(l, info.totalBytes!),
        );
      } else if (info.usedBytes != null) {
        traffic = l.subscriptionPackageUsedSummary(
          formatTrafficFor(l, info.usedBytes!),
        );
      } else {
        traffic = l.subscriptionPackageNotProvided;
      }
      final ends = info.expiresAt;
      if (info.expireTimestamp == 0) {
        expiry = l.subscriptionsNoEnd;
      } else if (ends == null) {
        expiry = l.subscriptionPackageNotProvided;
      } else if (info.isExpired(now)) {
        expiry = l.subscriptionsEnded;
        expiryBad = true;
      } else {
        expiry = l.subscriptionsDaysLeft(
          (ends.difference(now).inMilliseconds / Duration.millisecondsPerDay)
              .ceil(),
        );
      }
    }

    final material = MaterialLocalizations.of(context);
    final checked = source.timestamp.toLocal();
    final updated = DateUtils.isSameDay(checked, now)
        ? l.subscriptionsUpdatedToday(
            material.formatTimeOfDay(TimeOfDay.fromDateTime(checked)),
          )
        : l.subscriptionsUpdatedOn(material.formatMediumDate(checked));

    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: active ? palette.running : palette.border,
          width: active ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: home.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(LucideIcons.link, size: 20, color: home.strong),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(height: 2),
                          Text(
                            l.subscriptionsInUse,
                            style: AppTypography.settingsHint.copyWith(
                              color: palette.runningText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('subscription-more-${source.id}'),
                    tooltip: MaterialLocalizations.of(context)
                        .moreButtonTooltip,
                    onPressed: onMore,
                    color: palette.mutedForeground,
                    icon: const Icon(LucideIcons.ellipsis, size: 20),
                  ),
                  const SizedBox(width: 2),
                  SizedBox.square(
                    dimension: 42,
                    child: IconButton.filled(
                      key: ValueKey('subscription-refresh-${source.id}'),
                      tooltip: l.prototypeUpdate,
                      onPressed: onRefresh,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.running,
                        foregroundColor: palette.runningForeground,
                        disabledBackgroundColor: palette.running.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      icon: busy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.runningForeground,
                              ),
                            )
                          : const Icon(LucideIcons.refreshCw, size: 18),
                    ),
                  ),
                ],
              ),
              if (traffic != null && expiry != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Tile(
                          title: l.subscriptionsTraffic,
                          value: traffic,
                          color: trafficBad ? coral.strong : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Tile(
                          title: l.subscriptionPackageExpiry,
                          value: expiry,
                          color: expiryBad ? coral.strong : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${l.prototypeServerCount(controller.sourceCount(source.id))}'
                ' · $updated',
                style: AppTypography.settingsHint.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  style: AppTypography.settingsHint.copyWith(
                    color: palette.destructive,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.value, this.color});

  final String title;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.settingsHint.copyWith(
              color: palette.mutedForeground,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? palette.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualCard extends StatelessWidget {
  const _ManualCard({
    required this.name,
    required this.detail,
    required this.onTap,
  });

  final String name;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: AppTypography.settingsHint.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
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

/// 3 APES: the «Подписки» tab on the phone with no subscription yet — no
/// import options here, only «Подключиться», which goes to the main screen
/// («Нет подписки» with paste and QR).
class SubscriptionsEmptyView extends StatelessWidget {
  const SubscriptionsEmptyView({super.key, required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            minHeight: constraints.maxHeight - 48,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.running.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.globe,
                    size: 40,
                    color: palette.runningText,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  l.subscriptionsEmptyTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.connectStatusTitle.copyWith(
                    color: palette.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.subscriptionsEmptyHint,
                textAlign: TextAlign.center,
                style: AppTypography.connectStatusDetail.copyWith(
                  fontSize: 14,
                  color: palette.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('subscriptions-empty-connect'),
                    onPressed: onConnect,
                    icon: const Icon(LucideIcons.power, size: 18),
                    label: Text(l.subscriptionsEmptyConnect),
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: palette.running,
                      foregroundColor: palette.runningForeground,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
