import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/connect/settings.dart';

/// 3 APES: server groups for connection modes, read from server names.
///
/// The provider marks servers in their names: "Белый список · …" and
/// "LTE·БС · …" work on mobile internet with whitelists. A 🇷🇺 flag or
/// "Россия" marks the *entry* in Russia, not the exit (checked 16.10.2026:
/// "Обычные · 🇷🇺 RU" exits in Belgrade), so the abroad mode needs an explicit
/// exit marker: "Выход РФ" or "RU-exit" in the name. The pinned libXray no
/// longer reports the real exit country; a measured country code still wins
/// when it is present.
abstract final class ModeServers {
  static final _mobile = RegExp(
    r'белый\s*список|(^|[\s·|/(\[-])бс($|[\s·|/)\]-])|white\s*list|whitelist',
    caseSensitive: false,
    unicode: true,
  );
  static final _russianExit = RegExp(
    r'выход\s*(в\s*)?(рф|россии)|ru[\s_-]?exit',
    caseSensitive: false,
    unicode: true,
  );

  static bool isMobile(String name) => _mobile.hasMatch(name);

  /// Whether the name says the traffic exits in Russia.
  static bool hasRussianExit(String name) => _russianExit.hasMatch(name);

  /// Whether the server's traffic leaves the internet in Russia.
  static bool isRussian(CoreConfigData row) {
    final measured = row.countryCode?.toUpperCase();
    if (measured != null && measured.isNotEmpty) return measured == 'RU';
    return hasRussianExit(row.name);
  }

  /// Rows a mode may use, in the order of preference. Each list is tried in
  /// turn until one has servers; an empty result means the mode is unavailable.
  static List<bool Function(CoreConfigData)> poolsFor(ConnectionMode mode) =>
      switch (mode) {
        // Whitelist servers are scarce: keep them for mobile internet, but
        // never leave a subscription without servers.
        ConnectionMode.home ||
        ConnectionMode.protect => [(row) => !isMobile(row.name), (_) => true],
        ConnectionMode.abroad => [
          (row) => isRussian(row) && !isMobile(row.name),
          isRussian,
        ],
      };
}
