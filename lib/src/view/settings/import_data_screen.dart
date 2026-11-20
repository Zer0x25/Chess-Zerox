import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/import/imported_game_store.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/import/username_import_screen.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/platform_alert_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Lets the user delete the usernames and games stored locally by the importer.
class const ImportDataScreen({super.key}) extends ConsumerWidget {
  static Route<dynamic> buildRoute() => buildScreenRoute(screen: const ImportDataScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(importedSourcesProvider);

    Future<void> clear({StoredImportSource? source}) async {
      final store = await ref.read(importedGameStoreProvider.future);
      await store.clear(source: source?.source, username: source?.username);
      ref.invalidate(importedSourcesProvider);
    }

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.mobileImportData)),
      body: switch (sources) {
        AsyncData(:final value) => _Body(
          sources: value,
          onClearEntry: (entry) => clear(source: entry),
          onClearAll: () => clear(),
        ),
        AsyncError() => FullScreenRetryRequest(
          onRetry: () => ref.invalidate(importedSourcesProvider),
        ),
        _ => const Center(child: CircularProgressIndicator.adaptive()),
      },
    );
  }
}

class const _Body({
  required final List<({StoredImportSource source, int gameCount})> sources,
  required final Future<void> Function(StoredImportSource source) onClearEntry,
  required final Future<void> Function() onClearAll,
}) extends StatelessWidget {
  Future<void> _confirm(BuildContext context, Future<void> Function() onConfirm) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => PlatformAlertDialog(
        title: Text(context.l10n.mobileImportClearConfirm),
        content: Text(context.l10n.mobileImportClearConfirmBody),
        actions: [
          PlatformDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          PlatformDialogAction(
            cupertinoIsDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return Center(
        child: Padding(
          padding: Styles.bodySectionPadding,
          child: Text(context.l10n.mobileImportNoData, textAlign: .center),
        ),
      );
    }

    return ListView(
      children: [
        ListSection(
          hasLeading: true,
          children: [
            for (final entry in sources)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(entry.source.username, maxLines: 1, overflow: .ellipsis),
                subtitle: Text(
                  '${entry.source.source.label} • '
                  '${context.l10n.mobileImportGamesCount('${entry.gameCount}')}',
                ),
                onTap: () => Navigator.of(context).push(
                  UsernameImportScreen.buildRoute(
                    source: entry.source.source,
                    initialUsername: entry.source.username,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirm(context, () => onClearEntry(entry.source)),
                ),
              ),
          ],
        ),
        ListSection(
          hasLeading: true,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(context.l10n.mobileImportClearAll),
              onTap: () => _confirm(context, onClearAll),
            ),
          ],
        ),
      ],
    );
  }
}
