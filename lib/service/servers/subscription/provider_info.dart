import 'dart:convert';

/// 3 APES: what the provider tells about its subscription in response headers
/// (the set Remnawave and Happ use). Every field is optional; a malformed field
/// is unknown and never invalidates the subscription body.
class SubscriptionProviderInfo {
  const SubscriptionProviderInfo({
    this.title,
    this.announce,
    this.supportUrl,
    this.webPageUrl,
    this.updateIntervalHours,
    this.newUrl,
    this.fallbackUrl,
  });

  final String? title;
  final String? announce;
  final String? supportUrl;
  final String? webPageUrl;
  final int? updateIntervalHours;

  /// `new-url`: the provider moved the subscription here for good.
  final String? newUrl;

  /// `fallback-url`: reserve address when the main one fails.
  final String? fallbackUrl;

  static const maxTitleLength = 64;
  static const maxAnnounceLength = 500;
  static const maxUrlLength = 2048;
  static const maxIntervalHours = 720;

  /// [headers] as Dio reports them: lowercase names, values possibly split.
  factory SubscriptionProviderInfo.fromHeaders(
    Map<String, List<String>>? headers,
  ) {
    String? raw(String name) {
      final values = headers?[name];
      if (values == null || values.isEmpty) return null;
      // dart:io may split a value at commas; rejoin it as it was sent.
      return values.join(', ');
    }

    return SubscriptionProviderInfo(
      title: _text(raw('profile-title'), maxTitleLength, singleLine: true),
      announce: _text(raw('announce'), maxAnnounceLength, singleLine: false),
      supportUrl: _url(raw('support-url')),
      webPageUrl: _url(raw('profile-web-page-url')),
      updateIntervalHours: _hours(raw('profile-update-interval')),
      newUrl: _subscriptionUrl(raw('new-url')),
      fallbackUrl: _subscriptionUrl(raw('fallback-url')),
    );
  }

  bool get isEmpty =>
      title == null &&
      announce == null &&
      supportUrl == null &&
      webPageUrl == null &&
      updateIntervalHours == null &&
      newUrl == null &&
      fallbackUrl == null;

  /// The subscription name to store. An automatic name (the URL host, or the
  /// title this provider sent before) follows the provider's title; a name the
  /// user typed stays.
  String nameFor(String current, {required String url, String? previousTitle}) {
    final next = title;
    if (next == null) return current;
    final trimmed = current.trim();
    final automatic =
        trimmed.isEmpty ||
        trimmed == Uri.tryParse(url)?.host ||
        (previousTitle != null && trimmed == previousTitle);
    return automatic ? next : current;
  }

  /// Short description for the log; no URLs, the subscription link is secret.
  String describe() =>
      'title=${title == null ? '-' : '"$title"'}, '
      'interval=${updateIntervalHours == null ? '-' : '${updateIntervalHours}h'}, '
      'announce=${announce == null ? 'no' : 'yes'}, '
      'support=${supportUrl == null ? 'no' : 'yes'}, '
      'webPage=${webPageUrl == null ? 'no' : 'yes'}, '
      'newUrl=${newUrl == null ? 'no' : 'yes'}, '
      'fallback=${fallbackUrl == null ? 'no' : 'yes'}';

  static String? _decode(String? value) {
    if (value == null) return null;
    var text = value.trim();
    if (text.isEmpty) return null;
    if (text.toLowerCase().startsWith('base64:')) {
      try {
        final payload = text.substring(7).trim().replaceAll(RegExp(r'\s'), '');
        return utf8.decode(base64.decode(base64.normalize(payload)));
      } catch (_) {
        return null;
      }
    }
    // dart:io reads header bytes as Latin-1; raw UTF-8 text comes garbled.
    final units = text.codeUnits;
    if (units.every((c) => c <= 0xFF) && units.any((c) => c > 0x7F)) {
      try {
        text = utf8.decode(latin1.encode(text));
      } catch (_) {
        // Real Latin-1 text: keep it as received.
      }
    }
    return text;
  }

  static String? _text(
    String? value,
    int maxLength, {
    required bool singleLine,
  }) {
    var text = _decode(value);
    if (text == null) return null;
    text = text.replaceAll('\r\n', '\n');
    text = singleLine
        ? text.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
        : text.replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]+'), ' ');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
    if (text.isEmpty) return null;
    final runes = text.runes.toList();
    if (runes.length > maxLength) {
      text = '${String.fromCharCodes(runes.take(maxLength - 1)).trimRight()}…';
    }
    return text;
  }

  static final _telegramName = RegExp(r'^@([A-Za-z0-9_]{4,32})$');
  static final _bareHost = RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(/|$)');

  /// Only https and tg links are kept. Common panel mistakes are repaired:
  /// `http://` becomes `https://`, `t.me/x` gets a scheme, `@name` becomes a
  /// Telegram link. Nothing is ever opened over plain http.
  static String? _url(String? value) {
    var text = _decode(value);
    if (text == null || text.contains(RegExp(r'\s'))) return null;
    final name = _telegramName.firstMatch(text);
    if (name != null) return 'https://t.me/${name.group(1)}';
    if (text.toLowerCase().startsWith('http://')) {
      text = 'https://${text.substring(7)}';
    } else if (_bareHost.hasMatch(text)) {
      text = 'https://$text';
    }
    if (text.length > maxUrlLength) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https' && uri.host.isNotEmpty) return text;
    if (scheme == 'tg' && text.length > 5) return text;
    return null;
  }

  /// Subscription addresses: strict https, nothing repaired, no fragment.
  static String? _subscriptionUrl(String? value) {
    final text = _decode(value);
    if (text == null ||
        text.length > maxUrlLength ||
        text.contains(RegExp(r'\s'))) {
      return null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final hash = text.indexOf('#');
    return hash < 0 ? text : text.substring(0, hash);
  }

  static int? _hours(String? value) {
    final text = _decode(value);
    if (text == null || !RegExp(r'^[0-9]{1,4}$').hasMatch(text)) return null;
    final hours = int.parse(text);
    return hours >= 1 && hours <= maxIntervalHours ? hours : null;
  }
}
