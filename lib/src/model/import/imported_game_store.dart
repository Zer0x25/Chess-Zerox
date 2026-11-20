import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:sqflite/sqflite.dart';

extension _ImportSourceDb on ImportSource {
  String get dbValue => switch (this) {
    ImportSource.lichess => 'lichess',
    ImportSource.chessCom => 'chessCom',
  };
}

ImportSource _sourceFromDb(String value) => switch (value) {
  'lichess' => ImportSource.lichess,
  'chessCom' => ImportSource.chessCom,
  _ => throw FormatException('Unknown import source: $value'),
};

DateTime? _dateTimeFromDb(Object? value) =>
    value is int ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true) : null;

/// A username whose public games have been imported, with its incremental cursor.
class const StoredImportSource({
  required final ImportSource source,
  required final String username,
  final DateTime? lastPlayedAt,
  required final DateTime lastSyncAt,
}) {
  @override
  String toString() => 'StoredImportSource($source, $username, $lastPlayedAt)';
}

/// Local cache of games imported from Lichess and Chess.com.
///
/// Games keep their full PGN so the analysis board and the local review work offline. Each source
/// and username has a cursor ([StoredImportSource.lastPlayedAt]) used to request only newer games.
class const ImportedGameStore(final Database db) {
  /// Saves [games], ignoring duplicates by (source, external id).
  ///
  /// Returns the number of games that were actually new. The cursor only ever moves forward: if a
  /// game is imported out of order, the most recent date already stored wins.
  Future<int> insertGames({
    required ImportSource source,
    required String username,
    required Iterable<ImportedGame> games,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((txn) async {
      final gamesToSave = games.toList(growable: false);
      final before = await _countRows(
        txn,
        where: 'source = ? AND username = ?',
        args: [source.dbValue, username],
      );

      final batch = txn.batch();
      for (final game in gamesToSave) {
        batch.insert('imported_games', {
          'source': source.dbValue,
          'username': username,
          'external_id': game.id,
          'played_at': game.playedAt?.millisecondsSinceEpoch,
          'white': game.white,
          'black': game.black,
          'result': game.result,
          'speed': game.speed,
          'pgn': game.pgn ?? '',
          'imported_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);

      final existingRows = await txn.query(
        'import_sources',
        columns: ['last_played_at'],
        where: 'source = ? AND username = ?',
        whereArgs: [source.dbValue, username],
      );
      final existingMs = existingRows.isNotEmpty
          ? existingRows.first['last_played_at'] as int?
          : null;
      var newestMs = existingMs;
      for (final game in gamesToSave) {
        final playedAtMs = game.playedAt?.millisecondsSinceEpoch;
        if (playedAtMs != null && (newestMs == null || playedAtMs > newestMs)) {
          newestMs = playedAtMs;
        }
      }

      await txn.insert('import_sources', {
        'source': source.dbValue,
        'username': username,
        'last_played_at': newestMs,
        'last_sync_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return (await _countRows(
            txn,
            where: 'source = ? AND username = ?',
            args: [source.dbValue, username],
          )) -
          before;
    });
  }

  /// Games already saved, newest first.
  Future<List<ImportedGame>> listGames({
    ImportSource? source,
    String? username,
    int? limit = 30,
  }) async {
    final (where, args) = _filter(source, username);
    final rows = await db.query(
      'imported_games',
      where: where,
      whereArgs: args,
      orderBy: 'played_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(_gameFromRow).toList(growable: false);
  }

  /// Date of the most recent game already saved for [source] and [username], if any.
  Future<DateTime?> cursorFor(ImportSource source, String username) async {
    final rows = await db.query(
      'import_sources',
      columns: ['last_played_at'],
      where: 'source = ? AND username = ?',
      whereArgs: [source.dbValue, username],
    );
    return rows.isEmpty ? null : _dateTimeFromDb(rows.first['last_played_at']);
  }

  /// Usernames saved for each source, including their cursor and last synchronization date.
  Future<List<StoredImportSource>> listSources() async {
    final rows = await db.query('import_sources', orderBy: 'source ASC, username ASC');
    return rows
        .map(
          (row) => StoredImportSource(
            source: _sourceFromDb(row['source']! as String),
            username: row['username']! as String,
            lastPlayedAt: _dateTimeFromDb(row['last_played_at']),
            lastSyncAt: DateTime.fromMillisecondsSinceEpoch(row['last_sync_at']! as int),
          ),
        )
        .toList(growable: false);
  }

  Future<int> countGames({ImportSource? source, String? username}) {
    final (where, args) = _filter(source, username);
    return _countRows(db, where: where, args: args);
  }

  /// Deletes saved games and/or cursors. With no arguments, clears everything.
  Future<void> clear({ImportSource? source, String? username}) async {
    final (where, args) = _filter(source, username);
    await db.transaction((txn) async {
      final games = await txn.query(
        'imported_games',
        columns: ['source', 'external_id'],
        where: where,
        whereArgs: args,
      );
      for (final game in games) {
        final safeId = '${game['source']}_${game['external_id']}'.replaceAll(
          RegExp('[^a-zA-Z0-9_]'),
          '_',
        );
        await txn.delete('local_game_review', where: 'game_key = ?', whereArgs: ['import_$safeId']);
      }
      await txn.delete('imported_games', where: where, whereArgs: args);
      await txn.delete('import_sources', where: where, whereArgs: args);
    });
  }

  (String?, List<Object?>?) _filter(ImportSource? source, String? username) {
    final conditions = <String>[];
    final args = <Object?>[];
    if (source != null) {
      conditions.add('source = ?');
      args.add(source.dbValue);
    }
    if (username != null) {
      conditions.add('username = ?');
      args.add(username);
    }
    if (conditions.isEmpty) return (null, null);
    return (conditions.join(' AND '), args);
  }

  Future<int> _countRows(DatabaseExecutor executor, {String? where, List<Object?>? args}) async {
    final rows = await executor.rawQuery(
      'SELECT COUNT(*) AS count FROM imported_games${where != null ? ' WHERE $where' : ''}',
      args,
    );
    return rows.first['count']! as int;
  }

  ImportedGame _gameFromRow(Map<String, Object?> row) => ImportedGame(
    source: _sourceFromDb(row['source']! as String),
    id: row['external_id']! as String,
    white: row['white'] as String? ?? '',
    black: row['black'] as String? ?? '',
    result: row['result'] as String? ?? '*',
    playedAt: _dateTimeFromDb(row['played_at']),
    speed: row['speed'] as String?,
    pgn: row['pgn'] as String?,
  );
}

final importedGameStoreProvider = FutureProvider<ImportedGameStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ImportedGameStore(db);
}, name: 'ImportedGameStoreProvider');

final importedSourcesProvider = FutureProvider<List<({StoredImportSource source, int gameCount})>>((
  ref,
) async {
  final store = await ref.watch(importedGameStoreProvider.future);
  final sources = await store.listSources();
  return [
    for (final source in sources)
      (
        source: source,
        gameCount: await store.countGames(source: source.source, username: source.username),
      ),
  ];
}, name: 'ImportedSourcesProvider');
