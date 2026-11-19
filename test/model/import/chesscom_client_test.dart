import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/model/import/chesscom_client.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';

const _archivesUrl = 'https://api.chess.com/pub/player/hikaru/games/archives';
const _novemberUrl = 'https://api.chess.com/pub/player/hikaru/games/2026/11';
const _octoberUrl = 'https://api.chess.com/pub/player/hikaru/games/2026/10';

const _archivesJson =
    '''
{
  "archives": [
    "$_octoberUrl",
    "$_novemberUrl"
  ]
}
''';

const _novemberJson = '''
{
  "games": [
    {
      "uuid": "november-rapid",
      "url": "https://www.chess.com/game/live/1",
      "pgn": "[Event \\"Live Chess\\"]\\n[Result \\"1-0\\"]\\n\\n1. e4 e5 2. Nf3 1-0",
      "time_class": "rapid",
      "rules": "chess",
      "end_time": 1763500000,
      "white": {"username": "Hikaru", "rating": 3300, "result": "win"},
      "black": {"username": "Rival", "rating": 3100, "result": "resigned"}
    },
    {
      "uuid": "november-chess960",
      "url": "https://www.chess.com/game/live/2",
      "pgn": "[Result \\"0-1\\"]\\n\\n1. e4 0-1",
      "time_class": "blitz",
      "rules": "chess960",
      "end_time": 1763400000,
      "white": {"username": "Hikaru", "rating": 3300, "result": "checkmated"},
      "black": {"username": "Rival", "rating": 3100, "result": "win"}
    },
    {
      "uuid": "november-no-pgn",
      "time_class": "bullet",
      "rules": "chess",
      "end_time": 1763300000,
      "white": {"username": "Hikaru", "rating": 3300, "result": "win"},
      "black": {"username": "Rival", "rating": 3100, "result": "resigned"}
    }
  ]
}
''';

const _octoberJson = '''
{
  "games": [
    {
      "uuid": "october-blitz",
      "url": "https://www.chess.com/game/live/3",
      "pgn": "[Result \\"1/2-1/2\\"]\\n\\n1. e4 e5 1/2-1/2",
      "time_class": "blitz",
      "rules": "chess",
      "end_time": 1762000000,
      "white": {"username": "Hikaru", "rating": 3290, "result": "agreed"},
      "black": {"username": "Other", "rating": 3050, "result": "agreed"}
    }
  ]
}
''';

void main() {
  group('ChessComClient.fetchRecentGames', () {
    test('lists the latest standard games of a player', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return switch (request.url.toString()) {
          _archivesUrl => http.Response(_archivesJson, 200),
          _novemberUrl => http.Response(_novemberJson, 200),
          _octoberUrl => http.Response(_octoberJson, 200),
          _ => http.Response('', 404),
        };
      });

      final games = await ChessComClient(
        client,
        clock: () => DateTime.utc(2026, 11, 19),
      ).fetchRecentGames('hikaru', months: 2, max: 10);

      expect(requests.map((r) => r.url.toString()), [_archivesUrl, _novemberUrl, _octoberUrl]);
      expect(requests.first.headers['User-Agent'], startsWith('ChessZerox/'));

      // Chess960 and games without a PGN are skipped, and the newest game comes first.
      expect(games.map((g) => g.id), ['november-rapid', 'october-blitz']);

      final rapid = games.first;
      expect(rapid.source, ImportSource.chessCom);
      expect(rapid.white, 'Hikaru');
      expect(rapid.black, 'Rival');
      expect(rapid.whiteRating, 3300);
      expect(rapid.blackRating, 3100);
      expect(rapid.result, '1-0');
      expect(rapid.speed, 'rapid');
      expect(rapid.variant, 'chess');
      expect(rapid.isStandardVariant, isTrue);
      expect(
        rapid.playedAt?.toUtc(),
        DateTime.fromMillisecondsSinceEpoch(1763500000 * 1000, isUtc: true),
      );
      expect(rapid.pgn, contains('[Result "1-0"]'));
    });

    test('limits the number of months and games fetched', () async {
      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return switch (request.url.toString()) {
          _archivesUrl => http.Response(_archivesJson, 200),
          _novemberUrl => http.Response(_novemberJson, 200),
          _octoberUrl => http.Response(_octoberJson, 200),
          _ => http.Response('', 404),
        };
      });

      final games = await ChessComClient(
        client,
        clock: () => DateTime.utc(2026, 11, 19),
      ).fetchRecentGames('hikaru', months: 1, max: 1);

      expect(requestedUrls, [_archivesUrl, _novemberUrl]);
      expect(games.single.id, 'november-rapid');
    });

    test('returns an empty list for an empty username', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final games = await ChessComClient(client).fetchRecentGames('   ');
      expect(games, isEmpty);
    });

    test('caches responses for 12 hours and revalidates with ETag', () async {
      var now = DateTime.utc(2026, 11, 19, 12);
      var monthRequests = 0;
      final client = MockClient((request) async {
        return switch (request.url.toString()) {
          _archivesUrl => http.Response(_archivesJson, 200),
          _novemberUrl => () {
            monthRequests++;
            if (request.headers['If-None-Match'] == '"month-1"') {
              return http.Response('', 304);
            }
            return http.Response(_novemberJson, 200, headers: {'ETag': '"month-1"'});
          }(),
          _ => http.Response('', 404),
        };
      });
      final chessCom = ChessComClient(client, clock: () => now);

      await chessCom.fetchRecentGames('hikaru', months: 1);
      expect(monthRequests, 1);

      now = now.add(const Duration(hours: 11));
      final cachedGames = await chessCom.fetchRecentGames('hikaru', months: 1);
      expect(monthRequests, 1);
      expect(cachedGames.single.id, 'november-rapid');

      now = now.add(const Duration(hours: 2));
      final revalidatedGames = await chessCom.fetchRecentGames('hikaru', months: 1);
      expect(monthRequests, 2);
      expect(revalidatedGames.single.id, 'november-rapid');
    });

    test('maps HTTP errors to exceptions', () async {
      final notFound = ChessComClient(MockClient((request) async => http.Response('', 404)));
      await expectLater(
        notFound.fetchRecentGames('unknown'),
        throwsA(
          isA<ChessComException>().having((e) => e.message, 'message', contains('not found')),
        ),
      );

      final rateLimited = ChessComClient(MockClient((request) async => http.Response('', 429)));
      await expectLater(
        rateLimited.fetchRecentGames('hikaru'),
        throwsA(
          isA<ChessComException>().having((e) => e.message, 'message', contains('rate limiting')),
        ),
      );

      final serverError = ChessComClient(MockClient((request) async => http.Response('', 500)));
      await expectLater(
        serverError.fetchRecentGames('hikaru'),
        throwsA(isA<ChessComException>().having((e) => e.message, 'message', contains('HTTP 500'))),
      );
    });
  });

  group('parseChessComMonth', () {
    test('derives the result from the players when the PGN has no Result tag', () {
      final games = parseChessComMonth(jsonDecode(_novemberJson) as Map<String, dynamic>);
      expect(games.single.result, '1-0');
    });
  });
}
