import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/advanced_mode.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/main/router.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:onexray/service/shared/menu/short_cut/service.dart';
import 'package:onexray/service/shared/menu/window/service.dart';
import 'package:onexray/service/shared/share/service.dart';

const _desktopWindowSize = Size(1160, 720);
const _minimumDesktopWindowSize = Size(480, 600);

Future<void> main(List<String> _) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockPhonePortrait();
  await AdvancedMode.load();

  await ShortCutService().initialize();
  ShareService().startAppLinks();
  await _initBridge();
  final appStartup = AppStartupService();
  await appStartup.prepare();

  if (AppPlatform.isDesktop) {
    await WindowService().prepare(
      size: _desktopWindowSize,
      minimumSize: _minimumDesktopWindowSize,
    );
  }

  runApp(GoRouteApp());
  // Hidden windows may not render frames. Keep visibility independent from
  // first-frame callbacks and preserve the existing hidden-start policy.
  await appStartup.onWindowReady();
}

Future<void> _initBridge() async {
  BridgeFlutterApi.setUp(AppFlutterApi());
  await AppHostApi().initTunFilesDir();
}

/// 3 APES: phones stay upright; tablets keep rotating (wide layout).
/// iPhone is also locked in Info.plist; this covers Android phones, where
/// the manifest cannot tell a phone from a tablet.
Future<void> _lockPhonePortrait() async {
  if (!AppPlatform.isMobile) return;
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return;
  final view = views.first;
  final size = view.physicalSize / view.devicePixelRatio;
  if (size.shortestSide >= 600) return;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}
