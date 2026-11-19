import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/model/import/import_providers.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';

import '../../test_container.dart';
import '../../test_helpers.dart';

const _standardGame =
    '{"id":"g2bzFol8","rated":true,"variant":"standard","speed":"blitz","perf":"blitz",'
    '"createdAt":1673553626465,"lastMoveAt":1673553936657,"status":"resign",'
    '"players":{"white":{"user":{"name":"SchallUndRausch","id":"schallundrausch"},"rating":1751},'
    '"black":{"user":{"name":"Thibault","patron":true,"id":"thibault"},"rating":1767}},'
    '"winner":"black","clock":{"initial":180,"increment":2,"totalTime":260}}';

const _fromPositionGame =
    '{"id":"Huk88k3D","rated":false,"variant":"fromPosition","speed":"blitz","perf":"blitz",'
    '"createdAt":1673716450321,"lastMoveAt":1673716450321,"status":"noStart",'
    '"players":{"white":{"aiLevel":1},"black":{"user":{"name":"Thibault","id":"thibault"}}},'
    '"clock":{"initial":300,"increment":0,"totalTime":300}}';

void main() {
  group('ImportRepository.fetchLichessGames', () {
    test('lists only standard games and maps their metadata', () async {
      final mockClient = MockClient((request) {
        if (request.url.path == '/api/games/user/testuser') {
          return mockResponse('$_standardGame\n$_fromPositionGame\n', 200);
        }
        return mockResponse('', 404);
      });

      final container = await lichessClientContainer(mockClient);
      final games = await container.read(importRepositoryProvider).fetchLichessGames('testUser');

      expect(games, hasLength(1));
      final game = games.single;
      expect(game.source, ImportSource.lichess);
      expect(game.id, 'g2bzFol8');
      expect(game.playersLabel, 'SchallUndRausch vs Thibault');
      expect(game.whiteRating, 1751);
      expect(game.blackRating, 1767);
      expect(game.result, '0-1');
      expect(game.speed, 'blitz');
      expect(game.variant, 'standard');
      expect(game.isStandardVariant, isTrue);
      expect(game.pgn, isNull);
      expect(game.url, 'https://lichess.org/g2bzFol8');
    });

    test('returns an empty list when the player has no standard games', () async {
      final mockClient = MockClient((request) {
        if (request.url.path == '/api/games/user/testuser') {
          return mockResponse('$_fromPositionGame\n', 200);
        }
        return mockResponse('', 404);
      });

      final container = await lichessClientContainer(mockClient);
      final games = await container.read(importRepositoryProvider).fetchLichessGames('testUser');

      expect(games, isEmpty);
    });
  });

  group('ImportRepository.fetchLichessPgn', () {
    test('downloads the PGN of a game', () async {
      const pgn = '[Event "Test"]\n[Result "1-0"]\n\n1. e4 e5 1-0';
      final requests = <http.Request>[];
      final mockClient = MockClient((request) {
        requests.add(request);
        if (request.url.path == '/game/export/g2bzFol8') {
          return mockResponse(pgn, 200);
        }
        return mockResponse('', 404);
      });

      final container = await lichessClientContainer(mockClient);
      final result = await container.read(importRepositoryProvider).fetchLichessPgn('g2bzFol8');

      expect(result, pgn);
      expect(requests.single.headers['Accept'], 'application/x-chess-pgn');
    });
  });
}
