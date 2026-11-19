import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:lichess_mobile/src/model/import/imported_game_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ImportedGameStore store;

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    addTearDown(db.close);
    store = ImportedGameStore(db);
  });

  ImportedGame game(
    String id,
    DateTime playedAt, {
    ImportSource source = ImportSource.chessCom,
    String pgn = '[Result "*"]\n\n*',
  }) {
    return ImportedGame(
      source: source,
      id: id,
      white: 'white',
      black: 'black',
      result: '*',
      playedAt: playedAt,
      speed: 'blitz',
      pgn: pgn,
    );
  }

  group('ImportedGameStore', () {
    test('inserts games with their PGN and ignores duplicates', () async {
      final older = DateTime.utc(2026, 1, 2);
      final newer = DateTime.utc(2026, 1, 5);
      final first = game('a', older, pgn: '[Event "A"]\n\n*');
      final second = game('b', newer, pgn: '[Event "B"]\n\n*');

      expect(
        await store.insertGames(
          source: ImportSource.chessCom,
          username: 'IIZeroxII',
          games: [first, second],
        ),
        2,
      );
      expect(
        await store.insertGames(
          source: ImportSource.chessCom,
          username: 'IIZeroxII',
          games: [first],
        ),
        0,
      );

      final saved = await store.listGames();
      expect(saved, hasLength(2));
      final byId = {for (final g in saved) g.id: g};
      expect(byId['a']!.pgn, '[Event "A"]\n\n*');
      expect(byId['b']!.pgn, '[Event "B"]\n\n*');
      expect(byId['a']!.speed, 'blitz');
    });

    test('cursor is the newest played game and never moves backwards', () async {
      const source = ImportSource.chessCom;
      const username = 'IIZeroxII';
      final jan = DateTime.utc(2026, 1, 5);
      final feb = DateTime.utc(2026, 2, 3);

      await store.insertGames(source: source, username: username, games: [game('a', jan)]);
      expect(await store.cursorFor(source, username), jan);

      // An older game imported later must not move the cursor back.
      await store.insertGames(
        source: source,
        username: username,
        games: [game('older', DateTime.utc(2025, 12, 1))],
      );
      expect(await store.cursorFor(source, username), jan);

      await store.insertGames(source: source, username: username, games: [game('b', feb)]);
      expect(await store.cursorFor(source, username), feb);

      final sources = await store.listSources();
      expect(sources, hasLength(1));
      expect(sources.single.source, source);
      expect(sources.single.username, username);
      expect(sources.single.lastPlayedAt, feb);
    });

    test('cursors are independent per source and username', () async {
      final date = DateTime.utc(2026, 3, 1);
      await store.insertGames(
        source: ImportSource.chessCom,
        username: 'one',
        games: [game('a', date)],
      );
      await store.insertGames(
        source: ImportSource.lichess,
        username: 'one',
        games: [game('b', date, source: ImportSource.lichess)],
      );

      expect(await store.cursorFor(ImportSource.chessCom, 'one'), date);
      expect(await store.cursorFor(ImportSource.lichess, 'one'), date);
      expect(await store.cursorFor(ImportSource.chessCom, 'two'), isNull);
      expect(await store.listSources(), hasLength(2));
    });

    test('lists newest first and filters by source and username', () async {
      final jan = DateTime.utc(2026, 1, 1);
      final mar = DateTime.utc(2026, 3, 1);
      final feb = DateTime.utc(2026, 2, 1);

      await store.insertGames(
        source: ImportSource.chessCom,
        username: 'one',
        games: [game('a', jan), game('b', mar), game('c', feb)],
      );
      await store.insertGames(
        source: ImportSource.lichess,
        username: 'two',
        games: [game('d', mar, source: ImportSource.lichess)],
      );

      expect((await store.listGames()).map((g) => g.id), ['d', 'b', 'c', 'a']);
      expect((await store.listGames(source: ImportSource.chessCom)).map((g) => g.id), [
        'b',
        'c',
        'a',
      ]);
      expect((await store.listGames(username: 'two')).map((g) => g.id), ['d']);
      expect((await store.listGames(limit: 2)).map((g) => g.id), ['d', 'b']);
      expect(await store.countGames(source: ImportSource.chessCom), 3);
    });

    test('clear removes only the requested source or username', () async {
      final date = DateTime.utc(2026, 1, 1);
      await store.insertGames(
        source: ImportSource.chessCom,
        username: 'one',
        games: [game('a', date)],
      );
      await store.insertGames(
        source: ImportSource.chessCom,
        username: 'two',
        games: [game('b', date)],
      );
      await store.insertGames(
        source: ImportSource.lichess,
        username: 'one',
        games: [game('c', date, source: ImportSource.lichess)],
      );

      await store.clear(source: ImportSource.chessCom, username: 'one');
      expect((await store.listGames()).map((g) => g.id), ['c', 'b']);
      expect(await store.listSources(), hasLength(2));

      await store.clear(source: ImportSource.chessCom);
      expect((await store.listGames()).map((g) => g.id), ['c']);

      await store.clear();
      expect(await store.listGames(), isEmpty);
      expect(await store.listSources(), isEmpty);
    });
  });

  group('Database v10', () {
    test('an upgrade from v9 creates the import tables and keeps existing data', () async {
      final dir = await Directory.systemTemp.createTemp('db_upgrade_v10');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/app.db';

      final v9 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, version) async {
            await db.execute(
              'CREATE TABLE puzzle(puzzleId TEXT NOT NULL PRIMARY KEY, '
              'lastModified TEXT NOT NULL, data TEXT NOT NULL)',
            );
            await db.insert('puzzle', {
              'puzzleId': 'p1',
              'lastModified': DateTime.now().toIso8601String(),
              'data': '{}',
            });
          },
        ),
      );
      await v9.close();

      final upgraded = await openAppDatabase(databaseFactoryFfi, path);
      addTearDown(upgraded.close);

      final tables = (await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name']).toList();
      expect(tables, contains('import_sources'));
      expect(tables, contains('imported_games'));
      expect(await upgraded.query('puzzle'), hasLength(1));

      final upgradedStore = ImportedGameStore(upgraded);
      await upgradedStore.insertGames(
        source: ImportSource.lichess,
        username: 'one',
        games: [game('g1', DateTime.utc(2026, 2, 1), source: ImportSource.lichess)],
      );
      expect(await upgradedStore.listGames(), hasLength(1));
    });
  });
}
