import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/pages/main/desktop_window.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';

/// Keeps the themed AppBar while forwarding clicks on controls that overlap
/// the native macOS titlebar. Empty titlebar space keeps native window gestures.
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
  }) : tabText = null;

  /// 3 APES: the root page of a bottom tab. On the phone the title is shown
  /// as in the design — capitals with letter spacing and a mint line, centred,
  /// without the line under the bar. Pushed copies of the page keep the plain
  /// title and the back button.
  PageAppBar.tab(String text, {super.key, this.actions, this.bottom})
    : title = Text(text),
      tabText = text,
      leading = null;

  final Widget title;
  final String? tabText;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  // Retain AppBar's theme-aware preferred size, including its optional tabs.
  @override
  Size get preferredSize => AppBar(bottom: bottom).preferredSize;

  @override
  Widget build(BuildContext context) {
    final insets = MacOSWindowInsets.maybeOf(context);
    final route = ModalRoute.of(context);
    final forwardClicks =
        insets != null &&
        insets.titlebarHeight > 0 &&
        MediaQuery.paddingOf(context).top == 0 &&
        TickerMode.valuesOf(context).enabled &&
        (route?.isCurrent ?? true);
    var effectiveLeading = leading;
    if (forwardClicks && effectiveLeading == null) {
      if (Scaffold.maybeOf(context)?.hasDrawer ?? false) {
        effectiveLeading = const DrawerButton();
      } else if (route?.impliesAppBarDismissal ?? false) {
        effectiveLeading = route!.fullscreenDialog
            ? const CloseButton()
            : const BackButton();
      }
    }
    final tabRoot =
        tabText != null &&
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint &&
        !(route?.impliesAppBarDismissal ?? false);
    return AppBar(
      title: tabRoot ? PageTabTitle(tabText!) : title,
      centerTitle: tabRoot ? true : null,
      shape: tabRoot ? const Border() : null,
      leading: forwardClicks && effectiveLeading != null
          ? _AnimatedToolbarPassthrough(child: effectiveLeading)
          : effectiveLeading,
      actions: forwardClicks
          ? actions
                ?.map((child) => _AnimatedToolbarPassthrough(child: child))
                .toList()
          : actions,
      bottom: bottom,
    );
  }
}

/// 3 APES: tab title of the new design — «СЕРВЕРЫ» with a 48×2 mint line.
class PageTabTitle extends StatelessWidget {
  const PageTabTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      // 3 APES: the line runs exactly under the word.
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppTypography.setupBrand.copyWith(
                color: palette.foreground,
                fontSize: 17,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              height: 2,
              // The last letter's spacing is trailing space: not underlined.
              margin: const EdgeInsetsDirectional.only(end: 4),
              decoration: BoxDecoration(
                color: palette.running,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route transitions transform the page without laying out its buttons again.
class _AnimatedToolbarPassthrough extends StatefulWidget {
  const _AnimatedToolbarPassthrough({required this.child});

  final Widget child;

  @override
  State<_AnimatedToolbarPassthrough> createState() =>
      _AnimatedToolbarPassthroughState();
}

class _AnimatedToolbarPassthroughState
    extends State<_AnimatedToolbarPassthrough> {
  final _passthrough = GlobalKey<MacosToolbarPassthroughState>();
  List<Animation<double>> _animations = [];
  bool _updateScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final animation in _animations) {
      animation.removeListener(_updateAfterFrame);
    }
    final route = ModalRoute.of(context);
    _animations = [?route?.animation, ?route?.secondaryAnimation];
    for (final animation in _animations) {
      animation.addListener(_updateAfterFrame);
    }
  }

  void _updateAfterFrame() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _passthrough.currentState?.requestUpdate();
    });
  }

  @override
  void dispose() {
    for (final animation in _animations) {
      animation.removeListener(_updateAfterFrame);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MacosToolbarPassthrough(key: _passthrough, child: widget.child);
}
