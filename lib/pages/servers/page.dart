import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/shared/widgets/app_activity.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/view.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/shared/widgets/responsive_content.dart';
import 'package:onexray/service/servers/country.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({super.key});
  @override
  State<ServersPage> createState() => _ServersPageState();
}

class _ServersPageState extends State<ServersPage> {
  final controller = ServersController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 3 APES: the phone servers tab lists countries.
      if (_countries(context)) controller.groupBy(ServerGrouping.location);
      controller.initialize();
    });
  }

  /// 3 APES: on the phone the bottom tab is «Подписки» (subscription
  /// cards); the same page pushed from the server row of the main screen
  /// lists Auto, favourites and countries.
  bool _countries(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint &&
      (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);

  @override
  void dispose() {
    scroll.dispose();
    unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocBuilder<ServersController, ServersPageState>(
      builder: (context, state) {
        final l = AppLocalizations.of(context)!;
        final mobileRoot =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        final empty = state.ready && !state.failed && state.servers.isEmpty;
        final countries = _countries(context);
        final page = Scaffold(
          appBar: countries
              ? PageAppBar(title: Text(l.prototypeServers))
              : mobileRoot
              ? PageAppBar.tab(
                  l.prototypeSubscriptions,
                  actions: [
                    IconButton(
                      color: ColorManager.palette(context).primary,
                      tooltip: l.subscriptionsAdd,
                      onPressed: () => controller.addServers(context),
                      icon: const Icon(LucideIcons.plus),
                    ),
                  ],
                )
              : PageAppBar(
                  title: Text(l.prototypeServers),
                  actions: [
                    if (!mobileRoot && !empty) ...[
                      OutlinedButton.icon(
                        onPressed: () => controller.openSources(context),
                        icon: AppActivityBuilder(
                          builder: (context, activity) => activity.downloading
                              ? const ButtonProgressIndicator()
                              : const Icon(LucideIcons.refreshCw),
                        ),
                        label: Text(l.prototypeUpdatesAndSources),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => controller.addServers(context),
                        icon: const Icon(LucideIcons.plus),
                        label: Text(l.prototypeAddServer),
                      ),
                    ] else if (mobileRoot)
                      IconButton(
                        color: ColorManager.palette(context).primary,
                        tooltip: l.prototypeAddServers,
                        onPressed: () => controller.addServers(context),
                        icon: const Icon(LucideIcons.plus),
                      ),
                  ],
                  bottom: mobileRoot || empty
                      ? null
                      : TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.page,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          tabs: [
                            Tab(text: l.prototypeBySubscription),
                            Tab(text: l.prototypeByNodeLocation),
                          ],
                          onTap: (index) =>
                              controller.groupBy(ServerGrouping.values[index]),
                        ),
                ),
          body: SafeArea(
            child: ServerLoadState(
              ready: controller.ready,
              failed: controller.failed,
              failure: state.failure,
              onRetry: controller.initialize,
              child: ResponsiveContent(
                desktopMaxWidth: AppLayout.standardMaxWidth,
                child: ServerBrowser(
                  controller: controller,
                  scroll: scroll,
                  countries: countries,
                  subscriptions: mobileRoot && !countries,
                ),
              ),
            ),
          ),
        );
        return mobileRoot
            ? page
            : DefaultTabController(
                length: 2,
                initialIndex: controller.grouping.index,
                child: page,
              );
      },
    ),
  );
}

/// 3 APES: "Избранное" and "Выбрать страну" from the phone servers tab.
class ServerListPage extends StatelessWidget {
  final ServerListParams params;
  const ServerListPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final controller = params.controller;
    return BlocProvider.value(
      value: controller,
      child: BlocBuilder<ServersController, ServersPageState>(
        builder: (context, _) {
          final l = AppLocalizations.of(context)!;
          final countries = params.kind == ServerListKind.countries;
          return Scaffold(
            appBar: PageAppBar(
              title: Text(
                countries ? l.serversChooseCountry : l.prototypeFavorites,
              ),
            ),
            body: SafeArea(
              child: ResponsiveContent(
                child: countries
                    ? ServerCountriesView(controller: controller)
                    : ServerFavoritesView(controller: controller),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ServerGroupPage extends StatelessWidget {
  final ServerGroupParams params;
  const ServerGroupPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final controller = params.controller;
    return BlocProvider.value(
      value: controller,
      child: BlocBuilder<ServersController, ServersPageState>(
        builder: (context, _) {
          final l = AppLocalizations.of(context)!;
          final group = controller
              .groups(l)
              .where((row) => row.id == params.groupId)
              .firstOrNull;
          // 3 APES: a country opened on the phone gets the new design.
          final country =
              group?.country != null &&
              MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
          final flag = ServerCountry.flag(group?.country);
          return Scaffold(
            appBar: PageAppBar(
              title: Text(
                group == null
                    ? l.prototypeServers
                    : country && flag.isNotEmpty
                    ? '$flag ${group.name}'
                    : group.name,
              ),
              actions: const [AppActivityIndicator(pinging: false)],
            ),
            body: SafeArea(
              child: ResponsiveContent(
                child: group == null
                    ? Center(child: Text(l.prototypeNoServersYet))
                    : country
                    ? ServerCountryServersView(
                        controller: controller,
                        group: group,
                      )
                    : ServerGroupView(
                        controller: controller,
                        group: group,
                        groupPage: true,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ServerLoadState extends StatelessWidget {
  final bool ready, failed;
  final Object? failure;
  final VoidCallback onRetry;
  final Widget child;
  const ServerLoadState({
    super.key,
    required this.ready,
    required this.failed,
    this.failure,
    required this.onRetry,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (failed) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(appFailureMessage(l, failure)),
              FilledButton(onPressed: onRetry, child: Text(l.prototypeRetry)),
            ],
          ),
        ),
      );
    }
    if (!ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return child;
  }
}
