import 'package:intl/intl.dart' show NumberFormat;
import 'package:onexray/l10n/localizations/app_localizations.dart';

String formatTraffic(int bytes, {bool connection = false}) {
  // Match the connection page's approved labels; other consumers use IEC units.
  final units = connection
      ? const ['B', 'KB', 'MB', 'GB', 'TB']
      : const ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  var number = value.toStringAsFixed(
    unit == 0
        ? 0
        : connection
        ? 2
        : 1,
  );
  if (connection && number.contains('.')) {
    number = number.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return '$number ${units[unit]}';
}

/// 3 APES: subscription traffic in the user's language — localized units
/// ("1,2 ГБ" in Russian) and the locale's decimal separator.
String formatTrafficFor(AppLocalizations l, int bytes) {
  final units = l.trafficUnits.split(',');
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final number = NumberFormat(unit == 0 ? '0' : '0.0', l.localeName);
  return '${number.format(value)} ${units[unit]}';
}
