import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/connect/monkeys.dart';
import 'package:onexray/pages/launch/splash/controller.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/shared/failure.dart';

/// 3 APES: launch screen. Continues the system splash (the covered monkeys
/// of the icon): the monkeys open one after another, the wordmark fades
/// in, and the app goes on once both the animation and the start-up are
/// done.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  /// The animation is short; start-up usually takes about as long.
  static Duration get minimum =>
      ConnectMonkeys.total + const Duration(milliseconds: 250);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _open = false;
  bool _played = false;
  String? _route;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _open = true);
      _timer = Timer(SplashPage.minimum, () {
        _played = true;
        _go();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go() {
    final route = _route;
    if (!mounted || !_played || route == null) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return BlocProvider(
      create: (_) => SplashController(),
      child: BlocConsumer<SplashController, SplashPageState>(
        listenWhen: (previous, current) =>
            previous.route != current.route && current.route != null,
        listener: (context, state) {
          _route = state.route;
          _go();
        },
        builder: (context, state) => Scaffold(
          body: Center(
            child: state.failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        appFailureMessage(
                          AppLocalizations.of(context)!,
                          state.error,
                        ),
                      ),
                      TextButton(
                        onPressed: context.read<SplashController>().retry,
                        child: Text(AppLocalizations.of(context)!.buttonRetry),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConnectMonkeys(
                        key: const ValueKey('splash-monkeys'),
                        covered: !_open,
                        holdOnDrop: false,
                        haptic: false,
                        height: 170,
                      ),
                      const SizedBox(height: 28),
                      AnimatedOpacity(
                        opacity: _open ? 1 : 0,
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            Text(
                              '3 APES',
                              style: AppTypography.setupBrand.copyWith(
                                color: palette.foreground,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width: 64,
                              height: 2,
                              decoration: BoxDecoration(
                                color: palette.running,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
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
}
