import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/servers/country.dart';

CoreConfigData _row(String name, {String? country}) => CoreConfigData(
  id: 1,
  name: name,
  type: 'outbound',
  tags: 'vless',
  data: '',
  delay: 0,
  subId: 0,
  countryCode: country,
  favorite: false,
);

void main() {
  test('reads the country from the flag in the name', () {
    expect(ServerCountry.of(_row('Обычные · 🇩🇪 DE · vless')), 'DE');
    expect(ServerCountry.of(_row('🇳🇱 Amsterdam')), 'NL');
    expect(ServerCountry.of(_row('Node without a flag')), isNull);
  });

  test('a measured country wins over the name', () {
    expect(ServerCountry.of(_row('🇩🇪 Germany', country: 'fi')), 'FI');
    expect(ServerCountry.of(_row('🇩🇪 Germany', country: '')), 'DE');
  });

  test('a Russian flag is the entry unless the exit is in Russia', () {
    expect(ServerCountry.of(_row('Обычные · 🇷🇺 RU')), isNull);
    expect(ServerCountry.of(_row('🇷🇺 Россия · Выход РФ')), 'RU');
  });

  test('short names drop what the country screen already shows', () {
    expect(
      ServerCountry.shortName('Обычные · 🇮🇳 IN · vless · 828ms · 17'),
      'Обычные · 17',
    );
    expect(ServerCountry.shortName('🇩🇪 Frankfurt'), 'Frankfurt');
    expect(ServerCountry.shortName('🇩🇪 DE'), '🇩🇪 DE');
  });

  test('region matching and flags', () {
    final row = _row('Обычные · 🇮🇳 IN');
    expect(ServerCountry.matches(row, 'in'), isTrue);
    expect(ServerCountry.matches(row, 'DE'), isFalse);
    expect(ServerCountry.flag('de'), '🇩🇪');
    expect(ServerCountry.flag(''), '');
  });
}
