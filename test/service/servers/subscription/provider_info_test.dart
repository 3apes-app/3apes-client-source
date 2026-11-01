import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/servers/subscription/provider_info.dart';

Map<String, List<String>> _h(Map<String, String> values) => {
  for (final e in values.entries) e.key: [e.value],
};

String _b64(String text) => 'base64:${base64.encode(utf8.encode(text))}';

void main() {
  test('reads the Remnawave header set, base64 and plain', () {
    final info = SubscriptionProviderInfo.fromHeaders(
      _h({
        'profile-title': _b64('3 APES 🐒'),
        'announce': _b64('Скидка 20%\nдо пятницы'),
        'support-url': 'https://t.me/apes_support',
        'profile-web-page-url': 'https://3apes.app/cabinet',
        'profile-update-interval': '1',
      }),
    );
    expect(info.title, '3 APES 🐒');
    expect(info.announce, 'Скидка 20%\nдо пятницы');
    expect(info.supportUrl, 'https://t.me/apes_support');
    expect(info.webPageUrl, 'https://3apes.app/cabinet');
    expect(info.updateIntervalHours, 1);
    expect(info.isEmpty, isFalse);
  });

  test('no headers is an empty info', () {
    expect(SubscriptionProviderInfo.fromHeaders(null).isEmpty, isTrue);
    expect(SubscriptionProviderInfo.fromHeaders({}).isEmpty, isTrue);
  });

  test('raw UTF-8 read as Latin-1 by dart:io is repaired', () {
    final garbled = latin1.decode(utf8.encode('Три обезьяны'));
    final info = SubscriptionProviderInfo.fromHeaders(
      _h({'profile-title': garbled}),
    );
    expect(info.title, 'Три обезьяны');
  });

  test('a value split at commas is joined back', () {
    final info = SubscriptionProviderInfo.fromHeaders({
      'announce': ['Hello', 'world'],
    });
    expect(info.announce, 'Hello, world');
  });

  test('bad values are unknown, the rest survives', () {
    final info = SubscriptionProviderInfo.fromHeaders(
      _h({
        'profile-title': 'base64:%%%',
        'support-url': 'ftp://files.example',
        'profile-web-page-url': 'javascript:alert(1)',
        'profile-update-interval': '0',
        'announce': '  ok  ',
      }),
    );
    expect(info.title, isNull);
    expect(info.supportUrl, isNull);
    expect(info.webPageUrl, isNull);
    expect(info.updateIntervalHours, isNull);
    expect(info.announce, 'ok');
    for (final value in ['-1', '1.5', '721', 'soon', '']) {
      expect(
        SubscriptionProviderInfo.fromHeaders(
          _h({'profile-update-interval': value}),
        ).updateIntervalHours,
        isNull,
        reason: value,
      );
    }
  });

  test('panel mistakes in links are repaired to https', () {
    String? support(String value) => SubscriptionProviderInfo.fromHeaders(
      _h({'support-url': value}),
    ).supportUrl;
    expect(
      support('http://t.me/Project3ApesVPN_SupportBot'),
      'https://t.me/Project3ApesVPN_SupportBot',
    );
    expect(support('t.me/Apes3VPNbot'), 'https://t.me/Apes3VPNbot');
    expect(support('@Apes3VPNbot'), 'https://t.me/Apes3VPNbot');
    expect(support('HTTP://3apes.app/help'), 'https://3apes.app/help');
    expect(support('support'), isNull);
    expect(support('@ab'), isNull);
    expect(support('https://t.me/a b'), isNull);
  });

  test('new-url and fallback-url accept strict https only', () {
    SubscriptionProviderInfo info(String name, String value) =>
        SubscriptionProviderInfo.fromHeaders(_h({name: value}));
    expect(
      info('new-url', 'https://sub.new.example/abc').newUrl,
      'https://sub.new.example/abc',
    );
    expect(
      info('fallback-url', _b64('https://reserve.example/abc?x=1')).fallbackUrl,
      'https://reserve.example/abc?x=1',
    );
    expect(
      info('new-url', 'https://sub.new.example/abc#Name').newUrl,
      'https://sub.new.example/abc',
    );
    for (final bad in [
      'http://sub.new.example/abc',
      'sub.new.example/abc',
      'https://user:pass@sub.new.example/abc',
      'https:///abc',
      'https://sub.new.example/a b',
      'tg://resolve?domain=x',
    ]) {
      expect(info('new-url', bad).newUrl, isNull, reason: bad);
      expect(info('fallback-url', bad).fallbackUrl, isNull, reason: bad);
    }
  });

  test('tg links are accepted for support', () {
    final info = SubscriptionProviderInfo.fromHeaders(
      _h({'support-url': 'tg://resolve?domain=Apes3VPNbot'}),
    );
    expect(info.supportUrl, 'tg://resolve?domain=Apes3VPNbot');
  });

  test('title is one line and length-limited', () {
    final info = SubscriptionProviderInfo.fromHeaders(
      _h({'profile-title': _b64('A\nB${'x' * 100}')}),
    );
    expect(info.title!.contains('\n'), isFalse);
    expect(info.title!.runes.length, SubscriptionProviderInfo.maxTitleLength);
    expect(info.title!.endsWith('…'), isTrue);
  });

  group('nameFor', () {
    const url = 'https://sub.3apes.online/abc';
    const info = SubscriptionProviderInfo(title: '3 APES');

    test('host name follows the title', () {
      expect(info.nameFor('sub.3apes.online', url: url), '3 APES');
    });

    test('previous provider title follows the new title', () {
      const next = SubscriptionProviderInfo(title: '3 APES Premium');
      expect(
        next.nameFor('3 APES', url: url, previousTitle: '3 APES'),
        '3 APES Premium',
      );
    });

    test('a name typed by the user stays', () {
      expect(
        info.nameFor('Мой VPN', url: url, previousTitle: '3 APES'),
        'Мой VPN',
      );
    });

    test('no title keeps the name', () {
      expect(
        const SubscriptionProviderInfo().nameFor('sub.3apes.online', url: url),
        'sub.3apes.online',
      );
    });
  });
}
