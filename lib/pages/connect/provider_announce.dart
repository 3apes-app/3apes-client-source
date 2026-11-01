import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/color.dart';

/// 3 APES: the provider's `announce` header on the main screen. Closing it
/// hides this exact text; a new announcement shows again.
class ProviderAnnounceCard extends StatefulWidget {
  const ProviderAnnounceCard({super.key});

  /// The first subscription with an announcement, in the order they were added.
  static String? pick(Iterable<SubscriptionData> rows) {
    for (final row in rows) {
      final text = row.announce?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String fingerprint(String text) =>
      sha256.convert(utf8.encode(text)).toString().substring(0, 16);

  @override
  State<ProviderAnnounceCard> createState() => _ProviderAnnounceCardState();
}

class _ProviderAnnounceCardState extends State<ProviderAnnounceCard> {
  StreamSubscription<List<SubscriptionData>>? _rows;
  String? _announce;
  String? _dismissed;
  var _ready = false;

  /// 3 APES: announcements that already hid themselves in this app session.
  /// They return on the next launch; only «×» hides one for good.
  static final _hiddenThisSession = <String>{};
  static const _showFor = Duration(seconds: 5);
  Timer? _hideTimer;
  String? _timerFor;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      _dismissed = await PreferencesKey().readDismissedAnnounce();
    } catch (_) {
      // Without preferences the announcement simply cannot be hidden.
    }
    if (!mounted) return;
    _rows = AppDatabase().subscriptionDao.allRowsStream.listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          _announce = ProviderAnnounceCard.pick(rows);
          _ready = true;
        });
      },
      onError: (Object _) {
        // The main screen must not fail because of an announcement.
      },
    );
  }

  Future<void> _dismiss(String text) async {
    final fingerprint = ProviderAnnounceCard.fingerprint(text);
    setState(() => _dismissed = fingerprint);
    try {
      await PreferencesKey().saveDismissedAnnounce(fingerprint);
    } catch (_) {
      // Hidden for this session only.
    }
  }

  /// Starts the auto-hide countdown once per announcement text.
  void _scheduleHide(String fingerprint) {
    if (_timerFor == fingerprint) return;
    _hideTimer?.cancel();
    _timerFor = fingerprint;
    _hideTimer = Timer(_showFor, () {
      if (!mounted) return;
      setState(() => _hiddenThisSession.add(fingerprint));
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _rows?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _announce;
    final fingerprint = text == null
        ? null
        : ProviderAnnounceCard.fingerprint(text);
    if (!_ready ||
        text == null ||
        fingerprint == _dismissed ||
        _hiddenThisSession.contains(fingerprint)) {
      return const SizedBox.shrink();
    }
    _scheduleHide(fingerprint!);
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: Semantics(
        container: true,
        label: l.providerAnnounceLabel,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ColorManager.palette(context).primary
                  .withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.megaphone,
                  color: ColorManager.palette(context).primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.prototypeClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => _dismiss(text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
