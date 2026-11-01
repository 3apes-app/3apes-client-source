import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/pages/shared/connection_action.dart';
import 'package:onexray/pages/servers/catalog.dart';
import 'package:onexray/service/servers/catalog.dart';
import 'package:onexray/service/servers/country.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/service/connect/mode_servers.dart';
import 'package:onexray/service/connect/routing/custom/service.dart';
import 'package:onexray/service/connect/routing/custom/configuration.dart';

import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/shared/share/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/servers/sources.dart';
import 'package:onexray/pages/servers/subscription/params.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/shared/widgets/adaptive_dialog.dart';
import 'package:onexray/service/servers/server.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/servers/subscription/failure.dart';
import 'package:onexray/service/servers/subscription/model.dart';

export 'catalog.dart';

enum ServerAction { edit, test, copy, share, delete }

enum SourceAction { update, test, edit, share, delete }

/// 3 APES: the screens behind the phone servers tab.
enum ServerListKind { countries, favorites }

class ServerListParams {
  final ServersController controller;
  final ServerListKind kind;
  const ServerListParams(this.controller, this.kind);
}

class ServerGroupParams {
  final ServersController controller;
  final String groupId;
  const ServerGroupParams(this.controller, this.groupId);
}

const _unchanged = Object();

typedef PendingServerTest = ({String? groupId, bool cancelling});

class ServersPageState {
  ServersPageState({
    ConnectionConfiguration? configuration,
    this.connectionView = const ConnectionView(),
    ServerCatalog? catalog,
    List<RoutingConfiguration> customRoutes = const [],
    this.ready = false,
    this.failed = false,
    this.failure,
    this.serverGroupingIndex = 0,
    this.activeServerGroupId,
    this.serverSearchQuery = '',
    Set<String> pendingServerActions = const {},
    Map<Object, PendingServerTest> serverTests = const {},
    Set<int> favoritingServerIds = const {},
    this.selectingServers,
    Map<int, String> sourceErrors = const {},
  }) : configuration = configuration ?? ConnectionConfiguration(),
       catalog = catalog ?? ServerCatalog(),
       customRoutes = List.unmodifiable(customRoutes),
       pendingServerActions = Set.unmodifiable(pendingServerActions),
       serverTests = Map.unmodifiable(serverTests),
       favoritingServerIds = Set.unmodifiable(favoritingServerIds),
       sourceErrors = Map.unmodifiable(sourceErrors);

  final ConnectionConfiguration configuration;
  final ConnectionView connectionView;
  List<CoreConfigData> get servers => catalog.servers;
  List<SubscriptionData> get sources => catalog.sources;
  final ServerCatalog catalog;
  final List<RoutingConfiguration> customRoutes;
  final bool ready;
  final bool failed;
  final Object? failure;

  final int serverGroupingIndex;
  final String? activeServerGroupId;
  final String serverSearchQuery;
  final Set<String> pendingServerActions;
  final Map<Object, PendingServerTest> serverTests;
  final Set<int> favoritingServerIds;
  final ServerSelection? selectingServers;
  final Map<int, String> sourceErrors;

  ServersPageState copyWith({
    ConnectionConfiguration? configuration,
    ConnectionView? connectionView,
    ServerCatalog? catalog,
    List<RoutingConfiguration>? customRoutes,
    bool? ready,
    bool? failed,
    Object? failure,
    int? serverGroupingIndex,
    Object? activeServerGroupId = _unchanged,
    String? serverSearchQuery,
    Set<String>? pendingServerActions,
    Map<Object, PendingServerTest>? serverTests,
    Set<int>? favoritingServerIds,
    Object? selectingServers = _unchanged,
    Map<int, String>? sourceErrors,
  }) => ServersPageState(
    configuration: configuration ?? this.configuration,
    connectionView: connectionView ?? this.connectionView,
    catalog: catalog ?? this.catalog,
    customRoutes: customRoutes ?? this.customRoutes,
    ready: ready ?? this.ready,
    failed: failed ?? this.failed,
    failure: failed == false ? null : failure ?? this.failure,
    serverGroupingIndex: serverGroupingIndex ?? this.serverGroupingIndex,
    activeServerGroupId: identical(activeServerGroupId, _unchanged)
        ? this.activeServerGroupId
        : activeServerGroupId as String?,
    serverSearchQuery: serverSearchQuery ?? this.serverSearchQuery,
    pendingServerActions: pendingServerActions ?? this.pendingServerActions,
    serverTests: serverTests ?? this.serverTests,
    favoritingServerIds: favoritingServerIds ?? this.favoritingServerIds,
    selectingServers: identical(selectingServers, _unchanged)
        ? this.selectingServers
        : selectingServers as ServerSelection?,
    sourceErrors: sourceErrors ?? this.sourceErrors,
  );
}

class ServersController extends PageCubit<ServersPageState>
    with ServerLabels, ServerGroups {
  ServersController({
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
    ServerAssetService? assets,
    PingService? ping,
  }) : db = database ?? AppDatabase(),
       coordinator = coordinator ?? ConnectionCoordinator.instance,
       _ping = ping ?? PingService(),
       super(ServersPageState()) {
    this.assets =
        assets ??
        ServerAssetService(database: db, coordinator: this.coordinator);
    this.coordinator.state.addListener(_connectionChanged);
    _connectionChanged();
    search.addListener(_searchChanged);
  }
  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  @override
  ServerCatalog get catalog => state.catalog;
  @override
  String get query => state.serverSearchQuery;
  set servers(List<CoreConfigData> rows) =>
      emit(state.copyWith(catalog: catalog.copyWith(servers: rows)));
  set sources(List<SubscriptionData> rows) =>
      emit(state.copyWith(catalog: catalog.copyWith(sources: rows)));
  ConnectionConfiguration get configuration => state.configuration;
  set configuration(ConnectionConfiguration value) =>
      emit(state.copyWith(configuration: value));
  List<RoutingConfiguration> get customRoutes => state.customRoutes;
  set customRoutes(List<RoutingConfiguration> value) =>
      emit(state.copyWith(customRoutes: value));
  ConnectionView get connectionView => state.connectionView;
  bool get ready => state.ready;
  set ready(bool value) => emit(state.copyWith(ready: value));
  bool get failed => state.failed;

  void _connectionChanged() {
    final next = coordinator.state.value;
    if (next.phase != connectionView.phase ||
        next.runtime != connectionView.runtime) {
      emit(state.copyWith(connectionView: next));
    }
  }

  Future<void> initialize() async {
    emit(state.copyWith(failed: false));
    try {
      if (!isPageActive) return;
      configuration = await coordinator.configuration;
      if (_subscriptions.isEmpty) {
        _subscriptions.add(
          ServerCatalog.watch(db).listen(
            (value) => emit(state.copyWith(catalog: value)),
            onError: _readFailed,
          ),
        );
        _subscriptions.add(
          db.connectionConfigDao.watch().listen((row) {
            configuration = ConnectionConfiguration.fromJson(
              jsonDecode(row.configurationJson) as Map<String, dynamic>,
            );
          }, onError: _readFailed),
        );
        _subscriptions.add(
          db.routingProfileDao.allRowsStream.listen((rows) {
            try {
              customRoutes = rows
                  .map(CustomRoutingService.readConfiguration)
                  .toList();
            } catch (error) {
              _readFailed(error);
            }
          }, onError: _readFailed),
        );
      }
      ready = true;
    } catch (error) {
      _readFailed(error);
    }
  }

  void _readFailed(Object error) =>
      emit(state.copyWith(failed: true, failure: error));

  /// 3 APES: the phone opens the simple «Новая подписка»; the full import
  /// (servers, files, JSON) is in Advanced → App.
  /// 3 APES: «Подключиться» on the empty «Подписки» tab — back to the main
  /// screen, which shows «Нет подписки» with paste and QR.
  void openMain(BuildContext context) =>
      context.goPrimaryRoot(AppPrimaryDestination.connect);

  Future<void> addServers(BuildContext context) => context.pushScoped(
    MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
        ? AppPageDestination.subscriptionNew
        : AppPageDestination.serversImport,
  );
  Future<void> run(BuildContext context, Future<void> Function() action) async {
    await runConnectionAction(context, coordinator, action);
  }

  late final ServerAssetService assets;
  final PingService _ping;
  final search = TextEditingController();
  @override
  ServerGrouping get grouping =>
      ServerGrouping.values[state.serverGroupingIndex];
  set grouping(ServerGrouping value) =>
      emit(state.copyWith(serverGroupingIndex: value.index));
  String? get activeGroupId => state.activeServerGroupId;
  set activeGroupId(String? value) =>
      emit(state.copyWith(activeServerGroupId: value));
  Set<String> get _pending => state.pendingServerActions;
  Set<int> get favoritingIds => state.favoritingServerIds;
  ServerSelection? get selecting => state.selectingServers;
  set selecting(ServerSelection? value) =>
      emit(state.copyWith(selectingServers: value));
  Map<int, String> get sourceErrors => state.sourceErrors;

  void setSourceError(int id, String? error) {
    final next = {...sourceErrors};
    if (error == null) {
      next.remove(id);
    } else {
      next[id] = error;
    }
    emit(state.copyWith(sourceErrors: next));
  }

  bool get busy => selecting != null || connectionView.busy;
  bool serverBusy(CoreConfigData row) =>
      _pending.contains('server:${row.id}') ||
      _pending.contains('source:${row.subId}');
  bool sourceBusy(int id) =>
      _pending.contains('source:$id') ||
      servers.any(
        (row) => row.subId == id && _pending.contains('server:${row.id}'),
      );
  bool testingGroup(ServerGroup group) =>
      state.serverTests.values.any((test) => test.groupId == group.id);
  bool cancellingGroup(ServerGroup group) => state.serverTests.values
      .where((test) => test.groupId == group.id)
      .every((test) => test.cancelling);
  bool selectingGroup(ServerSelection value) =>
      selecting != null &&
      jsonEncode(selecting!.toJson()) == jsonEncode(value.toJson());

  void _searchChanged() => searchChanged(search.text);
  void searchChanged(String value) {
    if (value != state.serverSearchQuery) {
      emit(state.copyWith(serverSearchQuery: value));
    }
  }

  void groupBy(ServerGrouping value) {
    search.clear();
    emit(
      state.copyWith(
        serverGroupingIndex: value.index,
        activeServerGroupId: null,
      ),
    );
  }

  int entryCount(ServerSelection selection) {
    final connection = ConnectionSettings.fromJson({
      ...configuration.connection.toJson(),
      'expert': false,
      'selection': selection.toJson(),
    });
    int? customCount;
    if (connection.trafficMode == TrafficMode.custom) {
      final profile = customRoutes
          .where((profile) => profile.id == connection.customId)
          .firstOrNull;
      if (profile == null) return 0;
      customCount = profile.entryCount;
    }
    return connection.requiredEntries(customEntryCount: customCount);
  }

  bool canUse(ServerGroup group) {
    if (group.country == '') return false;
    final count = entryCount(group.selection);
    final finalExit = configuration.connection.trafficMode == TrafficMode.smart
        ? configuration.connection.smart.finalExitId
        : null;
    return count > 0 &&
        group.rows
                .where((row) => row.id != finalExit && catalog.selectable(row))
                .take(count)
                .length >=
            count;
  }

  bool selected(ServerSelection selection) =>
      !configuration.connection.expert &&
      jsonEncode(configuration.connection.selection.toJson()) ==
          jsonEncode(selection.toJson());

  // Display only: running identities come from the active runtime. Offline
  // previews use existing successful probes, never start a probe or select VPN.
  ({List<String> names, CoreConfigData? first}) get _displaySelection {
    final settings = configuration.connection;
    if (settings.expert) return (names: [], first: null);
    final view = connectionView;
    if (view.phase == ConnectionPhase.connected) {
      final runtime = view.runtime;
      if (runtime == null || runtime.configuration.connection.expert) {
        return (names: [], first: null);
      }
      final entries = runtime.entries;
      return (
        names: entries.map((entry) => entry.name).toList(),
        first: servers
            .where((row) => row.id == entries.firstOrNull?.id)
            .firstOrNull,
      );
    }
    final selection = settings.selection;
    final count = entryCount(selection);
    final rows =
        servers.where((row) {
          if (row.id == settings.finalExitId ||
              !ServerAssetService.healthy(row) ||
              !catalog.selectable(row)) {
            return false;
          }
          return switch (selection.kind) {
            SelectionKind.automatic => true,
            SelectionKind.region => ServerCountry.matches(
              row,
              selection.region,
            ),
            SelectionKind.source => row.subId == selection.id,
            SelectionKind.server => row.id == selection.id,
          };
        }).toList()..sort((a, b) {
          final delay = a.delay.compareTo(b.delay);
          return delay == 0 ? a.id.compareTo(b.id) : delay;
        });
    if (count <= 0 || rows.length < count) return (names: [], first: null);
    return (
      names: rows.take(count).map(serverName).toList(),
      first: rows.first,
    );
  }

  String? automaticResult(AppLocalizations l) {
    if (!selected(const ServerSelection.automatic())) return null;
    final display = _displaySelection;
    if (display.names.isEmpty) return null;
    final row = display.first;
    return l.prototypeCurrentServerLatency(
      display.names.first,
      row != null && ServerAssetService.healthy(row) ? row.delay : '—',
    );
  }

  /// 3 APES: "Сейчас: Индия · 518 мс" under Auto on the phone servers tab —
  /// the country instead of the provider's long server name.
  String? automaticCountryResult(AppLocalizations l) {
    if (!selected(const ServerSelection.automatic())) return null;
    final display = _displaySelection;
    final row = display.first;
    if (display.names.isEmpty || row == null) return null;
    final code = ServerCountry.of(row);
    return l.prototypeCurrentServerLatency(
      code == null ? display.names.first : countryName(l, code),
      ServerAssetService.healthy(row) ? row.delay : '—',
    );
  }

  /// 3 APES: the best successful delay of a group, for the country list.
  /// Whitelist servers are left out: the modes use them on their own.
  int? fastestDelay(ServerGroup group) {
    int? fastest;
    for (final row in group.rows) {
      if (!catalog.selectable(row) ||
          ModeServers.isMobile(row.name) ||
          !ServerAssetService.healthy(row)) {
        continue;
      }
      if (fastest == null || row.delay < fastest) fastest = row.delay;
    }
    return fastest;
  }

  /// 3 APES: every server of the group was tested and none answered.
  bool groupFailed(ServerGroup group) {
    final rows = group.rows.where(
      (row) => catalog.selectable(row) && !ModeServers.isMobile(row.name),
    );
    return rows.isNotEmpty &&
        rows.every(
          (row) =>
              row.delay != PingDelayConstants.unknown &&
              !PingDelayConstants.isSuccessful(row.delay),
        );
  }

  /// 3 APES: countries for "Выбрать страну" — working ones by name, then the
  /// ones that did not answer, then servers without a country. Countries that
  /// only have whitelist servers are hidden.
  List<ServerGroup> countryGroups(AppLocalizations l) {
    final result = groups(l)
        .where(
          (group) => group.rows.any((row) => !ModeServers.isMobile(row.name)),
        )
        .toList();
    int rank(ServerGroup group) => (group.country ?? '').isEmpty
        ? 2
        : groupFailed(group)
        ? 1
        : 0;
    result.sort((a, b) {
      final order = rank(a).compareTo(rank(b));
      return order != 0 ? order : a.name.compareTo(b.name);
    });
    return result;
  }

  Future<void> openList(BuildContext context, ServerListKind kind) async {
    search.clear();
    await context.pushScoped(
      AppPageDestination.serverList,
      extra: ServerListParams(this, kind),
    );
    if (isPageActive) search.clear();
  }

  ({String title, String detail})? currentSelectionSummary(AppLocalizations l) {
    final settings = configuration.connection;
    final selection = settings.selection;
    if (settings.expert || selection.kind == SelectionKind.automatic) {
      return null;
    }
    final display = _displaySelection;
    final row =
        display.first ??
        servers.where((row) => row.id == selection.id).firstOrNull;
    final title = switch (selection.kind) {
      SelectionKind.automatic => l.prototypeAutomaticSelection,
      SelectionKind.region => countryName(l, selection.region),
      SelectionKind.source =>
        selection.id == 0
            ? l.prototypeManualAdditions
            : sources
                      .where((source) => source.id == selection.id)
                      .firstOrNull
                      ?.name ??
                  l.prototypeTemporarilyUnavailable,
      SelectionKind.server =>
        display.names.firstOrNull ??
            (row == null ? l.prototypeTemporarilyUnavailable : serverName(row)),
    };
    return (
      title: title,
      detail: selection.kind == SelectionKind.server
          ? row == null
                ? ''
                : '${countryName(l, ServerCountry.of(row))} · ${sourceName(l, row)}'
          : '${l.prototypeAutomaticSelection}${display.names.isEmpty ? '' : ' · ${display.names.join(' + ')}'}',
    );
  }

  String? get currentGroupId {
    final selection = configuration.connection.selection;
    final first = _displaySelection.first;
    if (grouping == ServerGrouping.location) {
      final code = selection.kind == SelectionKind.region
          ? selection.region
          : first == null
          ? null
          : ServerCountry.of(first);
      return code == null ? null : 'location:${code.toUpperCase()}';
    }
    final id = selection.kind == SelectionKind.source
        ? selection.id
        : first?.subId;
    return id == null ? null : 'subscription:$id';
  }

  bool canChoose(CoreConfigData row) =>
      catalog.selectable(row) && !exitConflict(row);

  bool exitConflict(CoreConfigData row) =>
      configuration.connection.trafficMode == TrafficMode.smart &&
      configuration.connection.smart.finalExitId == row.id;

  bool chosen(CoreConfigData row) => selected(ServerSelection.server(row.id));

  void chooseRow(BuildContext context, CoreConfigData row) {
    if (!canChoose(row)) return;
    choose(context, ServerSelection.server(row.id));
  }

  Set<int> get runningEntries =>
      connectionView.phase == ConnectionPhase.connected
      ? {
          for (final entry
              in connectionView.runtime?.entries ?? const <RuntimeNode>[])
            entry.id,
        }
      : {};

  String summary(AppLocalizations l, ServerGroup group) {
    var available = 0;
    int? fastest;
    for (final row in group.rows) {
      if (!catalog.selectable(row)) continue;
      available++;
      if (ServerAssetService.healthy(row) &&
          (fastest == null || row.delay < fastest)) {
        fastest = row.delay;
      }
    }
    // 3 APES: no latency part until at least one server has answered.
    return fastest == null
        ? l.prototypeGroupAvailabilityNoLatency(available, group.rows.length)
        : l.prototypeGroupAvailability(available, group.rows.length, fastest);
  }

  String? sourceCheckedLabel(
    AppLocalizations l,
    DateTime timestamp, {
    DateTime? now,
  }) {
    final checked = timestamp.toLocal();
    final reference = (now ?? DateTime.now()).toLocal();
    final elapsed = reference.difference(checked);
    if (elapsed.isNegative || elapsed.inMinutes < 1) {
      return l.prototypeCheckedJustNow;
    }
    if (DateUtils.isSameDay(checked, reference)) {
      return l.prototypeCheckedToday;
    }
    return null;
  }

  Future<void> browse(
    BuildContext context,
    ServerGroup group, {
    required bool mobile,
  }) async {
    activeGroupId = group.id;
    if (mobile) {
      await context.pushScoped(
        AppPageDestination.serverGroup,
        extra: ServerGroupParams(this, group.id),
      );
    }
  }

  Future<void> choose(BuildContext context, ServerSelection selection) async {
    if (busy) return;
    selecting = selection;
    try {
      final saved = await applyConnectionChange(
        context,
        coordinator,
        {'selection': selection.toJson(), 'expert': false},
        label: (next) =>
            selectionName(AppLocalizations.of(context)!, next.selection),
        title: AppLocalizations.of(context)!.prototypeChangeServerQuestion,
      );
      if (saved != null) configuration = saved;
    } finally {
      selecting = null;
    }
  }

  Future<void> toggleFavorite(BuildContext context, CoreConfigData row) =>
      perform(context, () async {
        emit(state.copyWith(favoritingServerIds: {...favoritingIds, row.id}));
        try {
          await assets.favorite(row.id, !row.favorite);
        } finally {
          emit(
            state.copyWith(
              favoritingServerIds: {...favoritingIds}..remove(row.id),
            ),
          );
        }
      }, ids: {row.id});

  Future<void> test(
    BuildContext context,
    Iterable<CoreConfigData> rows, {
    String? groupId,
  }) async {
    final ids = rows.map((row) => row.id).toSet();
    if (ids.isEmpty) return;
    await run(context, () async {
      final request = Object();
      emit(
        state.copyWith(
          serverTests: {
            ...state.serverTests,
            request: (groupId: groupId, cancelling: false),
          },
        ),
      );
      try {
        await _ping.pingConfigIds(
          ids.toList(),
          force: true,
          isCancelled: () =>
              !isPageActive || (state.serverTests[request]?.cancelling ?? true),
        );
      } finally {
        emit(
          state.copyWith(serverTests: {...state.serverTests}..remove(request)),
        );
      }
    });
  }

  void cancelTest(String groupId) {
    emit(
      state.copyWith(
        serverTests: state.serverTests.map(
          (id, test) => MapEntry(
            id,
            test.groupId == groupId
                ? (groupId: groupId, cancelling: true)
                : test,
          ),
        ),
      ),
    );
  }

  Future<void> serverAction(
    BuildContext context,
    CoreConfigData row,
    ServerAction action,
  ) async {
    if (serverBusy(row)) return;
    final l = AppLocalizations.of(context)!;
    switch (action) {
      case ServerAction.edit:
        await context.pushScoped(
          AppPageDestination.serverEditor,
          extra: row.id,
        );
      case ServerAction.test:
        await test(context, [row]);
      case ServerAction.copy:
        await perform(context, () async {
          await assets.copyLocal(row, l.prototypeLocalCopy);
          if (context.mounted) {
            ContextAlert.showToast(context, l.prototypeLocalCopySaved);
          }
        }, ids: {row.id});
      case ServerAction.share:
        await shareAsset(context, SharePageParams(ShareType.config, row.id));
      case ServerAction.delete:
        await remove(context, serverName(row), ids: {row.id});
    }
  }

  Future<void> sourceAction(
    BuildContext context,
    SubscriptionData source,
    SourceAction action,
  ) async {
    if (sourceBusy(source.id)) return;
    switch (action) {
      case SourceAction.update:
        await perform(context, () async {
          final result = await SubscriptionService().refreshSubscriptionResult(
            source,
          );
          if (!context.mounted) return;
          if (result.superseded) return;
          final l = AppLocalizations.of(context)!;
          if (result.success) {
            setSourceError(source.id, null);
            ContextAlert.showToast(
              context,
              l.prototypeUsableNodes(result.count),
            );
          } else {
            final reason = subscriptionFailureMessage(
              l,
              result.status,
              error: result.error,
              updating: true,
            );
            setSourceError(source.id, reason);
            final navigator = Navigator.of(context);
            final closeSources = ModalRoute.of(context) is PopupRoute;
            final dialogContext = navigator.context;
            if (closeSources) navigator.pop();
            final offerHwid = SubscriptionService.offersHwidEnable(
              source,
              result.status,
            );
            final enable = await showAppDialog<bool>(
              dialogContext,
              (_) => SourceUpdateErrorDialog(
                sourceName: source.name,
                reason: reason,
                existingNodesKept:
                    result.status != SubscriptionUpdateResult.notFound,
                offerHwidEnable: offerHwid,
              ),
            );
            if (enable == true && dialogContext.mounted) {
              final retry = await SubscriptionService().enableHwidAndRefresh(
                source.id,
              );
              if (!dialogContext.mounted || retry.superseded) return;
              if (retry.success) {
                setSourceError(source.id, null);
                ContextAlert.showToast(
                  dialogContext,
                  l.prototypeUsableNodes(retry.count),
                );
              } else {
                final again = subscriptionFailureMessage(
                  l,
                  retry.status,
                  error: retry.error,
                  updating: true,
                );
                setSourceError(source.id, again);
                ContextAlert.showToast(dialogContext, again);
              }
            }
          }
        }, sourceId: source.id);
      case SourceAction.test:
        await test(
          context,
          servers.where((row) => row.subId == source.id),
          groupId: 'subscription:${source.id}',
        );
      case SourceAction.edit:
        await context.pushScoped(
          AppPageDestination.subscriptionEdit,
          extra: SubscriptionEditParams(id: source.id),
        );
      case SourceAction.share:
        await shareAsset(
          context,
          SharePageParams(ShareType.subscription, source.id),
        );
      case SourceAction.delete:
        await remove(context, source.name, sourceId: source.id);
    }
  }

  Future<void> shareAsset(BuildContext context, SharePageParams params) =>
      context.pushScoped(AppPageDestination.share, extra: params);

  Future<void> remove(
    BuildContext context,
    String name, {
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    await perform(
      context,
      () async {
        final preview = await assets.previewRemoval(
          ids: ids,
          sourceId: sourceId,
        );
        if (!context.mounted) return;
        final l = AppLocalizations.of(context)!;
        final reconnect = preview.affectsRuntime && !preview.disconnect;
        if (!await showDestructiveConfirmationDialog(
          context,
          title: sourceId == null
              ? l.prototypeDeleteServer
              : l.prototypeDeleteSource,
          subtitle: name,
          warning:
              '${sourceId == null ? l.prototypeDeletedServerSelectionNotice : l.prototypeSourceDeleteWarning(preview.ids.length)}'
              '${reconnect ? '\n\n${l.prototypeReconnectNotice}' : ''}',
          confirmLabel: preview.disconnect
              ? l.prototypeDeleteAndDisconnect
              : reconnect
              ? l.prototypeDeleteAndReconnect
              : l.prototypeDelete,
        )) {
          return;
        }
        await assets.remove(preview);
        if (context.mounted) {
          ContextAlert.showToast(context, l.prototypeNameRemoved(name));
        }
      },
      ids: ids,
      sourceId: sourceId,
    );
  }

  Future<void> openSources(BuildContext context) async {
    final source = await showAppDialog<SubscriptionData>(
      context,
      (_) => ServerSourcesDialog(controller: this),
      desktopMaxWidth: AppLayout.sourcesDialogWidth,
    );
    if (source == null || !context.mounted || !isPageActive) return;
    final action = await showSourceActionsMenu(
      context,
      name: source.name,
      count: sourceCount(source.id),
    );
    if (action != null && context.mounted && isPageActive) {
      await sourceAction(context, source, action);
    }
  }

  Future<void> openServerHelp(BuildContext context) async {
    final add = await showAppDialog<bool>(
      context,
      (_) => ServerHelpDialog(canScanQr: AppPlatform.isMobile),
    );
    if (add == true && context.mounted && isPageActive) {
      await addServers(context);
    }
  }

  Future<void> perform(
    BuildContext context,
    Future<void> Function() action, {
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    final keys = <String>{
      for (final id in ids) 'server:$id',
      if (sourceId != null) 'source:$sourceId',
    };
    if (keys.any(_pending.contains) ||
        (sourceId != null && sourceBusy(sourceId)) ||
        servers.any(
          (row) =>
              ids.contains(row.id) && _pending.contains('source:${row.subId}'),
        )) {
      return;
    }
    emit(state.copyWith(pendingServerActions: {..._pending, ...keys}));
    try {
      await run(context, action);
    } finally {
      emit(
        state.copyWith(pendingServerActions: {..._pending}..removeAll(keys)),
      );
    }
  }

  @override
  Future<void> disposePageResources() async {
    search.removeListener(_searchChanged);
    search.dispose();
    coordinator.state.removeListener(_connectionChanged);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
