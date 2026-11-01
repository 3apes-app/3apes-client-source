import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/pages/shared/connection_action.dart';
import 'package:onexray/service/connect/coordinator.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:onexray/core/tools/android_settings.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/security/model.dart';
import 'package:onexray/service/security/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 3 APES: the security check screen. Runs by itself on open; one button
/// at the bottom repeats it.
class SecurityCheckPage extends StatefulWidget {
  const SecurityCheckPage({super.key, this.service});

  final SecurityCheckService? service;

  @override
  State<SecurityCheckPage> createState() => _SecurityCheckPageState();
}

class _SecurityCheckPageState extends State<SecurityCheckPage>
    with WidgetsBindingObserver {
  late final SecurityCheckService _service =
      widget.service ?? SecurityCheckService();
  List<SecurityItem>? _items;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from system settings: check again without a tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _items != null) _run();
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    List<SecurityItem> items;
    try {
      items = await _service.run();
    } catch (_) {
      items = const [
        SecurityItem(SecurityCheckId.ip, SecurityVerdict.failed),
        SecurityItem(SecurityCheckId.ipv6, SecurityVerdict.failed),
      ];
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _running = false;
    });
  }

  /// 3 APES: the main fix for a visible IP — connect right here, then check
  /// again once the tunnel is up.
  Future<void> _connect() async {
    final coordinator = ConnectionCoordinator.instance;
    final done = await runConnectionAction(context, coordinator, () async {
      final view = coordinator.state.value;
      if (view.issue == 'permissionRequired' && view.permission != null) {
        await AppHostApi().requestPlatformPermission();
      }
      await coordinator.connect();
    });
    if (!done) return;
    for (var i = 0; i < 20; i++) {
      if (coordinator.state.value.phase == ConnectionPhase.connected) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) await _run();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = _items;
    return Scaffold(
      appBar: PageAppBar.tab(l.tabSecurity),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _Summary(
              running: _running,
              items: items,
              onRun: _run,
              onConnect: _connect,
            ),
            // 3 APES: what needs fixing comes first, right under the result.
            if (items != null && items.any((i) => i.isIssue)) ...[
              _Section(l.securityIssuesSection),
              _Group(items: items.where((i) => i.isIssue).toList()),
            ],
            if (items != null) ...[
              if (items.any((i) => !i.id.isDevice && !i.isIssue)) ...[
                _Section(l.securityNetworkSection),
                _Group(
                  items: items
                      .where((i) => !i.id.isDevice && !i.isIssue)
                      .toList(),
                ),
              ],
              if (items.any((i) => i.id.isDevice && !i.isIssue)) ...[
                _Section(l.securityDeviceSection),
                _Group(
                  items: items
                      .where((i) => i.id.isDevice && !i.isIssue)
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// 3 APES: white card of the new design — no border, soft shadow.
  static BoxDecoration card(BuildContext context) => BoxDecoration(
    color: ColorManager.palette(context).card,
    borderRadius: BorderRadius.circular(22),
    boxShadow: const [
      BoxShadow(color: Color(0x0F161B33), offset: Offset(0, 6), blurRadius: 22),
    ],
  );

  // 3 APES: status colors from the theme palette (light and dark).
  static Color colorOf(BuildContext context, SecurityLevel level) {
    final palette = ColorManager.palette(context);
    return switch (level) {
      SecurityLevel.ok => palette.runningText,
      SecurityLevel.warning => palette.chart3,
      SecurityLevel.danger => palette.destructive,
      SecurityLevel.info || SecurityLevel.unknown => palette.mutedForeground,
    };
  }

  static IconData iconOf(SecurityLevel level) => switch (level) {
    SecurityLevel.ok => LucideIcons.circleCheck,
    SecurityLevel.warning => LucideIcons.triangleAlert,
    SecurityLevel.danger => LucideIcons.circleAlert,
    SecurityLevel.info => LucideIcons.info,
    SecurityLevel.unknown => LucideIcons.circleHelp,
  };
}

/// 3 APES: the result ring with the green monkey ("не видим"): it covers its
/// eyes when everything is fine and looks around while there is something
/// to fix or the check is running.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.running,
    required this.items,
    required this.onRun,
    this.onConnect,
  });

  final bool running;
  final List<SecurityItem>? items;
  final VoidCallback onRun;
  final VoidCallback? onConnect;

  static const _open = 'assets/monkeys/green/green_00.webp';
  static const _closed = 'assets/monkeys/green/green_23.webp';
  // Same numbers as the main screen (monkeys.dart): frame width / height and
  // where the head is across the frame.
  static const _aspect = 227 / 300;
  static const _head = 0.568;
  static const _height = 100.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final list = items;
    final issues = list?.where((i) => i.isIssue).length ?? 0;
    final allFailed =
        list != null && list.every((i) => i.level == SecurityLevel.unknown);
    final checked =
        list
            ?.where(
              (i) =>
                  i.level == SecurityLevel.ok ||
                  i.level == SecurityLevel.warning ||
                  i.level == SecurityLevel.danger,
            )
            .length ??
        0;
    final okCount = list?.where((i) => i.level == SecurityLevel.ok).length ?? 0;
    final progress = running || checked == 0 ? 0.0 : okCount / checked;
    final String text;
    final Color color;
    String? detail;
    var good = false;
    if (running || list == null) {
      text = l.securityCheckRunning;
      color = ColorManager.secondaryText(context);
    } else if (allFailed) {
      text = l.securityCheckOffline;
      color = _SecurityCheckPageState.colorOf(context, SecurityLevel.unknown);
    } else if (issues == 0) {
      text = l.securityCheckAllGood;
      color = _SecurityCheckPageState.colorOf(context, SecurityLevel.ok);
      good = true;
    } else {
      // 3 APES: name the problem itself instead of a bare count.
      final found = list.where((i) => i.isIssue).toList();
      String name(SecurityItem item) => item.verdict == SecurityVerdict.ipDirect
          ? l.securityIpExposedShort
          : _Row(item: item)._title(l);
      if (found.length == 1 &&
          found.single.verdict == SecurityVerdict.ipDirect) {
        text = l.securityIpExposedHeadline;
        detail = l.securityIpExposedHint;
      } else if (found.length == 1) {
        text = _Row(item: found.single)._title(l);
        // The row right below explains it: no repeat here.
      } else {
        text = l.securityCheckIssues(issues);
        detail = found.map(name).join(' · ');
      }
      color = _SecurityCheckPageState.colorOf(context, SecurityLevel.warning);
    }
    final connectFix =
        !running &&
        onConnect != null &&
        (list?.any((i) => i.verdict == SecurityVerdict.ipDirect) ?? false);
    // Amber of the site palette: what is left to fix.
    final track = issues > 0 && !running
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFF2C66D)
              : const Color(0xFFF5B22A))
        : palette.border;
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox.square(
          dimension: 184,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The ring fills with every green check; the rest of it is
              // amber while something needs attention.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progress),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                  size: const Size.square(172),
                  painter: _RingPainter(
                    progress: value,
                    done: Theme.of(context).brightness == Brightness.dark
                        ? connectionModeGlow(context, ConnectionMode.home)
                        : palette.running,
                    rest: track,
                  ),
                ),
              ),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: palette.card,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F161B33),
                      offset: Offset(0, 6),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Center(
                    // The frames are wider than the monkey (the tail):
                    // move the image so the head is in the middle.
                    child: Transform.translate(
                      offset: const Offset(
                        -(_head - 0.5) * _height * _aspect,
                        4,
                      ),
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: ConnectMonkeys.tone(
                          context,
                          Image.asset(
                            good ? _closed : _open,
                            key: ValueKey(good),
                            height: _height,
                            errorBuilder: (_, _, _) => Icon(
                              LucideIcons.shieldCheck,
                              color: color,
                              size: 40,
                            ),
                          ),
                          key: ValueKey(good),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (running) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                text,
                key: const ValueKey('security-check-summary'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (detail != null && !running) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            key: const ValueKey('security-check-detail'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ColorManager.secondaryText(context),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (connectFix) ...[
          FilledButton.icon(
            key: const ValueKey('security-connect'),
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              // 3 APES: dark green with white in the light theme, mint with
              // dark text in the dark one.
              backgroundColor: palette.runningBadge,
              foregroundColor: palette.runningBadgeForeground,
              minimumSize: const Size(220, 50),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(LucideIcons.power, size: 18),
            label: Text(l.securityConnect),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('security-check-again'),
            onPressed: onRun,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text(l.securityCheckAgain),
          ),
        ] else
          FilledButton.icon(
            key: const ValueKey('security-check-again'),
            onPressed: running ? null : onRun,
            style: FilledButton.styleFrom(
              // 3 APES: dark green with white in the light theme, mint with
              // dark text in the dark one.
              backgroundColor: palette.runningBadge,
              foregroundColor: palette.runningBadgeForeground,
              minimumSize: const Size(220, 50),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: Text(l.securityCheckAgain),
          ),
      ],
    );
  }
}

/// 3 APES: the result ring — the rest colour all round, the green part on top.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.done,
    required this.rest,
  });

  final double progress;
  final Color done, rest;
  static const _width = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(_width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..color = rest;
    canvas.drawArc(circle, 0, 2 * math.pi, false, paint);
    if (progress <= 0) return;
    paint
      ..color = done
      ..strokeCap = progress >= 1 ? StrokeCap.butt : StrokeCap.round;
    canvas.drawArc(
      circle,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.done != done || old.rest != rest;
}

/// 3 APES: one card per section; what needs attention comes first.
class _Group extends StatelessWidget {
  const _Group({required this.items});

  final List<SecurityItem> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [
      ...items.where((i) => i.isIssue),
      ...items.where((i) => !i.isIssue),
    ];
    return Container(
      decoration: _SecurityCheckPageState.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, item) in sorted.indexed) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 50,
                color: ColorManager.palette(context).border,
              ),
            _Row(item: item),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(8, 24, 8, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: ColorManager.secondaryText(context),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final SecurityItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = _SecurityCheckPageState.colorOf(context, item.level);
    final value = _value(l);
    final action = item.verdict.action;
    return Container(
      key: ValueKey('security-row-${item.id.name}'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _SecurityCheckPageState.iconOf(item.level),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(l),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(_verdict(l), style: TextStyle(fontSize: 13, color: color)),
                if (value != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                ],
                // System screens open only on Android; iOS allows an app
                // to open its own settings page and nothing else.
                if (action != null && AppPlatform.isAndroid) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    key: ValueKey('security-action-${item.id.name}'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: color,
                    ),
                    onPressed: () => AndroidSettings.open(action.settings),
                    child: Text(l.protectAlwaysOnOpen),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l) => switch (item.id) {
    SecurityCheckId.ip => l.securityIpTitle,
    SecurityCheckId.ipv6 => l.securityIpv6Title,
    SecurityCheckId.dns => l.securityDnsTitle,
    SecurityCheckId.screenLock => l.securityLockTitle,
    SecurityCheckId.securityPatch => l.securityPatchTitle,
    SecurityCheckId.osVersion => l.securityOsTitle,
    SecurityCheckId.developer => l.securityDevTitle,
    SecurityCheckId.installers => l.securitySourcesTitle,
    SecurityCheckId.alwaysOn => l.protectAlwaysOnTitle,
  };

  String _verdict(AppLocalizations l) => switch (item.verdict) {
    SecurityVerdict.ipViaVpn => l.securityIpViaVpn,
    SecurityVerdict.ipDirect => l.securityIpDirect,
    SecurityVerdict.ipv6Off => l.securityIpv6Off,
    SecurityVerdict.ipv6ViaVpn => l.securityIpv6ViaVpn,
    SecurityVerdict.ipv6Leak => l.securityIpv6Leak,
    SecurityVerdict.ipv6Direct => l.securityIpv6Direct,
    SecurityVerdict.dnsViaVpn => l.securityDnsViaVpn,
    SecurityVerdict.dnsPrivate => l.securityDnsPrivate,
    SecurityVerdict.dnsProvider => l.securityDnsProvider,
    SecurityVerdict.dnsBypass => l.securityDnsBypass,
    SecurityVerdict.lockOn => l.securityLockOn,
    SecurityVerdict.lockOff => l.securityLockOff,
    SecurityVerdict.patchFresh => l.securityPatchFresh,
    SecurityVerdict.patchOld => l.securityPatchOld,
    SecurityVerdict.patchVeryOld => l.securityPatchVeryOld,
    SecurityVerdict.osCurrent => l.securityOsCurrent,
    SecurityVerdict.osPrevious => l.securityOsPrevious,
    SecurityVerdict.osOutdated => l.securityOsOutdated,
    SecurityVerdict.developerOff => l.securityDevOff,
    SecurityVerdict.developerOn => l.securityDevOn,
    SecurityVerdict.developerAdb => l.securityDevAdb,
    SecurityVerdict.installersStore => l.securitySourcesStore,
    SecurityVerdict.installersOther => l.securitySourcesOther,
    SecurityVerdict.alwaysOnFull => l.securityAlwaysOnFull,
    SecurityVerdict.alwaysOnNoBlock => l.securityAlwaysOnNoBlock,
    SecurityVerdict.alwaysOnOff => l.securityAlwaysOnOff,
    SecurityVerdict.failed => l.securityCheckFailed,
  };

  String? _value(AppLocalizations l) {
    final address = item.address;
    if (address == null) return null;
    final country = item.country;
    return country == null
        ? address
        : '$address · ${l.countryRegionName(country)}';
  }
}
