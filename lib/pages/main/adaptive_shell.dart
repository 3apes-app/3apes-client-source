import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/main/desktop_window.dart';
import 'package:onexray/pages/main/menu_actions.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/service/settings/app_update/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/event_bus/state.dart';
import 'package:onexray/service/manager.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:onexray/service/shared/menu/short_cut/service.dart';
import 'package:onexray/service/shared/menu/tray/service.dart';
import 'package:onexray/service/shared/share/service.dart';

class AdaptiveMainShell extends StatefulWidget {
  const AdaptiveMainShell({
    super.key,
    required this.navigationShell,
    this.initializeServices,
  });

  final StatefulNavigationShell navigationShell;
  final Future<void> Function(BuildContext context)? initializeServices;

  @override
  State<AdaptiveMainShell> createState() => _AdaptiveMainShellState();
}

class _AdaptiveMainShellState extends State<AdaptiveMainShell> {
  Future<void>? _servicesReady;
  bool _menusAttached = false;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _servicesReady ??= _initializeServices();
    if (_menusAttached) _refreshQuickActions();
  }

  Future<void> _initializeServices() {
    ShareService().onIncomingShare = (text) async {
      if (mounted) {
        // 3 APES: a subscription link opens the simple «Новая подписка» on
        // the phone; anything else keeps the full import.
        final simple =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint &&
            ServerImportController.subscriptionLink(text) != null;
        await context.pushScoped(
          simple
              ? AppPageDestination.subscriptionNew
              : AppPageDestination.serversImport,
          extra: text,
        );
      }
    };
    return (widget.initializeServices ?? ServiceManager.serviceInit)(context);
  }

  void _refreshQuickActions() {
    unawaited(ShortCutService().refresh(AppLocalizations.of(context)!));
  }

  void _attachMenus() {
    if (_menusAttached) return;
    _menusAttached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TrayService().onConfigurationChange = (values, label, validate) =>
          applyTrayConfiguration(context, values, label, validate);
      ShortCutService().attach(
        (action) => handleMobileQuickAction(context, action),
      );
      _refreshQuickActions();
    });
  }

  @override
  void dispose() {
    ShortCutService().detach();
    TrayService().onConfigurationChange = null;
    super.dispose();
  }

  void _retry() {
    final servicesReady = _initializeServices();
    setState(() {
      _servicesReady = servicesReady;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _servicesReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      appFailureMessage(
                        AppLocalizations.of(context)!,
                        snapshot.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('service-initialization-retry'),
                      onPressed: _retry,
                      child: Text(AppLocalizations.of(context)!.buttonRetry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        _attachMenus();
        return BlocSelector<AppEventBus, AppEventBusState, AppUpdateInfo?>(
          selector: (state) => state.appUpdateInfo,
          builder: (context, appUpdateInfo) => LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > AppLayout.mobileBreakpoint) {
                return _railScaffold(
                  context,
                  constraints.maxWidth,
                  appUpdateInfo,
                );
              }
              return _bottomNavigationScaffold(context, appUpdateInfo != null);
            },
          ),
        );
      },
    );
  }

  Widget _bottomNavigationScaffold(
    BuildContext context,
    bool appUpdateAvailable,
  ) {
    // 3 APES: нижние вкладки нового дизайна — только на корне вкладки;
    // вложенные экраны открываются без панели.
    // The top page, including pages opened with push (they do not change
    // the reported URL).
    final delegate = GoRouter.of(context).routerDelegate;
    return ListenableBuilder(
      listenable: delegate,
      builder: (context, _) {
        final config = delegate.currentConfiguration;
        final path = config.isEmpty ? '' : config.last.matchedLocation;
        final onRoot = AppPrimaryDestination.values.any(
          (primary) => primary.rootPath == path,
        );
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: onRoot ? _mobileTabBar(context) : null,
        );
      },
    );
  }

  Widget _railScaffold(
    BuildContext context,
    double width,
    AppUpdateInfo? appUpdateInfo,
  ) {
    final compact = width <= AppLayout.compactDesktopBreakpoint;
    final sidebarWidth = !compact
        ? AppLayout.desktopSidebarWidth
        : AppLayout.compactSidebarWidth;
    final palette = ColorManager.palette(context);
    final nativeSidebar = DesktopWindowFrame.hasNativeSidebar(context);
    return Scaffold(
      backgroundColor: nativeSidebar ? Colors.transparent : null,
      body: Row(
        children: [
          Container(
            key: const ValueKey('primary-desktop-navigation'),
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: nativeSidebar ? Colors.transparent : palette.sidebar,
              border: BorderDirectional(
                end: BorderSide(color: palette.sidebarBorder),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sidebarHorizontal,
                  vertical: nativeSidebar
                      ? AppSpacing.macOSSidebarVertical
                      : AppSpacing.sidebarVertical,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        compact
                            ? AppSpacing.sidebarCompactBrandStart
                            : AppSpacing.sidebarBrandStart,
                        AppSpacing.sidebarBrandTop,
                        compact
                            ? AppSpacing.sidebarCompactBrandStart
                            : AppSpacing.sidebarBrandStart,
                        nativeSidebar
                            ? AppSpacing.macOSSidebarBrandBottom
                            : AppSpacing.sidebarBrandBottom,
                      ),
                      child: Text(
                        '3 APES',
                        style: AppTypography.desktopBrand.copyWith(
                          color: palette.brand,
                        ),
                      ),
                    ),
                    for (final primary in AppPrimaryDestination.values) ...[
                      if (primary.index > 0)
                        const SizedBox(height: AppSpacing.sidebarRowGap),
                      _desktopDestination(context, primary),
                    ],
                    const Spacer(),
                    if (appUpdateInfo != null)
                      _DesktopUpdateReminder(
                        onTap: () => _showDesktopUpdate(context, appUpdateInfo),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child:
                nativeSidebar && Directionality.of(context) == TextDirection.ltr
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: navigationShell,
                  )
                // In RTL the content, not the sidebar, is below the native
                // controls on the physical left. Keep its local top inset.
                : navigationShell,
          ),
        ],
      ),
    );
  }

  Widget _desktopDestination(
    BuildContext context,
    AppPrimaryDestination primary,
  ) {
    final palette = ColorManager.palette(context);
    final selected = primary.index == navigationShell.currentIndex;
    final label = _label(context, primary);
    final color = selected ? palette.primary : palette.mutedStrong;
    return Semantics(
      key: ValueKey('primary-navigation-${primary.name}'),
      label: label,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? palette.selectedSurface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: selected
                ? Color.lerp(palette.border, palette.primary, .2)!
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: () => context.goPrimary(navigationShell, primary),
          borderRadius: BorderRadius.circular(AppRadii.card),
          hoverColor: palette.surfaceHover,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.sidebarRowHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(_icon(primary), size: 22, color: color),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style:
                            (selected
                                    ? AppTypography.selectedNavigationLabel
                                    : AppTypography.navigationLabel)
                                .copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileTabBar(BuildContext context) {
    final palette = ColorManager.palette(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: DecoratedBox(
          key: const ValueKey('primary-mobile-navigation'),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.foreground.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                for (final primary in AppPrimaryDestination.values)
                  Expanded(child: _mobileTab(context, primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileTab(BuildContext context, AppPrimaryDestination primary) {
    final palette = ColorManager.palette(context);
    final selected = primary.index == navigationShell.currentIndex;
    final label = _mobileLabel(context, primary);
    final color = selected ? palette.primary : palette.mutedForeground;
    return Semantics(
      key: ValueKey('primary-navigation-${primary.name}'),
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => context.goPrimary(navigationShell, primary),
        borderRadius: BorderRadius.circular(20),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selected ? palette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(_mobileIcon(primary), size: 20, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDesktopUpdate(BuildContext context, AppUpdateInfo updateInfo) {
    context.pushAppUpdateDialog(updateInfo);
  }

  /// 3 APES: on the phone the second tab is «Подписки»; countries open
  /// from the server row of the main screen.
  IconData _mobileIcon(AppPrimaryDestination primary) =>
      primary == AppPrimaryDestination.servers
      ? LucideIcons.link
      : _icon(primary);

  String _mobileLabel(BuildContext context, AppPrimaryDestination primary) =>
      primary == AppPrimaryDestination.servers
      ? AppLocalizations.of(context)!.prototypeSubscriptions
      : _label(context, primary);

  IconData _icon(AppPrimaryDestination primary) {
    return switch (primary) {
      AppPrimaryDestination.connect => LucideIcons.power,
      AppPrimaryDestination.servers => LucideIcons.globe,
      AppPrimaryDestination.security => LucideIcons.shieldCheck,
      AppPrimaryDestination.settings => LucideIcons.settings,
    };
  }

  String _label(BuildContext context, AppPrimaryDestination primary) {
    final localizations = AppLocalizations.of(context)!;
    return switch (primary) {
      AppPrimaryDestination.connect => localizations.prototypeConnect,
      AppPrimaryDestination.servers => localizations.prototypeServers,
      AppPrimaryDestination.security => localizations.tabSecurity,
      AppPrimaryDestination.settings => localizations.prototypeSettings,
    };
  }
}

class _DesktopUpdateReminder extends StatelessWidget {
  const _DesktopUpdateReminder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.appUpdateAvailable;
    final palette = ColorManager.palette(context);
    return Tooltip(
      message: label,
      child: Material(
        color: palette.sidebarAccent,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.controlHorizontal,
              ),
              child: Row(
                children: [
                  const _UpdateBadge(
                    child: Icon(LucideIcons.download, size: 19),
                  ),
                  const SizedBox(width: AppSpacing.actionGap),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.desktopUpdateLabel.copyWith(
                        color: palette.sidebarAccentForeground,
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

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      smallSize: 8,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: child,
    );
  }
}
