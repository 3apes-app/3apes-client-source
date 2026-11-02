import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/traffic_format.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/shared/widgets/responsive_content.dart';
import 'package:onexray/pages/shared/widgets/page_empty_state.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/failure.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectView extends StatelessWidget {
  const ConnectView({
    super.key,
    required this.view,
    this.trafficBuilder,
    required this.hasServers,
    required this.expert,
    required this.raws,
    required this.activeRawId,
    this.pendingChange,
    this.deletingRawIds = const {},
    required this.location,
    this.runningPath,
    this.locationDetail,
    this.locationHealth,
    required this.method,
    this.methodDetail,
    required this.onConnection,
    required this.onAddServers,
    required this.onExpert,
    required this.onServer,
    required this.onMethod,
    required this.onWhy,
    required this.onRawAdd,
    required this.onRawSelect,
    required this.onRawActions,
    this.announcement,
    this.mode,
    this.availableModes = const {},
    this.onMode,
    this.onAlwaysOn,
    this.onPasteLink,
    this.onScanLink,
    this.onGetSubscription,
    this.onSecurityCheck,
  });

  /// 3 APES: the security check card — on «Нет подписки» and on the main
  /// screen while the VPN is off. Works without a subscription.
  final VoidCallback? onSecurityCheck;

  /// 3 APES: «Нет подписки» on the phone. «Вставить ссылку» (falls back to
  /// [onAddServers]), «Сканировать QR-код» when the device has a camera, and
  /// «Получить в Telegram» only in the site build (not in the stores).
  final VoidCallback? onPasteLink, onScanLink, onGetSubscription;

  /// 3 APES: the mode buttons, phone only.
  final ConnectionMode? mode;
  final Set<ConnectionMode> availableModes;
  final ValueChanged<ConnectionMode>? onMode;

  /// 3 APES: shown under Protection, opens the always-on explanation.
  final VoidCallback? onAlwaysOn;
  final ConnectionView view;
  final Widget Function(bool desktop)? trafficBuilder;
  final bool hasServers;
  final bool expert;
  final List<CoreConfigData> raws;
  final int? activeRawId;
  final String? pendingChange;
  final Set<int> deletingRawIds;
  final String location;
  final String? runningPath;
  final String? locationDetail, locationHealth, methodDetail;
  final String method;
  final VoidCallback onConnection,
      onAddServers,
      onServer,
      onMethod,
      onWhy,
      onRawAdd;
  final ValueChanged<bool> onExpert;
  final ValueChanged<CoreConfigData> onRawSelect, onRawActions;

  /// 3 APES: provider announcement under the server row (phone layout).
  final Widget? announcement;

  bool get _connectionPending => pendingChange == 'connection';
  bool get _busy => view.busy || _connectionPending;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final empty =
        !hasServers &&
        !expert &&
        activeRawId == null &&
        !view.canDisconnect &&
        !_busy;
    if (empty) {
      // 3 APES: экран «Нет подписки» на телефоне, как в макете.
      if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
        return _noSubscription(context);
      }
      return ResponsiveContent(
        child: PageEmptyState(
          title: l.prototypeStartUsingOneXray,
          description: l.prototypeFirstConnectionHint,
          primaryLabel: l.prototypeAddServers,
          onPrimary: onAddServers,
          secondaryLabel: l.prototypeUseCompleteRawJson,
          onSecondary: () => onExpert(true),
        ),
      );
    }
    if (MediaQuery.sizeOf(context).width > AppLayout.mobileBreakpoint) {
      return _desktop(context);
    }
    return _phone(context);
  }

  /// 3 APES: main screen of the new design — wordmark, status, ring button,
  /// server and time, mode chip, and the three monkeys at the bottom.
  Widget _phone(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final connected = view.phase == ConnectionPhase.connected;
    final failed = view.failed && !connected;
    final connecting =
        view.phase == ConnectionPhase.preparing ||
        view.phase == ConnectionPhase.connecting;
    final phase = failed ? ConnectionPhase.failed : view.phase;
    final title = switch (phase) {
      ConnectionPhase.disconnected => l.prototypeDisconnected,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypeConnecting,
      ConnectionPhase.connected => l.prototypeConnected,
      ConnectionPhase.disconnecting => l.prototypeDisconnecting,
      ConnectionPhase.failed => l.prototypeConnectionFailed,
    };
    final startedAt = view.runtime?.startedAt;
    final elapsed = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMinutes;
    final detail = switch (phase) {
      ConnectionPhase.disconnected => l.prototypeReadyToProtectConnection,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypePreparingSecureConnection,
      ConnectionPhase.connected =>
        elapsed < 1
            ? l.prototypeJustConnected
            : elapsed < 60
            ? l.prototypeProtectedMinutes(elapsed)
            : l.prototypeProtectedHoursMinutes(elapsed ~/ 60, elapsed % 60),
      ConnectionPhase.disconnecting => l.prototypeFinishingConnection,
      ConnectionPhase.failed => connectionFailureMessage(
        l,
        issue: view.issue,
        error: view.error,
        permission: view.permission,
      ),
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 3 APES: the dark theme keeps the rings bright (connectionModeGlow).
    final blue = dark
        ? connectionModeGlow(context, ConnectionMode.protect)
        : connectionModeStyle(context, ConnectionMode.protect).strong;
    final mint = dark
        ? connectionModeGlow(context, ConnectionMode.home)
        : palette.running;
    final ({Color halo, Color band, Color icon, Color text}) ring = failed
        ? (
            halo: palette.destructive.withValues(alpha: 0.10),
            band: palette.destructive.withValues(alpha: 0.25),
            icon: palette.destructive,
            text: palette.destructive,
          )
        : connected
        ? (
            halo: mint.withValues(alpha: 0.22),
            band: mint.withValues(alpha: dark ? 0.75 : 0.55),
            icon: dark ? mint : palette.runningText,
            text: dark ? mint : palette.runningText,
          )
        : _busy
        ? (
            halo: blue.withValues(alpha: dark ? 0.14 : 0.10),
            band: blue.withValues(alpha: dark ? 0.4 : 0.25),
            icon: blue,
            text: blue,
          )
        : (
            halo: palette.foreground.withValues(alpha: 0.03),
            band: palette.border,
            icon: palette.foreground,
            text: palette.foreground,
          );
    final onPressed =
        view.phase == ConnectionPhase.disconnecting ||
            (pendingChange != null && !view.busy)
        ? null
        : onConnection;
    final current = mode;
    final modeStyle = current == null
        ? null
        : connectionModeStyle(context, current);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 APES: three sizes so the monkeys stay above the tab bar; small
        // phones (iPhone SE, compact Android) get the smallest one.
        final tiny = constraints.maxHeight < 640;
        final tight =
            tiny || (announcement != null && constraints.maxHeight < 820);
        final gap = tiny ? 8.0 : 14.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: tiny ? 10 : 22),
                  // 3 APES: the line runs exactly under the word.
                  IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '3 APES',
                          textAlign: TextAlign.center,
                          style: AppTypography.setupBrand.copyWith(
                            color: palette.foreground,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 2,
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          decoration: BoxDecoration(
                            color: palette.running,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_busy)
                        SizedBox.square(
                          dimension: 22,
                          child: MediaQuery.disableAnimationsOf(context)
                              ? Icon(
                                  LucideIcons.loaderCircle,
                                  color: ring.text,
                                  size: 22,
                                )
                              : CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: ring.text,
                                ),
                        )
                      else
                        Icon(
                          failed
                              ? LucideIcons.circleAlert
                              : connected
                              ? LucideIcons.shieldCheck
                              : LucideIcons.shield,
                          color: connected || failed
                              ? ring.text
                              : palette.mutedForeground,
                          size: 26,
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTypography.connectStatusTitle.copyWith(
                            color: ring.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tiny ? 10 : 18),
                  // 3 APES: on short screens with an announcement the ring
                  // shrinks so the monkeys stay above the tab bar.
                  SizedBox.square(
                    dimension: tiny ? 170 : (tight ? 210 : 268),
                    child: FittedBox(
                      child: Semantics(
                        button: true,
                        label: view.canDisconnect
                            ? l.prototypeDisconnect
                            : l.prototypeConnect,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 268,
                          height: 268,
                          decoration: BoxDecoration(
                            color: ring.halo,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 222,
                            height: 222,
                            decoration: BoxDecoration(
                              color: ring.band,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: SizedBox.square(
                              dimension: 176,
                              child: ElevatedButton(
                                key: const ValueKey('connect-round-button'),
                                onPressed: onPressed,
                                style: ElevatedButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                  elevation: 8,
                                  // 3 APES: a light glow on the dark theme looks
                                  // like a halo; a plain shadow there instead.
                                  shadowColor: dark
                                      ? Colors.black.withValues(alpha: 0.5)
                                      : ring.icon.withValues(alpha: 0.35),
                                  backgroundColor: palette.card,
                                  disabledBackgroundColor: palette.card,
                                  foregroundColor: ring.icon,
                                  disabledForegroundColor: ring.icon.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                child: const Icon(LucideIcons.power, size: 64),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  // 3 APES: the server choice is a visible button — tinted,
                  // framed and with an arrow — not plain text.
                  OutlinedButton(
                    key: const ValueKey('connect-location'),
                    onPressed: expert ? null : onServer,
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Color.alphaBlend(
                        palette.primary.withValues(alpha: .08),
                        palette.card,
                      ),
                      foregroundColor: palette.foreground,
                      side: BorderSide(
                        color: palette.primary.withValues(alpha: .55),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.globe,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            location,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!expert) ...[
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 18,
                            color: palette.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: AppTypography.connectStatusDetail.copyWith(
                      fontSize: 14,
                      color: failed
                          ? palette.destructive
                          : palette.mutedForeground,
                    ),
                  ),
                  if (view.issue == 'modeReset')
                    _notice(context, l.modeResetNotice),
                  if (view.issue == 'selectionReset')
                    _notice(
                      context,
                      l.prototypeNameActive(l.prototypeAutomaticSelection),
                    ),
                  if (view.failed && !failed)
                    _notice(
                      context,
                      l.prototypeCheckNetwork,
                      color: palette.destructive,
                    ),
                  if (!expert &&
                      current != null &&
                      modeStyle != null &&
                      onMode != null) ...[
                    SizedBox(height: gap),
                    OutlinedButton(
                      key: const ValueKey('connect-mode-chip'),
                      onPressed: pendingChange == 'mode' || _busy
                          ? null
                          : () => showConnectModeSheet(
                              context,
                              current: current,
                              available: availableModes,
                              onSelected: onMode!,
                            ),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: palette.card,
                        foregroundColor: palette.foreground,
                        side: BorderSide(color: palette.border),
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            modeStyle.icon,
                            size: 18,
                            color: modeStyle.strong,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${l.modeTitle}: ${connectionModeTitle(l, current)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 18,
                            color: palette.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                    if (current == ConnectionMode.protect && onAlwaysOn != null)
                      TextButton.icon(
                        onPressed: onAlwaysOn,
                        icon: const Icon(LucideIcons.lockKeyhole, size: 16),
                        label: Text(l.protectAlwaysOnAction),
                      ),
                  ],
                  if (expert) ...[
                    SizedBox(height: gap),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: _raws(context),
                      ),
                    ),
                  ],
                  if (announcement != null) ...[
                    SizedBox(height: gap),
                    announcement!,
                  ],
                  const Spacer(),
                  SizedBox(height: tiny ? 10 : 20),
                  ConnectMonkeys(
                    height: tiny ? 90 : (tight ? 112 : 150),
                    covered: connected || connecting,
                    // The user's own tap opens them at once; a reconnect
                    // (mode, server, network) waits to see if it is quick.
                    holdOnDrop: pendingChange != 'connection',
                    // No words while it reconnects; they return when connected.
                    showLabels: connected,
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
        );
      },
    );
  }

  Widget _notice(BuildContext context, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.metadata.copyWith(
            color: color ?? ColorManager.palette(context).mutedForeground,
          ),
        ),
      ),
    );
  }

  /// 3 APES: «Проверьте безопасность устройства» — a light card, so the
  /// main action above stays the main one. [free] adds «без подписки».
  Widget _securityCard(BuildContext context, {required bool free}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('connect-security-check'),
          onTap: onSecurityCheck,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.running.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.shieldCheck,
                      size: 20,
                      color: palette.runningText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.securityPromoTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        free ? l.securityPromoHintFree : l.securityPromoHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.connectStatusDetail.copyWith(
                          fontSize: 13,
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronRightDir,
                  size: 20,
                  color: palette.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3 APES: first launch / «Нет подписки» of the new design — wordmark,
  /// the three monkeys, «Добавьте подписку» and the ways to add one.
  Widget _noSubscription(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final pill = OutlinedButton.styleFrom(
      shape: const StadiumBorder(),
      backgroundColor: palette.card,
      foregroundColor: palette.foreground,
      side: BorderSide(color: palette.border),
      minimumSize: const Size.fromHeight(50),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
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
                // 3 APES: the line runs exactly under the word.
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '3 APES',
                        textAlign: TextAlign.center,
                        style: AppTypography.setupBrand.copyWith(
                          color: palette.foreground,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 2,
                        margin: const EdgeInsetsDirectional.only(end: 6),
                        decoration: BoxDecoration(
                          color: palette.running,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 20),
                ConnectMonkeys(
                  key: const ValueKey('no-subscription-monkeys'),
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
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    l.noSubscriptionLead,
                    textAlign: TextAlign.center,
                    style: AppTypography.connectStatusTitle.copyWith(
                      color: palette.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  onScanLink == null
                      ? l.noSubscriptionHint
                      : l.noSubscriptionLeadHint,
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
                      FilledButton.icon(
                        key: const ValueKey('no-subscription-paste'),
                        onPressed: onPasteLink ?? onAddServers,
                        icon: const Icon(LucideIcons.clipboard, size: 18),
                        label: Text(l.noSubscriptionPasteLink),
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
                      if (onScanLink != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('no-subscription-scan'),
                          onPressed: onScanLink,
                          icon: const Icon(LucideIcons.qrCode, size: 18),
                          label: Text(l.prototypeScanQrCode),
                          style: pill,
                        ),
                      ],
                      if (onGetSubscription != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('no-subscription-telegram'),
                          onPressed: onGetSubscription,
                          icon: const Icon(LucideIcons.send, size: 18),
                          label: Text(l.noSubscriptionTelegram),
                          style: pill,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onSecurityCheck != null) ...[
                  const SizedBox(height: 26),
                  _securityCard(context, free: true),
                ],
                const Spacer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktop(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width <= AppLayout.compactDesktopBreakpoint;
    final connected = view.phase == ConnectionPhase.connected;
    final main = Card(
      key: const ValueKey('desktop-connection-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _status(context, desktop: true),
          _expertSwitch(context, desktop: true),
          if (expert)
            _raws(context, desktop: true)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 29),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _desktopChoice(
                    context,
                    LucideIcons.earth,
                    l.prototypeServers,
                    location,
                    onServer,
                    detail: locationDetail ?? runningPath,
                    meta: connected ? locationHealth : null,
                  ),
                  const SizedBox(height: 25),
                  _desktopChoice(
                    context,
                    LucideIcons.shieldCheck,
                    l.prototypeTrafficMethod,
                    method,
                    onMethod,
                    detail: methodDetail,
                    busy: pendingChange == 'method',
                  ),
                  const SizedBox(height: 25),
                  _why(context, desktop: true),
                ],
              ),
            ),
        ],
      ),
    );
    final traffic = Card(
      key: const ValueKey('desktop-traffic-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l.prototypeTraffic,
                      style: AppTypography.connectDesktopTrafficTitle,
                    ),
                  ),
                ],
              ),
            ),
            trafficBuilder?.call(true) ??
                TrafficReadout(view: view, desktop: true),
          ],
        ),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.desktopPageTop,
        AppSpacing.page,
        AppSpacing.desktopPageBottom,
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 660),
                  child: main,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 560),
                  child: traffic,
                ),
              ],
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (viewport.height -
                            AppLayout.connectDesktopPanelViewportInset)
                        .clamp(0.0, double.infinity),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 104, child: main),
                    const SizedBox(width: 16),
                    Expanded(flex: 100, child: traffic),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _desktopChoice(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    VoidCallback onTap, {
    String? detail,
    String? meta,
    bool busy = false,
  }) {
    final palette = ColorManager.palette(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: Text(
            label,
            style: AppTypography.connectDesktopChoiceLabel.copyWith(
              color: palette.mutedStrong,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            onTap: _busy ? null : onTap,
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppLayout.connectDesktopChoiceMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (busy)
                      const ButtonProgressIndicator()
                    else
                      Icon(
                        icon,
                        size: 23,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? palette.foreground
                            : palette.scannerBackground,
                      ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.connectDesktopChoiceTitle,
                          ),
                          if (detail != null && detail.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectDesktopChoiceDetail
                                  .copyWith(color: palette.mutedForeground),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    if (meta != null) ...[
                      Text(
                        meta,
                        style: AppTypography.connectDesktopChoiceMeta.copyWith(
                          color: palette.running,
                        ),
                      ),
                      const SizedBox(width: 13),
                    ],
                    const Icon(LucideIcons.chevronRightDir, size: 19),
                    if (meta == null) const SizedBox(width: 13),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _expertSwitch(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: desktop
            ? AppLayout.connectDesktopExpertRowMinHeight
            : AppLayout.connectExpertRowMinHeight,
      ),
      padding: EdgeInsets.symmetric(horizontal: desktop ? 18 : 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l.prototypeExpertMode,
                    style: desktop
                        ? AppTypography.connectDesktopCaption
                        : AppTypography.connectCaption,
                  ),
                ),
                const SizedBox(width: 7),
                ExcludeSemantics(
                  child: Icon(
                    LucideIcons.info,
                    size: 15,
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (pendingChange == 'expert') ...[
            const ButtonProgressIndicator(),
            const SizedBox(width: 8),
          ],
          Semantics(
            label: l.prototypeExpertMode,
            child: ShadSwitch(
              value: expert,
              enabled: !_busy && pendingChange == null,
              onChanged: onExpert,
            ),
          ),
        ],
      ),
    );
  }

  Widget _why(BuildContext context, {bool desktop = false}) {
    final palette = ColorManager.palette(context);
    final action = InkWell(
      onTap: onWhy,
      borderRadius: desktop ? BorderRadius.circular(AppRadii.small) : null,
      child: Container(
        constraints: BoxConstraints(minHeight: desktop ? 53 : 49),
        padding: desktop ? const EdgeInsets.symmetric(horizontal: 14) : null,
        child: Row(
          children: [
            Icon(LucideIcons.circleHelp, size: 20, color: palette.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.prototypeWhyThisConnection,
                style:
                    (desktop
                            ? AppTypography.connectDesktopWhy
                            : AppTypography.connectWhy)
                        .copyWith(color: palette.primary),
              ),
            ),
            Icon(LucideIcons.chevronRightDir, size: 19, color: palette.primary),
          ],
        ),
      ),
    );
    if (!desktop) return action;
    return Material(
      color: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
        side: BorderSide(color: palette.border),
      ),
      child: action,
    );
  }

  Widget _status(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final connected = view.phase == ConnectionPhase.connected;
    final canDisconnect = view.canDisconnect;
    final failed = view.failed && !connected;
    final presentationPhase = failed ? ConnectionPhase.failed : view.phase;
    final title = switch (presentationPhase) {
      ConnectionPhase.disconnected => l.prototypeDisconnected,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypeConnecting,
      ConnectionPhase.connected => l.prototypeConnected,
      ConnectionPhase.disconnecting => l.prototypeDisconnecting,
      ConnectionPhase.failed => l.prototypeConnectionFailed,
    };
    final startedAt = view.runtime?.startedAt.millisecondsSinceEpoch;
    final elapsed = startedAt == null
        ? 0
        : DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(startedAt))
              .inMinutes;
    final detail = switch (presentationPhase) {
      ConnectionPhase.disconnected => l.prototypeReadyToProtectConnection,
      ConnectionPhase.preparing ||
      ConnectionPhase.connecting => l.prototypePreparingSecureConnection,
      ConnectionPhase.connected =>
        elapsed < 1
            ? l.prototypeJustConnected
            : elapsed < 60
            ? l.prototypeProtectedMinutes(elapsed)
            : l.prototypeProtectedHoursMinutes(elapsed ~/ 60, elapsed % 60),
      ConnectionPhase.disconnecting => l.prototypeFinishingConnection,
      ConnectionPhase.failed => connectionFailureMessage(
        l,
        issue: view.issue,
        error: view.error,
        permission: view.permission,
      ),
    };
    final palette = ColorManager.palette(context);
    final color = failed
        ? palette.destructive
        : connected
        ? palette.running
        : _busy
        ? palette.primary
        : palette.mutedStrong;
    final waitingForPhase = _connectionPending && !view.busy;
    final button = FilledButton(
      onPressed:
          view.phase == ConnectionPhase.disconnecting ||
              (pendingChange != null && !view.busy)
          ? null
          : onConnection,
      style: desktop
          ? AppTheme.connectionButton(
              context,
              destructive: canDisconnect,
            ).copyWith(
              minimumSize: const WidgetStatePropertyAll(
                Size(
                  AppLayout.connectDesktopButtonWidth,
                  AppLayout.connectDesktopButtonMinHeight,
                ),
              ),
              textStyle: WidgetStatePropertyAll(
                AppTypography.connectDesktopAction,
              ),
            )
          : AppTheme.connectionButton(context, destructive: canDisconnect),
      child: ButtonProgress(
        busy: desktop && _busy,
        child: Text(
          waitingForPhase
              ? l.prototypePleaseWait
              : canDisconnect
              ? l.prototypeDisconnect
              : view.phase == ConnectionPhase.disconnecting
              ? l.prototypePleaseWait
              : view.busy
              ? l.prototypeCancel
              : failed
              ? l.prototypeTryAgain
              : l.prototypeConnect,
        ),
      ),
    );
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: desktop
            ? AppLayout.connectDesktopStatusMinHeight
            : AppLayout.connectStatusMinHeight,
      ),
      child: Padding(
        padding: desktop
            ? const EdgeInsets.fromLTRB(20, 66, 20, 39)
            : const EdgeInsets.fromLTRB(15, 25, 15, 17),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  SizedBox.square(
                    dimension: desktop ? 29 : 24,
                    child: MediaQuery.disableAnimationsOf(context)
                        ? Icon(
                            LucideIcons.loaderCircle,
                            color: color,
                            size: desktop ? 29 : 24,
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                  )
                else if (connected)
                  Container(
                    width: desktop ? 29 : 24,
                    height: desktop ? 29 : 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: desktop ? 19 : 14,
                      color: palette.primaryForeground,
                    ),
                  )
                else
                  Icon(
                    failed ? LucideIcons.circleAlert : LucideIcons.shield,
                    color: color,
                    size: desktop ? 29 : 24,
                  ),
                SizedBox(width: desktop ? 12 : 10),
                Flexible(
                  child: Text(
                    title,
                    style:
                        (desktop
                                ? AppTypography.connectDesktopStatusTitle
                                : AppTypography.connectStatusTitle)
                            .copyWith(color: color),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: desktop ? 16 : 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style:
                  (desktop
                          ? AppTypography.connectDesktopStatusDetail
                          : AppTypography.connectStatusDetail)
                      .copyWith(color: palette.mutedStrong),
            ),
            if (view.issue == 'modeReset')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l.modeResetNotice,
                    textAlign: TextAlign.center,
                    style: AppTypography.metadata,
                  ),
                ),
              ),
            if (view.issue == 'selectionReset')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l.prototypeNameActive(l.prototypeAutomaticSelection),
                    textAlign: TextAlign.center,
                    style: AppTypography.metadata,
                  ),
                ),
              ),
            if (view.failed && !failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.prototypeCheckNetwork,
                  style: AppTypography.supporting.copyWith(
                    color: palette.destructive,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: desktop ? 30 : 18),
            if (desktop)
              Align(
                child: SizedBox(
                  width: AppLayout.connectDesktopButtonWidth,
                  child: button,
                ),
              )
            else
              // 3 APES: большая круглая кнопка подключения на телефоне.
              Center(
                child: Semantics(
                  button: true,
                  label: canDisconnect
                      ? l.prototypeDisconnect
                      : l.prototypeConnect,
                  child: SizedBox.square(
                    dimension: 176,
                    child: ElevatedButton(
                      key: const ValueKey('connect-round-button'),
                      onPressed: button.onPressed,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        backgroundColor: canDisconnect
                            ? ColorManager.palette(context).running
                            : ColorManager.palette(context).card,
                        foregroundColor: canDisconnect
                            ? ColorManager.palette(context).runningForeground
                            : ColorManager.palette(context).foreground,
                        side: BorderSide(
                          color: canDisconnect
                              ? ColorManager.palette(context).runningSurface
                              : ColorManager.palette(context).borderStrong,
                          width: canDisconnect ? 8 : 2,
                        ),
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 48,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(LucideIcons.power, size: 60),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!desktop) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: content,
    );
  }

  Widget _raws(BuildContext context, {bool desktop = false}) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(18, 0, 18, 14)
          : const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: desktop ? 52 : 47),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Raw JSON',
                    style: desktop
                        ? AppTypography.connectDesktopRawTitle
                        : AppTypography.connectRawTitle,
                  ),
                ),
                Text(
                  '${raws.length} / 3',
                  textDirection: TextDirection.ltr,
                  style: AppTypography.connectRawCount.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (view.phase == ConnectionPhase.connected && activeRawId == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.prototypeOrdinaryConnectionRunning,
                style: AppTypography.supporting.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ),
          if (raws.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              shape: AppDashedBorder(
                side: BorderSide(color: palette.borderStrong),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: desktop
                      ? AppLayout.connectDesktopRawEmptyMinHeight
                      : 160,
                ),
                child: Padding(
                  padding: EdgeInsets.all(desktop ? 24 : 19),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: desktop
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.filePlus,
                        size: desktop ? 32 : 27,
                        color: palette.mutedStrong,
                      ),
                      const SizedBox(height: 11),
                      Text(
                        l.prototypeNoRawJson,
                        textAlign: TextAlign.center,
                        style: desktop
                            ? AppTypography.connectDesktopRawEmptyTitle
                            : AppTypography.connectRawEmptyTitle,
                      ),
                      const SizedBox(height: 9),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: desktop ? 330 : 270,
                        ),
                        child: Text(
                          l.prototypeAddRawJsonHint,
                          textAlign: TextAlign.center,
                          style:
                              (desktop
                                      ? AppTypography
                                            .connectDesktopRawEmptyDetail
                                      : AppTypography.connectRawEmptyDetail)
                                  .copyWith(color: palette.mutedForeground),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: onRawAdd,
                        icon: const Icon(LucideIcons.plus, size: 17),
                        label: Text(l.prototypeAddRawJson),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (raws.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final row in raws) ...[
                    if (row != raws.first) const Divider(),
                    _rawRow(context, row, desktop: desktop),
                  ],
                ],
              ),
            ),
          if (raws.isNotEmpty && raws.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 11),
              child: OutlinedButton.icon(
                onPressed: onRawAdd,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  shape: AppDashedBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(l.prototypeAddRawJson),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.prototypeRawRuntimeOverrideNotice,
                  style: AppTypography.connectRawNotice.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rawRow(
    BuildContext context,
    CoreConfigData row, {
    bool desktop = false,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final active = activeRawId == row.id;
    return ColoredBox(
      color: active
          ? Color.lerp(palette.card, palette.selectedSurface, .6)!
          : palette.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 66 : 62),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap:
                    _busy ||
                        pendingChange != null ||
                        deletingRawIds.contains(row.id)
                    ? null
                    : () => onRawSelect(row),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 13 : 11,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      if (pendingChange == 'raw:${row.id}')
                        const ButtonProgressIndicator()
                      else
                        Icon(
                          LucideIcons.fileJson,
                          size: 21,
                          color: palette.primary,
                        ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectRawRowTitle,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              active
                                  ? l.prototypeActiveConfiguration
                                  : l.prototypeCompleteXrayConfiguration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.connectRawRowDetail.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 11),
                      Icon(
                        active ? LucideIcons.check : LucideIcons.circle,
                        size: active ? 19 : 18,
                        color: active
                            ? palette.primary
                            : palette.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: desktop ? 46 : 42,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(color: palette.border),
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: '${l.prototypeMoreActions}: ${row.name}',
                    onPressed: deletingRawIds.contains(row.id)
                        ? null
                        : () => onRawActions(row),
                    icon: deletingRawIds.contains(row.id)
                        ? const ButtonProgressIndicator()
                        : const Icon(LucideIcons.ellipsis, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrafficReadout extends StatelessWidget {
  const TrafficReadout({super.key, required this.view, this.desktop = false});
  final ConnectionView view;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final live =
        view.phase == ConnectionPhase.connected && view.metricsAvailable;
    final traffic = view.traffic;
    return Column(
      children: [
        _group(
          context,
          l.prototypeCurrentSpeed,
          live
              ? '${formatTraffic(view.downloadSpeed, connection: true)}/s'
              : '—',
          live ? '${formatTraffic(view.uploadSpeed, connection: true)}/s' : '—',
        ),
        _group(
          context,
          l.prototypeThisConnection,
          formatTraffic(traffic?.downlink ?? 0, connection: true),
          formatTraffic(traffic?.uplink ?? 0, connection: true),
          divider: false,
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    String download,
    String upload, {
    bool divider = true,
  }) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: desktop
            ? AppLayout.connectDesktopTrafficGroupMinHeight
            : AppLayout.connectTrafficGroupMinHeight,
      ),
      padding: EdgeInsets.symmetric(vertical: desktop ? 22 : 10.5),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style:
                (desktop
                        ? AppTypography.connectDesktopTrafficGroupTitle
                        : AppTypography.connectTrafficGroupTitle)
                    .copyWith(color: palette.mutedStrong),
          ),
          SizedBox(height: desktop ? 24 : 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _metric(
                    context,
                    LucideIcons.arrowDown,
                    l.prototypeDownload,
                    download,
                    palette.primary,
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: palette.border),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 1),
                      child: _metric(
                        context,
                        LucideIcons.arrowUp,
                        l.prototypeUpload,
                        upload,
                        palette.running,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) => Semantics(
    label: '$label $value',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.controlHorizontal,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: desktop ? 24 : 19, color: color),
              const SizedBox(width: AppSpacing.actionRunGap),
              Expanded(
                child: Text(
                  label,
                  style:
                      (desktop
                              ? AppTypography.connectDesktopTrafficLabel
                              : AppTypography.connectTrafficLabel)
                          .copyWith(
                            color: ColorManager.palette(context).mutedStrong,
                          ),
                ),
              ),
            ],
          ),
          SizedBox(height: desktop ? 10 : 5),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: desktop
                ? AppTypography.metric
                : AppTypography.connectTrafficValue,
          ),
        ],
      ),
    ),
  );
}
