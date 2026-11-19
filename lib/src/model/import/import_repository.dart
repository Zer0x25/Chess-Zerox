import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/game/exported_game.dart';
import 'package:lichess_mobile/src/model/game/game_repository.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';

/// Imports games from Lichess using the client and repositories the app already has.
class const ImportRepository(final GameRepository _gameRepository) {
  Future<List<ImportedGame>> fetchLichessGames(String username, {int max = 30}) async {
    final userId = UserId.fromUserName(username.trim());
    final games = await _gameRepository.getUserGames(userId, max: max);
    return games
        .map((entry) => entry.game)
        .where((game) => game.variant == Variant.standard)
        .map(_lichessGame)
        .toList(growable: false);
  }

  Future<String> fetchLichessPgn(String gameId) {
    return _gameRepository.getGamePgn(GameId(gameId));
  }
}

ImportedGame _lichessGame(LightExportedGame game) {
  final white = game.white;
  final black = game.black;
  return ImportedGame(
    source: .lichess,
    id: game.id.value,
    white: white.user?.name ?? white.name ?? 'Anonymous',
    black: black.user?.name ?? black.name ?? 'Anonymous',
    whiteRating: white.rating,
    blackRating: black.rating,
    result: _result(game),
    playedAt: game.createdAt,
    speed: game.speed.name,
    variant: game.variant.name,
    url: 'https://lichess.org/${game.id.value}',
  );
}

String _result(LightExportedGame game) {
  if (game.status == GameStatus.started || game.status == GameStatus.created) {
    return '*';
  }
  return switch (game.winner) {
    Side.white => '1-0',
    Side.black => '0-1',
    null => '1/2-1/2',
  };
}
