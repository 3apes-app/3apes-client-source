import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/controller.dart';
import 'package:onexray/pages/advanced/tab_visibility.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/page.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/settings/page.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';

class AdvancedPage extends StatelessWidget {
  final WidgetBuilder? xrayBuilder;
  final OpenTunnelPage? openTunnel;
  const AdvancedPage({super.key, this.xrayBuilder, this.openTunnel});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return BlocProvider(
      create: (_) => AdvancedController(),
      child: DefaultTabController(
        length: mobile ? 3 : 2,
        child: Scaffold(
          appBar: PageAppBar(
            title: Text(l.prototypeAdvanced),
            bottom: TabBar(
              isScrollable: !mobile,
              tabAlignment: mobile ? TabAlignment.fill : TabAlignment.start,
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? AppSpacing.mobilePage : AppSpacing.page,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                Tab(text: l.prototypeVpnTunnel),
                Tab(text: l.prototypeXrayRuntimeDiagnostics),
                if (mobile) Tab(text: l.advancedAppTab),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                _AdvancedWarning(text: l.advancedWarning, mobile: mobile),
                Expanded(
                  child: TabBarView(
                    children: [
                      VpnTunnelPane(openTunnel: openTunnel),
                      Builder(builder: xrayBuilder ?? _runtimeSummary),
                      if (mobile) const AppSettingsPane(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _runtimeSummary(BuildContext context) =>
      BlocBuilder<AdvancedController, AdvancedPageState>(
        builder: (context, state) {
          final l = AppLocalizations.of(context)!;
          final controller = context.read<AdvancedController>();
          return AdvancedTabVisibility(
            tabIndex: 1,
            onChanged: controller.setVisible,
            child: SettingsPageScroll(
              child: SettingSection(
                title: l.prototypeRuntimeStatus,
                children: [
                  SettingRow(
                    title: l.prototypeXrayCore,
                    value: controller.statusLabel(l),
                    leading: const Icon(LucideIcons.activity),
                  ),
                  PolicyValueRow(
                    title: l.prototypeVersion,
                    value: state.xrayVersion,
                  ),
                  PolicyValueRow(title: l.prototypeUptime, value: state.uptime),
                ],
              ),
            ),
          );
        },
      );
}

class _AdvancedWarning extends StatelessWidget {
  const _AdvancedWarning({required this.text, required this.mobile});

  final String text;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final side = mobile ? AppSpacing.mobilePage : AppSpacing.page;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(side, 12, side, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorManager.palette(context).warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.triangleAlert,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: ColorManager.primaryText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
