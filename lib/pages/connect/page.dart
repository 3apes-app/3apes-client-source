import 'dart:async';

import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/service/connect/coordinator.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/shared/widgets/app_activity.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/connect/provider_announce.dart';
import 'package:onexray/pages/connect/subscription_expired.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/main/page_visibility.dart';
import 'package:onexray/pages/servers/subscription/new_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final controller = ConnectController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.initialize();
    });
  }

  @override
  void dispose() {
    unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: PageVisibility(
      onChanged: controller.setPageVisible,
      child: Scaffold(
        // 3 APES: on the phone the main screen draws its own "3 APES"
        // wordmark (new design); the app bar stays on wide screens.
        appBar: MediaQuery.sizeOf(context).width > 720
            ? PageAppBar(
                title: Text(AppLocalizations.of(context)!.prototypeConnect),
                actions: const [AppActivityIndicator()],
              )
            : null,
        body: SafeArea(
          child: BlocBuilder<ConnectController, ConnectPageState>(
            buildWhen: (previous, next) => !previous.sameContentAs(next),
            builder: (context, state) {
              final l = AppLocalizations.of(context)!;
              if (state.failed) {
                return Center(
                  child: FilledButton(
                    onPressed: () => controller.initialize(),
                    child: Text(l.prototypeRetry),
                  ),
                );
              }
              if (!state.ready) {
                return Center(
                  child: Semantics(
                    label: l.prototypePleaseWait,
                    child: const CircularProgressIndicator(),
                  ),
                );
              }
              final view = state.connectionView;
              // 3 APES: «Подписка закончилась» — phone, VPN off, nothing
              // pending, regular (not expert) mode.
              final expiredScreen =
                  MediaQuery.sizeOf(context).width <= 720 &&
                  state.servers.isNotEmpty &&
                  !state.expertView &&
                  !state.configuration.connection.expert &&
                  state.pendingChange == null &&
                  !view.canDisconnect &&
                  !view.busy;
              return SubscriptionExpiredGate(
                enabled: expiredScreen,
                showRenew: AppBuild.site,
                child: ConnectView(
                  view: state.connectionView,
                  trafficBuilder: (desktop) =>
                      BlocSelector<
                        ConnectController,
                        ConnectPageState,
                        ConnectionView
                      >(
                        selector: (state) => state.connectionView,
                        builder: (context, view) =>
                            TrafficReadout(view: view, desktop: desktop),
                      ),
                  hasServers: state.servers.isNotEmpty,
                  expert: state.expertView,
                  raws: state.raws,
                  pendingChange: state.pendingChange,
                  deletingRawIds: state.deletingRawIds,
                  activeRawId: state.configuration.connection.expert
                      ? state.configuration.connection.rawId
                      : null,
                  location: controller.selectionTitle(l),
                  runningPath: controller.runningRoute?.path,
                  locationDetail: controller.selectionDetail(l),
                  locationHealth: controller.selectionHealth(l),
                  method: controller.homeMethodTitle(l),
                  methodDetail: controller.methodDescription(l),
                  onConnection: () => controller.connectionAction(context),
                  onAddServers: () => controller.addServers(context),
                  onPasteLink: () => controller.addSubscription(
                    context,
                    NewSubscriptionStart.paste,
                  ),
                  onScanLink: AppPlatform.isMobile
                      ? () => controller.addSubscription(
                          context,
                          NewSubscriptionStart.scan,
                        )
                      : null,
                  onSecurityCheck: () => controller.openSecurityCheck(context),
                  onGetSubscription: AppBuild.site
                      ? () => controller.openSubscriptionBot(context)
                      : null,
                  onExpert: (value) => controller.toggleExpert(context, value),
                  onServer: () => controller.chooseServer(context),
                  onMethod: () => controller.chooseTrafficMethod(context),
                  mode: controller.mode,
                  availableModes: controller.availableModes,
                  onMode: (mode) => controller.setMode(context, mode),
                  onAlwaysOn: AppPlatform.isAndroid
                      ? () => controller.explainAlwaysOn(context)
                      : null,
                  onWhy: () => controller.showWhy(context),
                  onRawAdd: () => controller.editRaw(context),
                  onRawSelect: (row) => controller.selectRaw(context, row.id),
                  onRawActions: (row) =>
                      controller.showRawActions(context, row),
                  announcement: const ProviderAnnounceCard(),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
