import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/app_build.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';

/// 3 APES: what «Новая подписка» does as soon as it opens (from the buttons
/// on «Нет подписки»).
enum NewSubscriptionStart { paste, scan }

/// 3 APES: «Новая подписка» of the new design (phone) — only the link (with
/// «Вставить»), an optional name, «Сканировать QR-код» and «Добавить».
/// Server links, files, JSON and encryption keys are in Advanced.
class NewSubscriptionPage extends StatefulWidget {
  const NewSubscriptionPage({
    super.key,
    this.initialText,
    this.start,
    this.controller,
  });

  /// Paste from the clipboard or open the camera right away.
  final NewSubscriptionStart? start;

  /// A shared or deep-linked subscription link to fill in.
  final String? initialText;
  final ServerImportController? controller;

  @override
  State<NewSubscriptionPage> createState() => _NewSubscriptionPageState();
}

class _NewSubscriptionPageState extends State<NewSubscriptionPage> {
  late final controller = widget.controller ?? ServerImportController();

  @override
  void initState() {
    super.initState();
    final text = widget.initialText;
    if (text != null) controller.fillSubscription(text);
    final start = widget.start;
    if (text == null && start != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (start) {
          case NewSubscriptionStart.paste:
            unawaited(controller.pasteSubscription(context));
          case NewSubscriptionStart.scan:
            if (controller.supportsScan) {
              unawaited(controller.scanSubscription(context));
            }
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocBuilder<ServerImportController, ServerImportPageState>(
      builder: (context, state) {
        final l = AppLocalizations.of(context)!;
        final palette = ColorManager.palette(context);
        final canAdd = controller.canSubmit(ServerImportAction.subscription);
        final scanning = state.openingAction == ServerImportAction.scan;
        OutlineInputBorder border(Color color, [double width = 1]) =>
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: color, width: width),
            );
        InputDecoration decoration(String hint, {Widget? suffix}) =>
            InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: palette.mutedForeground),
              filled: true,
              fillColor: palette.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: suffix,
              border: border(palette.border),
              enabledBorder: border(palette.border),
              focusedBorder: border(palette.running, 1.5),
            );
        Widget label(String text) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
          child: Text(
            text.toUpperCase(),
            style: AppTypography.serverSectionTitle.copyWith(
              color: palette.mutedForeground,
              letterSpacing: 1.4,
            ),
          ),
        );
        return PopScope(
          canPop: state.canClose,
          child: Scaffold(
            appBar: PageAppBar(title: Text(l.newSubscriptionTitle)),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  label(l.newSubscriptionLink),
                  TextField(
                    key: const ValueKey('new-subscription-url'),
                    controller: controller.url,
                    enabled: !state.busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    decoration: decoration(
                      'https://…',
                      suffix: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: TextButton(
                          key: const ValueKey('new-subscription-paste'),
                          onPressed: state.busy
                              ? null
                              : () => controller.pasteSubscription(context),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.runningText,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(l.newSubscriptionPaste),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 6, 0),
                    child: Text(
                      AppBuild.site
                          ? l.newSubscriptionLinkHint
                          : l.newSubscriptionLinkHintStore,
                      style: AppTypography.settingsHint.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  label(l.newSubscriptionName),
                  TextField(
                    key: const ValueKey('new-subscription-name'),
                    controller: controller.name,
                    enabled: !state.busy,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: decoration(l.newSubscriptionNameHint),
                  ),
                  if (controller.supportsScan) ...[
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      key: const ValueKey('new-subscription-scan'),
                      onPressed: state.busy
                          ? null
                          : () => controller.scanSubscription(context),
                      icon: scanning
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.foreground,
                              ),
                            )
                          : const Icon(LucideIcons.qrCode, size: 20),
                      label: Text(l.prototypeScanQrCode),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        backgroundColor: palette.card,
                        foregroundColor: palette.foreground,
                        side: BorderSide(color: palette.border),
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.error!,
                        style: AppTypography.settingsHint.copyWith(
                          color: palette.destructive,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                key: const ValueKey('new-subscription-add'),
                onPressed: canAdd ? () => controller.subscribe(context) : null,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: palette.running,
                  foregroundColor: palette.runningForeground,
                  disabledBackgroundColor: palette.running.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: palette.runningForeground.withValues(
                    alpha: 0.7,
                  ),
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: state.submitting
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: palette.runningForeground,
                        ),
                      )
                    : Text(l.noSubscriptionAdd),
              ),
            ),
          ),
        );
      },
    ),
  );
}
