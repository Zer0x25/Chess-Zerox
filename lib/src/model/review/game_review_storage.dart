import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/review/game_review.dart';
import 'package:sqflite/sqflite.dart';

/// Persists local reviews for imported PGNs, invalidating them when the PGN changes.
class const GameReviewStorage(final Database db) {
  /// Returns keys whose saved review matches the current PGN.
  Future<Set<String>> matchingKeys(Map<String, String> games) async {
    if (games.isEmpty) return {};
    final rows = await db.query('local_game_review', columns: ['game_key', 'pgn_hash']);
    return {
      for (final row in rows)
        if (games[row['game_key']] case final String pgn when _hash(pgn) == row['pgn_hash'])
          row['game_key']! as String,
    };
  }

  Future<void> save(Pgn options, GameReview review) async {
    await db.insert('local_game_review', {
      'game_key': options.id.value,
      'pgn_hash': _hash(options.pgn),
      'data': jsonEncode([
        for (final move in review.moves)
          {
            'ply': move.ply,
            'before': move.winPercentBefore,
            'after': move.winPercentAfter,
            'cpBefore': move.cpBefore,
            'cpAfter': move.cpAfter,
            'loss': move.centipawnLoss,
            'accuracy': move.accuracy,
            'verdict': move.verdict.name,
            'best': move.bestMoveUci,
          },
      ]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<GameReview?> load(Pgn options, List<ViewBranch> mainline) async {
    final rows = await db.query(
      'local_game_review',
      where: 'game_key = ? AND pgn_hash = ?',
      whereArgs: [options.id.value, _hash(options.pgn)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final entries = (jsonDecode(rows.first['data']! as String) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      var path = UciPath.empty;
      final paths = <UciPath>[];
      for (final branch in mainline) {
        path = path + branch.id;
        paths.add(path);
      }
      final moves = <ReviewMove>[];
      for (final entry in entries) {
        final ply = entry['ply'] as int;
        if (ply < 1 || ply > mainline.length) return null;
        final branch = mainline[ply - 1];
        moves.add(
          ReviewMove(
            ply: ply,
            side: branch.position.turn == Side.white ? Side.black : Side.white,
            sanMove: branch.sanMove,
            path: paths[ply - 1],
            winPercentBefore: (entry['before'] as num).toDouble(),
            winPercentAfter: (entry['after'] as num).toDouble(),
            cpBefore: entry['cpBefore'] as int?,
            cpAfter: entry['cpAfter'] as int?,
            centipawnLoss: entry['loss'] as int,
            accuracy: (entry['accuracy'] as num).toDouble(),
            verdict: ReviewVerdict.values.byName(entry['verdict'] as String),
            bestMoveUci: entry['best'] as String?,
          ),
        );
      }
      return buildGameReview(moves: moves.toIList());
    } on Object {
      return null;
    }
  }

  String _hash(String pgn) => sha256.convert(utf8.encode(pgn)).toString();
}
