import 'dart:convert';

import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/shared/share/app_link_model.dart';
import 'package:onexray/service/servers/subscription/model.dart';

abstract final class OneXrayAppLinkParser {
  /// 3 APES: own scheme. A URI scheme must start with a letter, so not "3apes".
  static const scheme = 'threeapes';
  static const host = '3apes.app';

  /// Short form for buttons and subscription pages:
  /// `threeapes://add?url=<link>` or `threeapes://add/<link>` (as Happ does).
  static const shortAddHost = 'add';

  /// OneXray links are still read, e.g. pasted from another device.
  static const legacyScheme = 'onexray';
  static const legacyHost = 'onexray.com';

  static bool isAppScheme(String? value) {
    final lower = value?.toLowerCase();
    return lower == scheme || lower == legacyScheme;
  }

  static const configPath = '/config/add';
  static const subscriptionPath = '/sub/add';
  static const geoDataPath = '/dat/add';

  static OneXrayAppLink? parse(Uri uri) {
    final linkScheme = uri.scheme.toLowerCase();
    final linkHost = uri.host.toLowerCase();
    if (uri.hasPort || uri.userInfo.isNotEmpty) return null;
    if (linkScheme == scheme && linkHost == shortAddHost) {
      return _parseShortSubscription(uri);
    }
    final known =
        (linkScheme == scheme && linkHost == host) ||
        (linkScheme == legacyScheme && linkHost == legacyHost);
    if (!known) {
      return null;
    }

    return switch (uri.path) {
      configPath => _parseConfig(uri),
      subscriptionPath => _parseSubscription(uri),
      geoDataPath => _parseGeoData(uri),
      _ => null,
    };
  }

  static OneXrayConfigLink? _parseConfig(Uri uri) {
    if (!_hasOnlyQueryKeys(uri, const {'type', 'data'})) {
      return null;
    }
    final typeText = _singleQueryValue(uri, 'type');
    final data = _singleQueryValue(uri, 'data');
    if (typeText == null || data == null) {
      return null;
    }
    final type = switch (typeText) {
      'outbound' => OneXrayConfigLinkType.outbound,
      'raw' => OneXrayConfigLinkType.raw,
      'custom' => OneXrayConfigLinkType.custom,
      'custom-advanced' => OneXrayConfigLinkType.customAdvanced,
      _ => null,
    };
    if (type == null) {
      return null;
    }

    try {
      final xrayJson = utf8.decode(base64Decode(data));
      if (xrayJson.trim().isEmpty) {
        return null;
      }
      return OneXrayConfigLink(
        name: _fragmentName(uri),
        type: type,
        xrayJson: xrayJson,
      );
    } catch (_) {
      return null;
    }
  }

  static OneXraySubscriptionLink? _parseSubscription(Uri uri) {
    if (!_hasOnlyQueryKeys(uri, const {'url', 'age'})) {
      return null;
    }
    final urlText = _singleQueryValue(uri, 'url');
    if (urlText == null) {
      return null;
    }
    final url = _httpsUrl(SubscriptionUrl.normalize(urlText));
    if (url == null) {
      return null;
    }

    final ageText = _optionalSingleQueryValue(uri, 'age');
    AgeKeyType? ageKeyType;
    if (ageText != null) {
      ageKeyType = switch (ageText) {
        'x25519' => AgeKeyType.x25519,
        'hybrid' => AgeKeyType.hybrid,
        _ => null,
      };
      if (ageKeyType == null) {
        return null;
      }
    }

    return OneXraySubscriptionLink(
      name: _fragmentName(uri),
      url: url,
      ageKeyType: ageKeyType,
    );
  }

  /// `threeapes://add?url=<link>#name` or `threeapes://add/<link>`; the
  /// link may be percent-encoded. Only https subscriptions are accepted.
  static OneXraySubscriptionLink? _parseShortSubscription(Uri uri) {
    if (uri.path.isEmpty || uri.path == '/') {
      if (!_hasOnlyQueryKeys(uri, const {'url'})) return null;
      final urlText = _singleQueryValue(uri, 'url');
      if (urlText == null) return null;
      final url = _httpsUrl(SubscriptionUrl.normalize(urlText));
      if (url == null) return null;
      return OneXraySubscriptionLink(name: _fragmentName(uri), url: url);
    }
    final text = uri.toString();
    final start = text.toLowerCase().indexOf('://$shortAddHost/');
    if (start < 0) return null;
    var raw = text.substring(start + shortAddHost.length + 4).trim();
    if (raw.toLowerCase().startsWith('https%3a')) {
      try {
        raw = Uri.decodeComponent(raw);
      } catch (_) {
        return null;
      }
    }
    final url = _httpsUrl(SubscriptionUrl.normalize(raw));
    if (url == null) return null;
    return OneXraySubscriptionLink(name: '', url: url);
  }

  static OneXrayGeoDataLink? _parseGeoData(Uri uri) {
    if (!_hasOnlyQueryKeys(uri, const {'type', 'url'})) {
      return null;
    }
    final typeText = _singleQueryValue(uri, 'type');
    final urlText = _singleQueryValue(uri, 'url');
    if (typeText == null || urlText == null) {
      return null;
    }
    final type = GeoDataType.fromString(typeText);
    final url = _httpsUrl(urlText);
    if (type == null || url == null) {
      return null;
    }
    return OneXrayGeoDataLink(name: _fragmentName(uri), type: type, url: url);
  }

  static String? _httpsUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty) {
      return null;
    }
    return uri.toString();
  }

  static bool _hasOnlyQueryKeys(Uri uri, Set<String> allowed) {
    return uri.queryParametersAll.keys.every(allowed.contains);
  }

  static String? _singleQueryValue(Uri uri, String key) {
    final values = uri.queryParametersAll[key];
    if (values == null || values.length != 1) {
      return null;
    }
    final value = values.single.trim();
    return value.isEmpty ? null : value;
  }

  static String? _optionalSingleQueryValue(Uri uri, String key) {
    if (!uri.queryParametersAll.containsKey(key)) {
      return null;
    }
    return _singleQueryValue(uri, key);
  }

  static String _fragmentName(Uri uri) {
    if (uri.fragment.isEmpty) {
      return '';
    }
    try {
      return Uri.decodeComponent(uri.fragment).trim();
    } catch (_) {
      return '';
    }
  }
}
