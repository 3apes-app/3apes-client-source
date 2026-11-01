import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/connect/provider_announce.dart';

SubscriptionData _row(int id, String? announce) => SubscriptionData(
  id: id,
  name: 'Sub $id',
  url: 'https://example.com/$id',
  hwidEnabled: false,
  timestamp: DateTime(2026),
  announce: announce,
);

void main() {
  test('the first subscription with an announcement is shown', () {
    expect(ProviderAnnounceCard.pick([]), isNull);
    expect(
      ProviderAnnounceCard.pick([_row(1, null), _row(2, '  '), _row(3, 'Hi')]),
      'Hi',
    );
    expect(
      ProviderAnnounceCard.pick([_row(1, 'First'), _row(2, 'Second')]),
      'First',
    );
  });

  test('a changed announcement has a new fingerprint', () {
    final a = ProviderAnnounceCard.fingerprint('Скидка до пятницы');
    expect(a, hasLength(16));
    expect(ProviderAnnounceCard.fingerprint('Скидка до пятницы'), a);
    expect(ProviderAnnounceCard.fingerprint('Скидка до субботы'), isNot(a));
  });
}
