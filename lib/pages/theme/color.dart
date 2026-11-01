import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/constants.dart';

@immutable
class AppPalette {
  // The confirmation overlay is shared by both prototype themes.
  static const restoreOverlay = Color.fromRGBO(5, 12, 30, 0.4);

  const AppPalette({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryHover,
    required this.primarySolid,
    required this.primarySolidHover,
    required this.primaryForeground,
    required this.surfaceHover,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.mutedStrong,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveSolid,
    required this.destructiveSolidHover,
    required this.destructiveForeground,
    required this.border,
    required this.borderStrong,
    required this.input,
    required this.ring,
    required this.selection,
    required this.scannerBackground,
    required this.overlay,
    required this.header,
    required this.brand,
    required this.sidebar,
    required this.sidebarForeground,
    required this.sidebarPrimary,
    required this.sidebarPrimaryForeground,
    required this.sidebarAccent,
    required this.sidebarAccentForeground,
    required this.sidebarBorder,
    required this.sidebarRing,
    required this.selectedSurface,
    required this.running,
    required this.runningText,
    required this.runningBadge,
    required this.runningBadgeForeground,
    required this.runningForeground,
    required this.runningSurface,
    required this.restarting,
    required this.restartingText,
    required this.warningSurface,
    required this.destructiveSurface,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
  });

  // 3 APES: светлая тема — обезьяны (design/monkeys): тёплый белый
  // фон, белые карточки, мятный основной цвет режима «Дома».
  static const light = AppPalette(
    background: Color(0xFFFFFBFC),
    foreground: Color(0xFF161B33),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF161B33),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF161B33),
    primary: Color(0xFF23784A),
    primaryHover: Color(0xFF1C643D),
    primarySolid: Color(0xFF23784A),
    primarySolidHover: Color(0xFF1C643D),
    primaryForeground: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF6F1F4),
    secondary: Color(0xFFFFFFFF),
    secondaryForeground: Color(0xFF161B33),
    muted: Color(0xFFF6F1F4),
    mutedForeground: Color(0xFF5F6378),
    mutedStrong: Color(0xFF444A63),
    accent: Color(0xFFE4F4E7),
    accentForeground: Color(0xFF23784A),
    destructive: Color(0xFFB8403A),
    destructiveSolid: Color(0xFFB8403A),
    destructiveSolidHover: Color(0xFF9C332E),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFFEFE7EC),
    borderStrong: Color(0xFFE0D6DC),
    input: Color(0xFFE6DDE3),
    ring: Color(0xFF8FD3A3),
    selection: Color(0xFFE4F4E7),
    scannerBackground: Color(0xFF161B33),
    overlay: Color.fromRGBO(22, 27, 51, 0.38),
    header: Color(0xFFFFFBFC),
    brand: Color(0xFF161B33),
    sidebar: Color(0xFFFFFBFC),
    sidebarForeground: Color(0xFF444A63),
    sidebarPrimary: Color(0xFF23784A),
    sidebarPrimaryForeground: Color(0xFFFFFFFF),
    sidebarAccent: Color(0xFFE4F4E7),
    sidebarAccentForeground: Color(0xFF23784A),
    sidebarBorder: Color(0xFFEFE7EC),
    sidebarRing: Color(0xFF8FD3A3),
    selectedSurface: Color(0xFFE4F4E7),
    running: Color(0xFF8FD3A3),
    runningText: Color(0xFF23784A),
    runningBadge: Color(0xFF23784A),
    runningBadgeForeground: Color(0xFFFFFFFF),
    runningForeground: Color(0xFF161B33),
    runningSurface: Color(0xFFE4F4E7),
    restarting: Color(0xFF3A63B8),
    restartingText: Color(0xFF3A63B8),
    warningSurface: Color(0xFFFFF2D9),
    destructiveSurface: Color(0xFFFDE7E5),
    chart1: Color(0xFF3A63B8),
    chart2: Color(0xFF23784A),
    chart3: Color(0xFF8A5A00),
    chart4: Color(0xFFB8403A),
    chart5: Color(0xFF7A5BB0),
  );
  // 3 APES: тёмная тема «Мягкая ночь» (подобрана 19.10 на макете): нейтральный
  // тёмно-серый с лёгкой синевой. Фон и плашки спокойные; тексты и акценты —
  // пастели обезьян, смешанные с фоном на 95% (76% оказалось слишком блёкло);
  // кольца — чистые пастели (connectionModeGlow); обезьяны притушены фильтром.
  static const dark = AppPalette(
    background: Color(0xFF111419),
    foreground: Color(0xFFF1F2F5),
    card: Color(0xFF191D24),
    cardForeground: Color(0xFFF1F2F5),
    popover: Color(0xFF1C2029),
    popoverForeground: Color(0xFFF1F2F5),
    primary: Color(0xFF89C99C),
    primaryHover: Color(0xFF95D4A8),
    primarySolid: Color(0xFF89C99C),
    primarySolidHover: Color(0xFF7CB292),
    primaryForeground: Color(0xFF0F2218),
    surfaceHover: Color(0xFF20252E),
    secondary: Color(0xFF191D24),
    secondaryForeground: Color(0xFFF1F2F5),
    muted: Color(0xFF15191F),
    mutedForeground: Color(0xFFB3B8C3),
    mutedStrong: Color(0xFFD9DCE2),
    accent: Color(0xFF1F2929),
    accentForeground: Color(0xFF89C99C),
    destructive: Color(0xFFE6938E),
    destructiveSolid: Color(0xFFA9524D),
    destructiveSolidHover: Color(0xFF934641),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFF272C35),
    borderStrong: Color(0xFF333946),
    input: Color(0xFF272C35),
    ring: Color(0xFF89C99C),
    selection: Color(0xFF263431),
    scannerBackground: Color(0xFF0B0D11),
    overlay: Color.fromRGBO(4, 6, 10, 0.6),
    header: Color(0xFF111419),
    brand: Color(0xFFF1F2F5),
    sidebar: Color(0xFF111419),
    sidebarForeground: Color(0xFFD9DCE2),
    sidebarPrimary: Color(0xFF89C99C),
    sidebarPrimaryForeground: Color(0xFF0F2218),
    sidebarAccent: Color(0xFF1F2929),
    sidebarAccentForeground: Color(0xFF89C99C),
    sidebarBorder: Color(0xFF272C35),
    sidebarRing: Color(0xFF89C99C),
    selectedSurface: Color(0xFF1F2929),
    running: Color(0xFF89C99C),
    runningText: Color(0xFF89C99C),
    runningBadge: Color(0xFF89C99C),
    runningBadgeForeground: Color(0xFF0F2218),
    runningForeground: Color(0xFF0F2218),
    runningSurface: Color(0xFF1F2929),
    restarting: Color(0xFF96AFE3),
    restartingText: Color(0xFF96AFE3),
    warningSurface: Color(0xFF2C2923),
    destructiveSurface: Color(0xFF2C2428),
    chart1: Color(0xFF96AFE3),
    chart2: Color(0xFF89C99C),
    chart3: Color(0xFFE7BD69),
    chart4: Color(0xFFE6938E),
    chart5: Color(0xFFBAA2E3),
  );
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryHover;
  final Color primarySolid;
  final Color primarySolidHover;
  // Foregrounds pair with solid fills, not the dark theme's interactive colors.
  final Color primaryForeground;
  final Color surfaceHover;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color mutedStrong;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveSolid;
  final Color destructiveSolidHover;
  final Color destructiveForeground;
  final Color border;
  final Color borderStrong;
  final Color input;
  final Color ring;
  final Color selection;
  final Color scannerBackground;
  final Color overlay;
  final Color header;
  final Color sidebar;
  final Color brand;
  final Color sidebarForeground;
  final Color sidebarPrimary;
  final Color sidebarPrimaryForeground;
  final Color sidebarAccent;
  final Color sidebarAccentForeground;
  final Color sidebarBorder;
  final Color sidebarRing;
  final Color selectedSurface;
  final Color running;
  final Color runningText;
  final Color runningBadge;
  final Color runningBadgeForeground;
  final Color runningForeground;
  final Color runningSurface;
  final Color restarting;
  final Color restartingText;
  final Color warningSurface;
  final Color destructiveSurface;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  static AppPalette lerp(AppPalette begin, AppPalette end, double t) {
    Color color(Color a, Color b) => Color.lerp(a, b, t) ?? b;

    return AppPalette(
      background: color(begin.background, end.background),
      foreground: color(begin.foreground, end.foreground),
      card: color(begin.card, end.card),
      cardForeground: color(begin.cardForeground, end.cardForeground),
      popover: color(begin.popover, end.popover),
      popoverForeground: color(begin.popoverForeground, end.popoverForeground),
      primary: color(begin.primary, end.primary),
      primaryHover: color(begin.primaryHover, end.primaryHover),
      primarySolid: color(begin.primarySolid, end.primarySolid),
      primarySolidHover: color(begin.primarySolidHover, end.primarySolidHover),
      primaryForeground: color(begin.primaryForeground, end.primaryForeground),
      surfaceHover: color(begin.surfaceHover, end.surfaceHover),
      secondary: color(begin.secondary, end.secondary),
      secondaryForeground: color(
        begin.secondaryForeground,
        end.secondaryForeground,
      ),
      muted: color(begin.muted, end.muted),
      mutedForeground: color(begin.mutedForeground, end.mutedForeground),
      mutedStrong: color(begin.mutedStrong, end.mutedStrong),
      accent: color(begin.accent, end.accent),
      accentForeground: color(begin.accentForeground, end.accentForeground),
      destructive: color(begin.destructive, end.destructive),
      destructiveSolid: color(begin.destructiveSolid, end.destructiveSolid),
      destructiveSolidHover: color(
        begin.destructiveSolidHover,
        end.destructiveSolidHover,
      ),
      destructiveForeground: color(
        begin.destructiveForeground,
        end.destructiveForeground,
      ),
      border: color(begin.border, end.border),
      borderStrong: color(begin.borderStrong, end.borderStrong),
      input: color(begin.input, end.input),
      ring: color(begin.ring, end.ring),
      selection: color(begin.selection, end.selection),
      scannerBackground: color(begin.scannerBackground, end.scannerBackground),
      overlay: color(begin.overlay, end.overlay),
      header: color(begin.header, end.header),
      sidebar: color(begin.sidebar, end.sidebar),
      brand: color(begin.brand, end.brand),
      sidebarForeground: color(begin.sidebarForeground, end.sidebarForeground),
      sidebarPrimary: color(begin.sidebarPrimary, end.sidebarPrimary),
      sidebarPrimaryForeground: color(
        begin.sidebarPrimaryForeground,
        end.sidebarPrimaryForeground,
      ),
      sidebarAccent: color(begin.sidebarAccent, end.sidebarAccent),
      sidebarAccentForeground: color(
        begin.sidebarAccentForeground,
        end.sidebarAccentForeground,
      ),
      sidebarBorder: color(begin.sidebarBorder, end.sidebarBorder),
      sidebarRing: color(begin.sidebarRing, end.sidebarRing),
      selectedSurface: color(begin.selectedSurface, end.selectedSurface),
      running: color(begin.running, end.running),
      runningText: color(begin.runningText, end.runningText),
      runningBadge: color(begin.runningBadge, end.runningBadge),
      runningBadgeForeground: color(
        begin.runningBadgeForeground,
        end.runningBadgeForeground,
      ),
      runningForeground: color(begin.runningForeground, end.runningForeground),
      runningSurface: color(begin.runningSurface, end.runningSurface),
      restarting: color(begin.restarting, end.restarting),
      restartingText: color(begin.restartingText, end.restartingText),
      warningSurface: color(begin.warningSurface, end.warningSurface),
      destructiveSurface: color(
        begin.destructiveSurface,
        end.destructiveSurface,
      ),
      chart1: color(begin.chart1, end.chart1),
      chart2: color(begin.chart2, end.chart2),
      chart3: color(begin.chart3, end.chart3),
      chart4: color(begin.chart4, end.chart4),
      chart5: color(begin.chart5, end.chart5),
    );
  }
}

class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens(this.palette);

  static const light = AppColorTokens(AppPalette.light);
  static const dark = AppColorTokens(AppPalette.dark);

  final AppPalette palette;

  Color get surface => palette.card;
  Color get surfaceBorder => palette.border;
  Color get primaryText => palette.foreground;
  Color get secondaryText => palette.mutedForeground;
  Color get tagBackground => palette.muted;
  Color get selectedBackground => palette.selectedSurface;

  static AppColorTokens fallback(Brightness brightness) {
    return brightness == Brightness.light ? light : dark;
  }

  @override
  AppColorTokens copyWith({AppPalette? palette}) {
    return AppColorTokens(palette ?? this.palette);
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(AppPalette.lerp(palette, other.palette, t));
  }
}

class ColorManager {
  static AppColorTokens tokens(BuildContext context) {
    return Theme.of(context).extension<AppColorTokens>() ??
        AppColorTokens.fallback(Theme.of(context).brightness);
  }

  static AppPalette palette(BuildContext context) => tokens(context).palette;

  static Color surface(BuildContext context) => tokens(context).surface;

  static Color primaryText(BuildContext context) => tokens(context).primaryText;

  static Color secondaryText(BuildContext context) {
    return tokens(context).secondaryText;
  }

  static Color nodeLatency(BuildContext context, int delay) {
    final colors = palette(context);
    if (!PingDelayConstants.isSuccessful(delay)) return colors.mutedForeground;
    // These tones remain legible as small text on normal and selected cards.
    return delay <= 500
        ? colors.runningBadge
        : delay <= 1000
        ? colors.restartingText
        : colors.primaryHover;
  }

  static Color tagBackground(BuildContext context) {
    return tokens(context).tagBackground;
  }

  static Color border(BuildContext context) => tokens(context).surfaceBorder;

  static Color selected(BuildContext context) {
    return tokens(context).selectedBackground;
  }
}
