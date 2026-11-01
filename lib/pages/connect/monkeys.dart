import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// 3 APES: the three monkeys on the main screen. Open (sitting, looking,
/// talking, listening) while the VPN is off; when it connects they cover
/// eyes, mouth and ears one after another, and open again on disconnect.
/// Frames: `assets/monkeys/<color>/<color>_00..23.webp` (from Grok videos,
/// see design/monkeys/README.md).
class ConnectMonkeys extends StatefulWidget {
  const ConnectMonkeys({
    super.key,
    required this.covered,
    this.height = 150,
    this.haptic = true,
    this.labels,
    this.labelColors,
    this.holdOnDrop = true,
    this.showLabels = true,
    this.stepFactor = step,
  });

  /// 3 APES: distance between the heads for this instance (see [step]).
  final double stepFactor;

  /// False while the VPN reconnects (mode, server, network): the words
  /// fade out and come back once it is connected again.
  final bool showLabels;

  /// The VPN dropped by itself or reconnects after a mode or server switch:
  /// keep the hands up for [uncoverDelay] and open only if it stays off.
  /// False when the user turned the VPN off: open right away.
  final bool holdOnDrop;

  /// Shown under each monkey (green, blue, red) once it has covered up:
  /// "see nothing", "tell nothing", "hear nothing".
  final List<String>? labels;
  final List<Color>? labelColors;

  static const labelHeight = 24.0;

  /// How long a reconnect may take before the monkeys open.
  static const uncoverDelay = Duration(milliseconds: 1500);

  /// Hands up: connecting or connected.
  final bool covered;
  final double height;
  final bool haptic;

  static const frames = 24;
  static const colors = ['green', 'blue', 'red'];

  /// Frame width / height and where the head is across the frame (0..1):
  /// the tails make the frames uneven, so the monkeys are placed by their
  /// heads, at equal steps.
  static const _aspect = {
    'green': 227 / 300,
    'blue': 212 / 300,
    'red': 231 / 300,
  };
  static const _head = {'green': 0.568, 'blue': 0.437, 'red': 0.460};

  /// Distance between the heads, in monkey heights.
  static const step = 0.72;

  /// Each monkey moves for [move]; the next one starts [stagger] later.
  static const move = Duration(milliseconds: 900);
  static const stagger = Duration(milliseconds: 250);
  static Duration get total => move + stagger * (colors.length - 1);

  static String frame(String color, int index) =>
      'assets/monkeys/$color/${color}_${index.toString().padLeft(2, '0')}.webp';

  /// 3 APES: the dark theme dims the monkeys a little (picked on the mockup
  /// 19.10): brightness 90%, saturation 97%. The light theme shows them as
  /// they are.
  static const darkBrightness = 0.9;
  static const darkSaturation = 0.97;

  /// Soft light under the monkeys in the dark theme, so they stand on the
  /// screen instead of floating: the text colour at 18%.
  static const darkGlow = 0.18;

  static List<double> _darkMatrix() {
    const b = darkBrightness, s = darkSaturation;
    const r = 0.2126, g = 0.7152, bl = 0.0722;
    return [
      b * (r * (1 - s) + s),
      b * g * (1 - s),
      b * bl * (1 - s),
      0,
      0,
      b * r * (1 - s),
      b * (g * (1 - s) + s),
      b * bl * (1 - s),
      0,
      0,
      b * r * (1 - s),
      b * g * (1 - s),
      b * (bl * (1 - s) + s),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Wraps a monkey picture: dimmed in the dark theme, unchanged in light.
  /// [key] is for an [AnimatedSwitcher] that switches the pictures.
  static Widget tone(BuildContext context, Widget child, {Key? key}) {
    if (Theme.of(context).brightness != Brightness.dark) return child;
    return ColorFiltered(
      key: key,
      colorFilter: ColorFilter.matrix(_darkMatrix()),
      child: child,
    );
  }

  @override
  State<ConnectMonkeys> createState() => _ConnectMonkeysState();
}

class _ConnectMonkeysState extends State<ConnectMonkeys>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ConnectMonkeys.total,
    value: widget.covered ? 1 : 0,
  );
  late final AnimationController _wordsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: widget.showLabels ? 1 : 0,
  );
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final color in ConnectMonkeys.colors) {
      for (var i = 0; i < ConnectMonkeys.frames; i++) {
        precacheImage(
          AssetImage(ConnectMonkeys.frame(color, i)),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  Timer? _uncover;

  @override
  void didUpdateWidget(ConnectMonkeys old) {
    super.didUpdateWidget(old);
    if (old.showLabels != widget.showLabels) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _wordsController.value = widget.showLabels ? 1 : 0;
      } else if (widget.showLabels) {
        _wordsController.forward();
      } else {
        _wordsController.reverse();
      }
    }
    if (old.covered == widget.covered) return;
    final instant = MediaQuery.disableAnimationsOf(context);
    if (widget.covered) {
      _uncover?.cancel();
      _uncover = null;
      if (_controller.value == 1 && !_controller.isAnimating) return;
      if (instant) {
        _controller.value = 1;
        return;
      }
      _controller.forward().whenComplete(() {
        if (mounted && widget.covered && widget.haptic) {
          HapticFeedback.mediumImpact();
        }
      });
    } else {
      _uncover?.cancel();
      if (!widget.holdOnDrop) {
        _uncover = null;
        if (instant) {
          _controller.value = 0;
        } else {
          _controller.reverse();
        }
        return;
      }
      _uncover = Timer(ConnectMonkeys.uncoverDelay, () {
        _uncover = null;
        if (!mounted || widget.covered) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _controller.value = 0;
        } else {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _uncover?.cancel();
    _wordsController.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _local(int monkey, double t) {
    final totalMs = ConnectMonkeys.total.inMilliseconds;
    final startMs = ConnectMonkeys.stagger.inMilliseconds * monkey;
    return ((t * totalMs - startMs) / ConnectMonkeys.move.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  int _index(int monkey, double t) =>
      (_local(monkey, t) * (ConnectMonkeys.frames - 1)).round();

  /// One size for all three words: the longest one decides, so the row
  /// stays even in every language.
  TextStyle _labelStyle(BuildContext context, List<String> labels, double max) {
    const base = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(context).style.merge(base),
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    if (widest <= max || widest == 0) return base;
    final k = max / widest;
    return base.copyWith(fontSize: 12 * k, letterSpacing: 1.4 * k);
  }

  // The word appears as the hands reach the face.
  double _labelOpacity(int monkey, double t) =>
      ((_local(monkey, t) - 0.65) / 0.35).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final hasLabels = labels != null && labels.length == 3;
    final labelSpace = hasLabels ? ConnectMonkeys.labelHeight : 0.0;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height + labelSpace,
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _wordsController]),
          builder: (context, _) {
            // Reverse plays the cascade backwards: the last monkey opens first.
            final t = _controller.value;
            final h = widget.height;
            final step = widget.stepFactor * h;
            final width = step * 2 + h * 0.9;
            final fallback = DefaultTextStyle.of(context).style.color;
            final labelWidth = step - 4;
            final labelStyle = hasLabels
                ? _labelStyle(context, labels, labelWidth)
                : null;
            final dark = Theme.of(context).brightness == Brightness.dark;
            final glowSize = h * 0.5;
            return SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (dark)
                    Positioned(
                      key: const ValueKey('monkeys-glow'),
                      bottom: labelSpace - glowSize * 0.3,
                      left: (width - glowSize) / 2,
                      width: glowSize,
                      height: glowSize,
                      child: Transform.scale(
                        scaleX: width * 1.05 / glowSize,
                        scaleY: 0.7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: ConnectMonkeys.darkGlow),
                                Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final (i, color) in ConnectMonkeys.colors.indexed)
                    Positioned(
                      bottom: labelSpace,
                      left:
                          width / 2 +
                          (i - 1) * step -
                          ConnectMonkeys._head[color]! *
                              ConnectMonkeys._aspect[color]! *
                              h,
                      child: ConnectMonkeys.tone(
                        context,
                        Image.asset(
                          ConnectMonkeys.frame(color, _index(i, t)),
                          key: ValueKey('monkey-$color'),
                          height: h,
                          width: ConnectMonkeys._aspect[color]! * h,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, _, _) => SizedBox(width: h * 0.75),
                        ),
                      ),
                    ),
                  if (hasLabels)
                    for (final (i, color) in ConnectMonkeys.colors.indexed)
                      Positioned(
                        bottom: 0,
                        left: width / 2 + (i - 1) * step - (step - 4) / 2,
                        width: labelWidth,
                        height: ConnectMonkeys.labelHeight,
                        child: Opacity(
                          key: ValueKey('monkey-label-$color'),
                          opacity: _labelOpacity(i, t) * _wordsController.value,
                          child: Center(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: labelStyle!.copyWith(
                                color:
                                    widget.labelColors?.elementAtOrNull(i) ??
                                    fallback,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
