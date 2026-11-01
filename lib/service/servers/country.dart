import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connect/mode_servers.dart';

/// 3 APES: the country a server belongs to.
///
/// The pinned libXray no longer reports the exit country, so the measured
/// `countryCode` is usually empty. The provider puts a flag in the server
/// name ("Обычные · 🇩🇪 DE · …"), which is used instead. A 🇷🇺 flag marks the
/// entry in Russia, not the exit (see [ModeServers]), so it only counts when
/// the name also says the exit is in Russia.
abstract final class ServerCountry {
  static const _first = 0x1F1E6; // REGIONAL INDICATOR SYMBOL LETTER A
  static const _last = 0x1F1FF; // REGIONAL INDICATOR SYMBOL LETTER Z

  /// Two upper-case letters, or `null` when the country is unknown.
  static String? of(CoreConfigData row) {
    final measured = row.countryCode?.trim().toUpperCase();
    if (measured != null && measured.isNotEmpty) return measured;
    return fromName(row.name);
  }

  static String? fromName(String name) {
    final runes = name.runes.toList();
    for (var i = 0; i + 1 < runes.length; i++) {
      if (_indicator(runes[i]) && _indicator(runes[i + 1])) {
        final code = String.fromCharCodes([
          runes[i] - _first + 0x41,
          runes[i + 1] - _first + 0x41,
        ]);
        if (code == 'RU' && !ModeServers.hasRussianExit(name)) return null;
        return code;
      }
    }
    return null;
  }

  /// Same comparison the region selection always used, with the flag fallback.
  static bool matches(CoreConfigData row, String? region) =>
      of(row) == region?.toUpperCase();

  /// The flag emoji for a two-letter code, or an empty string.
  static String flag(String? code) {
    final normalized = code?.toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(normalized)) return '';
    return String.fromCharCodes(
      normalized.codeUnits.map((unit) => unit - 0x41 + _first),
    );
  }

  static final _protocol = RegExp(
    r'^(vless|vmess|trojan|ss|shadowsocks|hysteria2?|hy2|tuic|wireguard|socks|http)$',
    caseSensitive: false,
  );
  static final _latency = RegExp(r'^\d+\s*ms$', caseSensitive: false);
  static final _code = RegExp(r'^[A-Z]{2}$');

  /// The server name without what the country screen already shows: the
  /// flag, the country code, the protocol and a delay written into the name.
  /// "Обычные · 🇮🇳 IN · vless · 828ms · 17" → "Обычные · 17".
  static String shortName(String name) {
    final parts = <String>[];
    for (final raw in name.split('·')) {
      final words = raw
          .trim()
          .split(RegExp(r'\s+'))
          .where(
            (word) =>
                word.isNotEmpty &&
                !word.runes.every(_indicator) &&
                !_code.hasMatch(word) &&
                !_protocol.hasMatch(word) &&
                !_latency.hasMatch(word),
          )
          .toList();
      if (words.isNotEmpty) parts.add(words.join(' '));
    }
    return parts.isEmpty ? name.trim() : parts.join(' · ');
  }

  static bool _indicator(int rune) => rune >= _first && rune <= _last;
}
