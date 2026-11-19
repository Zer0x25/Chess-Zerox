import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/import/chesscom_client.dart';
import 'package:lichess_mobile/src/model/import/import_providers.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/more/import_pgn_screen.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the recent public games of a player and opens one in the analysis board.
class const UsernameImportScreen({required final ImportSource source, super.key})
    extends ConsumerStatefulWidget {
  static Route<dynamic> buildRoute({required ImportSource source}) {
    return buildScreenRoute(screen: UsernameImportScreen(source: source));
  }

  @override
  ConsumerState<UsernameImportScreen> createState() => _UsernameImportScreenState();
}

class _UsernameImportScreenState() extends ConsumerState<UsernameImportScreen> {
  final _controller = TextEditingController();
  Future<List<ImportedGame>>? _future;
  String? _openingGameId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final username = _controller.text.trim();
    if (username.isEmpty) {
      showSnackBar(context, 'Enter a username first.', type: .error);
      return;
    }

    FocusScope.of(context).unfocus();
    final future = switch (widget.source) {
      .lichess => ref.read(importRepositoryProvider).fetchLichessGames(username),
      .chessCom => ref.read(chessComClientProvider).fetchRecentGames(username),
    };
    // The future may fail before the first build subscribes to it through the future builder,
    // which the framework would report as an unhandled error.
    future.ignore();
    setState(() {
      _future = future;
    });
  }

  Future<void> _openGame(ImportedGame game) async {
    if (!game.isStandardVariant) {
      showSnackBar(context, 'Only standard chess is supported for now.', type: .error);
      return;
    }

    setState(() => _openingGameId = game.id);
    try {
      final pgn = game.pgn ?? await ref.read(importRepositoryProvider).fetchLichessPgn(game.id);
      if (!mounted) return;

      final safeId = '${game.source.name}_${game.id}'.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
      ImportPgnScreen.handlePgnText(context, pgn, id: StringId('import_$safeId'));
    } catch (error) {
      if (mounted) {
        showSnackBar(context, 'Could not open the game: $error', type: .error);
      }
    } finally {
      if (mounted) setState(() => _openingGameId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text('Import from ${widget.source.label}')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: Styles.bodySectionPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    enabled: _openingGameId == null,
                    textInputAction: .search,
                    textCapitalization: .none,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      hintText: widget.source == .lichess ? 'e.g. MagnusCarlsen' : 'e.g. Hikaru',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openingGameId == null ? _search : null,
                    icon: const Icon(Icons.search),
                    label: const Text('Search games'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.source == .lichess ? 'Public games only. You do not need to log in.' : 'Public games only. For private games, export the PGN and use Import PGN.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(child: _results()),
          ],
        ),
      ),
    );
  }

  Widget _results() {
    final future = _future;
    if (future == null) {
      return _EmptyState(
        icon: Icons.download_outlined,
        title: 'No games loaded yet',
        message: widget.source == .lichess
            ? 'Enter a Lichess username to see their latest public games.'
            : 'Enter a Chess.com username to see their latest public games.',
      );
    }

    return FutureBuilder<List<ImportedGame>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final error = snapshot.error;
        if (error != null) {
          return Center(
            child: Padding(
              padding: Styles.bodySectionPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(error),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: _search, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final games = snapshot.data ?? const <ImportedGame>[];
        if (games.isEmpty) {
          return const _EmptyState(
            icon: Icons.search_off,
            title: 'No games found',
            message: 'This player has no recent public standard games.',
          );
        }

        return ListView.separated(
          itemCount: games.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final game = games[index];
            final date = game.playedAt;
            final dateLabel = date != null
                ? MaterialLocalizations.of(context).formatShortDate(date)
                : null;
            final subtitle = [
              game.result,
              ?game.speed,
              ?dateLabel,
              if (game.whiteRating != null || game.blackRating != null) game.ratingsLabel,
            ].join(' • ');

            return ListTile(
              leading: CircleAvatar(child: Text(game.source == .lichess ? 'L' : 'C')),
              title: Text(game.playersLabel, maxLines: 1, overflow: .ellipsis),
              subtitle: Text(subtitle, maxLines: 2, overflow: .ellipsis),
              trailing: _openingGameId == game.id
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _openingGameId == null ? () => _openGame(game) : null,
            );
          },
        );
      },
    );
  }

  String _errorMessage(Object error) {
    if (error is ChessComException) return error.message;
    return 'Could not load games. Check your connection and try again.';
  }
}

class const _EmptyState({
  required final IconData icon,
  required final String title,
  required final String message,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Styles.bodySectionPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
