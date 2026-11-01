import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';

class DocURLHelper {
  static const _domain = "onexray.com";

  static String _localizedDocsPath(String page) {
    return switch (AppEventBus.instance.state.languageCode) {
      LanguageCode.zh => "/zh/docs/$page/",
      LanguageCode.ru => "/ru/docs/$page/",
      _ => "/docs/$page/",
    };
  }

  static Uri docUri() {
    final uri = Uri.https("3apes.app", "/");
    ygLogger("$uri");
    return uri;
  }

  static Uri creditsUri() {
    final path = _localizedDocsPath("credits");
    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }

  static Uri privacyUri() {
    final uri = Uri.https("3apes.app", "/privacy");
    ygLogger("$uri");
    return uri;
  }
}
