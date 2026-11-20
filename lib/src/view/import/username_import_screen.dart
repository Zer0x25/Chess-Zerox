import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/import/chesscom_client.dart';
import 'package:lichess_mobile/src/model/import/import_providers.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:lichess_mobile/src/model/import/imported_game_store.dart';
import 'package:lichess_mobile/src/model/review/game_review_storage.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/more/import_pgn_screen.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// Lists the recent public games of a player and opens one in the analysis board.
class const UsernameImportScreen({
  required final ImportSource source,
  final String? initialUsername,
  super.key,
}) extends ConsumerStatefulWidget {
  static Route<dynamic> buildRoute({required ImportSource source, String? initialUsername}) {
    return buildScreenRoute(
      screen: UsernameImportScreen(source: source, initialUsername: initialUsername),
    );
  }

  @override
  ConsumerState<UsernameImportScreen> createState() => _UsernameImportScreenState();
}

class _UsernameImportScreenState() extends ConsumerState<UsernameImportScreen> {
  static const _limitChoices = [10, 30, 100];

  final _controller = TextEditingController();
  Future<List<ImportedGame>>? _future;
  String? _openingGameId;
  String? _username;
  int _limit = 30;
  bool _searching = false;
  Set<String> _reviewedKeys = {};

  String _gameKey(ImportedGame game) {
    final safeId = '${game.source.name}_${game.id}'.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    return 'import_$safeId';
  }

  Future<void> _refreshReviews(List<ImportedGame> games) async {
    final db = await ref.read(databaseProvider.future);
    final keys = await GameReviewStorage(db).matchingKeys({
      for (final game in games)
        if (game.pgn case final String pgn when pgn.isNotEmpty) _gameKey(game): pgn,
    });
    if (mounted) setState(() => _reviewedKeys = keys);
  }

  @override
  void initState() {
    super.initState();
    final username = widget.initialUsername;
    if (username != null) {
      _controller.text = username;
      _username = username;
      _future = _loadSaved(username);
    }
  }

  Future<List<ImportedGame>> _loadSaved(String username) async {
    final store = await ref.read(importedGameStoreProvider.future);
    final games = await store.listGames(source: widget.source, username: username, limit: null);
    await _refreshReviews(games);
    return games;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final username = _controller.text.trim();
    if (username.isEmpty) {
      showSnackBar(context, context.l10n.mobileImportEnterUsername, type: .error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final store = await ref.read(importedGameStoreProvider.future);
      final cursor = await store.cursorFor(widget.source, username);
      final fetched = switch (widget.source) {
        .lichess =>
          await ref.read(importRepositoryProvider).fetchLichessGames(username, max: _limit),
        .chessCom => await ref.read(chessComClientProvider).fetchRecentGames(username, max: _limit),
      };
      final newer = fetched
          .where((game) {
            final playedAt = game.playedAt;
            return playedAt == null || cursor == null || playedAt.isAfter(cursor);
          })
          .toList(growable: false);
      final newCount = await store.insertGames(
        source: widget.source,
        username: username,
        games: newer,
      );
      ref.invalidate(importedSourcesProvider);
      final saved = await store.listGames(source: widget.source, username: username, limit: null);
      await _refreshReviews(saved);
      if (!mounted) return;
      setState(() {
        _username = username;
        _future = Future.value(saved);
      });
      showSnackBar(context, switch (newCount) {
        0 => context.l10n.mobileImportNoNewGames,
        1 => context.l10n.mobileImportNewGame('1'),
        _ => context.l10n.mobileImportNewGames('$newCount'),
      });
    } catch (error) {
      if (!mounted) return;
      // The future may fail before the first build subscribes to it through the future builder.
      final future = Future<List<ImportedGame>>.error(error);
      future.ignore();
      setState(() {
        _future = future;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openGame(ImportedGame game) async {
    if (!game.isStandardVariant) {
      showSnackBar(context, context.l10n.mobileImportStandardOnly, type: .error);
      return;
    }

    setState(() => _openingGameId = game.id);
    try {
      final pgn = game.pgn ?? await ref.read(importRepositoryProvider).fetchLichessPgn(game.id);
      if (!mounted) return;

      await ImportPgnScreen.handlePgnText(context, pgn, id: StringId(_gameKey(game)));
      final username = _username;
      if (mounted && username != null) {
        setState(() => _future = _loadSaved(username));
      }
    } catch (error) {
      if (mounted) {
        showSnackBar(context, context.l10n.mobileImportOpenError('$error'), type: .error);
      }
    } finally {
      if (mounted) setState(() => _openingGameId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(
          widget.source == .lichess
              ? context.l10n.mobileImportFromLichess
              : context.l10n.mobileImportFromChessCom,
        ),
      ),
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
                      labelText: context.l10n.mobileImportUsername,
                      prefixIcon: const Icon(Icons.person_outline),
                      hintText: context.l10n.mobileImportUsernameExample(
                        widget.source == .lichess ? 'MagnusCarlsen' : 'Hikaru',
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openingGameId == null && !_searching ? _search : null,
                    icon: const Icon(Icons.search),
                    label: Text(
                      _username == null
                          ? context.l10n.mobileImportSearchGames
                          : context.l10n.mobileImportUpdate,
                    ),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(context.l10n.mobileImportCount),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _limit,
                        items: [
                          for (final choice in _limitChoices)
                            DropdownMenuItem(value: choice, child: Text('$choice')),
                        ],
                        onChanged: _searching
                            ? null
                            : (value) {
                                if (value != null) setState(() => _limit = value);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.source == .lichess
                        ? context.l10n.mobileImportPublicOnlyLichess
                        : context.l10n.mobileImportPublicOnlyChessCom,
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
        title: context.l10n.mobileImportNoGames,
        message: widget.source == .lichess
            ? context.l10n.mobileImportNoGamesLichess
            : context.l10n.mobileImportNoGamesChessCom,
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
                    _errorMessage(context, error),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _search,
                    child: Text(context.l10n.mobileImportRetry),
                  ),
                ],
              ),
            ),
          );
        }

        final games = snapshot.data ?? const <ImportedGame>[];
        if (games.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off,
            title: context.l10n.mobileImportNoGamesFound,
            message: context.l10n.mobileImportNoStandardGames,
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
              subtitle: Text(
                _reviewedKeys.contains(_gameKey(game))
                    ? '$subtitle\n✓ Revisión local guardada'
                    : subtitle,
                maxLines: 3,
                overflow: .ellipsis,
              ),
              isThreeLine: _reviewedKeys.contains(_gameKey(game)),
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

  String _errorMessage(BuildContext context, Object error) {
    if (error is ChessComException) {
      return switch (error.kind) {
        .playerNotFound => context.l10n.mobileImportPlayerNotFound,
        .rateLimited => context.l10n.mobileImportRateLimited,
        .other => error.message,
      };
    }
    return context.l10n.mobileImportLoadError;
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
