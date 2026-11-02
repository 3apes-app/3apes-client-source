import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/shared/widgets/adaptive_dialog.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/service/connect/settings.dart';

Future<T?> showConnectDialog<T>(BuildContext context, WidgetBuilder builder) =>
    showAppDialog<T>(context, builder);

Future<bool> showDestructiveConfirmationDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String warning,
  required String confirmLabel,
}) async =>
    await showAppDialog<bool>(context, (dialogContext) {
      final l = AppLocalizations.of(dialogContext)!;
      return AppDialog(
        title: title,
        subtitle: subtitle,
        expandLastAction: false,
        body: ConnectCallout(
          icon: LucideIcons.circleAlert,
          text: warning,
          warning: true,
        ),
        actions: [
          ConnectDialogButton(
            label: l.prototypeCancel,
            secondary: true,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          ConnectDialogButton(
            label: confirmLabel,
            icon: LucideIcons.trash2,
            destructive: true,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      );
    }) ??
    false;

Future<bool> showApplyAndReconnectDialog(
  BuildContext context, {
  required String label,
  String? title,
}) async {
  final l = AppLocalizations.of(context)!;
  return await showAppDialog<bool>(
        context,
        (dialogContext) => AppDialog(
          title: title ?? l.prototypeApplyChange,
          subtitle: l.prototypeReconnectNotice,
          body: ConnectCallout(
            icon: LucideIcons.refreshCw,
            text: l.prototypeWillUseName(label),
          ),
          actions: [
            ConnectDialogButton(
              label: l.prototypeCancel,
              secondary: true,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            ConnectDialogButton(
              label: l.prototypeApplyAndReconnect,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      ) ==
      true;
}

typedef ConnectDialog = AppDialog;

class ConnectDialogButton extends StatelessWidget {
  const ConnectDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.destructive = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool destructive;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy || icon != null) ...[
          if (busy) const ButtonProgressIndicator() else Icon(icon, size: 16),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    if (secondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: palette.borderStrong)),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: destructive ? AppTheme.destructiveButton(context) : null,
      child: child,
    );
  }
}

class ConnectCallout extends StatelessWidget {
  const ConnectCallout({
    super.key,
    required this.icon,
    required this.text,
    this.warning = false,
  });
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? palette.destructiveSurface : palette.muted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: icon == LucideIcons.lockKeyhole ? 17 : 21,
            color: warning ? palette.destructive : palette.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: AppTypography.dialogCallout.copyWith(
                color: warning ? palette.destructive : palette.mutedStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef ConnectTrafficChoice = ({TrafficMode mode, int? id, bool edit});
typedef ConnectCustomChoice = ({
  int id,
  String name,
  int? ruleCount,
  bool advanced,
});

Future<bool?> showCustomRoutingModeDialog(BuildContext context) =>
    showAppDialog<bool>(context, (dialogContext) {
      final l = AppLocalizations.of(dialogContext)!;
      return AppDialog(
        title: l.prototypeNewCustomRoute,
        onClose: () => Navigator.pop(dialogContext),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MethodOption(
                title: l.routingNormalConfiguration,
                description: l.prototypeCustomRoutingDescription,
                selected: false,
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              const SizedBox(height: 12),
              _MethodOption(
                title: l.routingAdvancedJson,
                description: l.routingAdvancedSummary,
                selected: false,
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
        ),
      );
    });

/// 3 APES: three mode buttons on the phone's main screen. A mode without
/// servers (Abroad without Russian-exit servers) is shown as "Soon".
class ConnectModeSelector extends StatelessWidget {
  const ConnectModeSelector({
    super.key,
    required this.current,
    required this.available,
    required this.busy,
    required this.onSelected,
  });
  final ConnectionMode current;
  final Set<ConnectionMode> available;
  final bool busy;
  final ValueChanged<ConnectionMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, mode) in visibleConnectionModes.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  key: ValueKey('connect-mode-${mode.name}'),
                  title: connectionModeTitle(l, mode),
                  mode: mode,
                  soon: !available.contains(mode),
                  selected: mode == current,
                  onPressed: busy || !available.contains(mode)
                      ? null
                      : () => onSelected(mode),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${connectionModeTagline(l, current)}. '
          '${connectionModeDescription(l, current)}',
          textAlign: TextAlign.center,
          style: AppTypography.metadata.copyWith(color: palette.mutedStrong),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.title,
    required this.mode,
    required this.soon,
    required this.selected,
    required this.onPressed,
  });
  final String title;
  final ConnectionMode mode;
  final bool soon, selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Semantics(
      button: true,
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          backgroundColor: selected ? palette.primary : null,
          foregroundColor: selected
              ? palette.primaryForeground
              : palette.foreground,
          disabledForegroundColor: selected
              ? palette.primaryForeground
              : palette.mutedForeground,
          side: BorderSide(color: selected ? palette.primary : palette.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTypography.control,
            ),
            if (soon)
              Text(
                unavailableModeLabel(l, mode),
                style: AppTypography.metadata.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String connectionModeTitle(AppLocalizations l, ConnectionMode mode) =>
    switch (mode) {
      ConnectionMode.home => l.modeHome,
      ConnectionMode.protect => l.modeProtect,
      ConnectionMode.abroad => l.modeAbroad,
    };

/// 3 APES: modes offered in the pickers; «За границей» stays hidden until
/// its release (see [AppBuild.abroadMode]).
List<ConnectionMode> get visibleConnectionModes => [
  for (final mode in ConnectionMode.values)
    if (mode != ConnectionMode.abroad || AppBuild.abroadMode != 'hidden') mode,
];

/// 3 APES: badge of a mode this subscription cannot use. «За границей» needs
/// servers in Russia: «Скоро» until the plan exists, then «Нет в вашем
/// тарифе» (`--dart-define=ABROAD_MODE=tariff`).
String unavailableModeLabel(AppLocalizations l, ConnectionMode mode) =>
    mode != ConnectionMode.abroad
    ? l.modeNotInSubscription
    : AppBuild.abroadMode == 'tariff'
    ? l.modeNotInTariff
    : l.securityCheckSoon;

/// 3 APES: one-line promise of the mode, shown above its description.
String connectionModeTagline(AppLocalizations l, ConnectionMode mode) =>
    switch (mode) {
      ConnectionMode.home => l.modeHomeTagline,
      ConnectionMode.protect => l.modeProtectTagline,
      ConnectionMode.abroad => l.modeAbroadTagline,
    };

String connectionModeDescription(AppLocalizations l, ConnectionMode mode) =>
    switch (mode) {
      ConnectionMode.home => l.modeHomeHint,
      ConnectionMode.protect => l.modeProtectHint,
      ConnectionMode.abroad => l.modeAbroadHint,
    };

/// 3 APES: mode colors of the new design — Home green, Protection blue,
/// Abroad coral (light theme; the dark theme «Мягкая ночь» uses them
/// mixed 95% into its background).
({Color surface, Color strong, IconData icon}) connectionModeStyle(
  BuildContext context,
  ConnectionMode mode,
) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (mode) {
    ConnectionMode.home => (
      surface: dark ? const Color(0xFF263431) : const Color(0xFFE4F4E7),
      strong: dark ? const Color(0xFF89C99C) : const Color(0xFF23784A),
      icon: LucideIcons.house,
    ),
    ConnectionMode.protect => (
      surface: dark ? const Color(0xFF2A313F) : const Color(0xFFE7EEFB),
      strong: dark ? const Color(0xFF96AFE3) : const Color(0xFF3A63B8),
      icon: LucideIcons.shield,
    ),
    ConnectionMode.abroad => (
      surface: dark ? const Color(0xFF392C2F) : const Color(0xFFFDE7E5),
      strong: dark ? const Color(0xFFE6938E) : const Color(0xFFB8403A),
      icon: LucideIcons.plane,
    ),
  };
}

/// 3 APES: rings and glows (main button, «Проверка», «Подписка закончилась»)
/// stay bright in the dark theme — the original pastels — while text and
/// surfaces use the muted «Мягкая ночь» colours. Light theme: [strong].
Color connectionModeGlow(BuildContext context, ConnectionMode mode) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return connectionModeStyle(context, mode).strong;
  }
  return switch (mode) {
    ConnectionMode.home => const Color(0xFF8FD3A3),
    ConnectionMode.protect => const Color(0xFF9DB7EE),
    ConnectionMode.abroad => const Color(0xFFF19A94),
  };
}

/// 3 APES: "Режим: Дома ▾" on the main screen opens this sheet.
Future<void> showConnectModeSheet(
  BuildContext context, {
  required ConnectionMode current,
  required Set<ConnectionMode> available,
  required ValueChanged<ConnectionMode> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ColorManager.palette(context).background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => ConnectModeSheet(
      current: current,
      available: available,
      onSelected: (mode) {
        Navigator.of(sheet).pop();
        onSelected(mode);
      },
    ),
  );
}

class ConnectModeSheet extends StatelessWidget {
  const ConnectModeSheet({
    super.key,
    required this.current,
    required this.available,
    required this.onSelected,
  });
  final ConnectionMode current;
  final Set<ConnectionMode> available;
  final ValueChanged<ConnectionMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.modeTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 16),
            for (final mode in visibleConnectionModes) ...[
              _ModeOption(
                key: ValueKey('connect-mode-sheet-${mode.name}'),
                mode: mode,
                selected: mode == current,
                soon: !available.contains(mode),
                onTap: available.contains(mode) ? () => onSelected(mode) : null,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    super.key,
    required this.mode,
    required this.selected,
    required this.soon,
    required this.onTap,
  });
  final ConnectionMode mode;
  final bool selected, soon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final style = connectionModeStyle(context, mode);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? style.strong : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Opacity(
            opacity: soon ? 0.7 : 1,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: style.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(style.icon, size: 22, color: style.strong),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectionModeTitle(l, mode),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          connectionModeTagline(l, mode),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: style.strong,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connectionModeDescription(l, mode),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selected)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: style.strong,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.check,
                        size: 16,
                        color: palette.background,
                      ),
                    )
                  else if (soon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: style.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        unavailableModeLabel(l, mode),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: style.strong,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectTrafficMethodDialog extends StatelessWidget {
  const ConnectTrafficMethodDialog({
    super.key,
    required this.current,
    required this.customRoutes,
  });
  final ConnectionSettings current;
  final List<ConnectCustomChoice> customRoutes;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    void choose(TrafficMode mode, int? id, {bool edit = false}) =>
        Navigator.of(context).pop((mode: mode, id: id, edit: edit));
    final mobile =
        MediaQuery.sizeOf(context).width < AppLayout.mobileBreakpoint;
    return ConnectDialog(
      title: l.prototypeChooseTrafficMethod,
      subtitle: l.prototypeTrafficMethodQuestion,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 20,
          18,
          mobile ? 14 : 20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MethodOption(
              title: l.prototypeSmartRoutingRecommended,
              description: l.prototypeSmartRoutingDescription,
              selected: current.trafficMode == TrafficMode.smart,
              onPressed: () => choose(TrafficMode.smart, null),
              onEdit: () => choose(TrafficMode.smart, null, edit: true),
            ),
            const SizedBox(height: 10),
            _MethodOption(
              title: l.prototypeAllViaVpn,
              description: l.prototypeAllViaVpnDescription,
              selected: current.trafficMode == TrafficMode.allVpn,
              onPressed: () => choose(TrafficMode.allVpn, null),
            ),
            const SizedBox(height: 19),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.prototypeCustomRouting,
                          style: AppTypography.dialogGroupTitle,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l.prototypeChooseNamedRoute,
                          style: AppTypography.dialogGroupMeta.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${customRoutes.length}/3',
                    textDirection: TextDirection.ltr,
                    style: AppTypography.dialogGroupMeta.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            for (final route in customRoutes) ...[
              const SizedBox(height: 10),
              _MethodOption(
                title: route.name,
                description: route.ruleCount == null
                    ? l.prototypeCannotReadCustomRoute
                    : [
                        if (route.advanced) l.routingAdvancedJson,
                        l.prototypeRuleCount(route.ruleCount!),
                      ].join(' · '),
                selected:
                    current.trafficMode == TrafficMode.custom &&
                    current.customId == route.id,
                onPressed: () => choose(TrafficMode.custom, route.id),
                onEdit: () => choose(TrafficMode.custom, route.id, edit: true),
              ),
            ],
            if (customRoutes.isEmpty || customRoutes.length >= 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
                child: Text(
                  customRoutes.isEmpty
                      ? l.prototypeNoCustomRoutes
                      : l.prototypeCustomRouteLimit,
                  style: AppTypography.dialogGroupMeta.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            if (customRoutes.length < 3) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => choose(TrafficMode.custom, null, edit: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  textStyle: AppTypography.dialogAddAction,
                  minimumSize: const Size.fromHeight(42),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: palette.borderStrong),
                  shape: AppDashedBorder(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadii.card),
                    ),
                  ),
                ),
                icon: const Icon(LucideIcons.plus, size: 17),
                label: Text(l.prototypeNewCustomRoute),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onPressed,
    this.onEdit,
  });
  final String title, description;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      decoration: BoxDecoration(
        color: selected ? palette.selectedSurface : palette.card,
        border: Border.all(
          color: selected
              ? Color.lerp(palette.border, palette.primary, 0.48)!
              : palette.border,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              selected: selected,
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: palette.foreground,
                  minimumSize: const Size(0, 80),
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 0, 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.selectedSurface,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        LucideIcons.shieldCheck,
                        size: 21,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.dialogOptionTitle),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: AppTypography.dialogOptionDescription
                                .copyWith(color: palette.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (onEdit != null) ...[
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: palette.primary,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTypography.dialogOptionEdit,
              ),
              child: Text(AppLocalizations.of(context)!.prototypeEdit),
            ),
            const SizedBox(width: 10),
          ],
          Icon(
            selected ? LucideIcons.circleCheck : LucideIcons.arrowRightDir,
            size: selected ? 21 : 18,
            color: selected ? palette.running : palette.foreground,
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class ConnectExplanation extends StatelessWidget {
  const ConnectExplanation({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: ColorManager.palette(context).primary),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTypography.dialogBody)),
    ],
  );
}
