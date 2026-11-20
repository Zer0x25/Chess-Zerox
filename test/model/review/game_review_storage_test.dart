import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/review/game_review.dart';
import 'package:lichess_mobile/src/model/review/game_review_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('restores an imported review and rejects a changed PGN', () async {
    final db = await openAppDatabase(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
    addTearDown(db.close);
    const options = AnalysisOptions.pgn(
      id: StringId('import_chessCom_game'),
      orientation: Side.white,
      pgn: '1. e4 e5',
      variant: Variant.standard,
      isComputerAnalysisAllowed: true,
    ) as Pgn;
    final mainline = Root.fromPgnMoves('e4 e5').view.mainline.toList();
    final move = ReviewMove(
      ply: 1,
      side: Side.white,
      sanMove: mainline.first.sanMove,
      path: UciPath.fromId(mainline.first.id),
      winPercentBefore: 50,
      winPercentAfter: 48,
      centipawnLoss: 20,
      accuracy: 90,
      verdict: ReviewVerdict.good,
      bestMoveUci: 'e2e4',
    );
    final storage = GameReviewStorage(db);
    await storage.save(options, buildGameReview(moves: IList([move])));

    expect(await storage.matchingKeys({'import_chessCom_game': options.pgn}), {
      'import_chessCom_game',
    });
    expect(await storage.matchingKeys({'import_chessCom_game': '1. d4 d5'}), isEmpty);
    expect(await storage.matchingKeys({'other': options.pgn}), isEmpty);
    final loaded = await storage.load(options, mainline);
    expect(loaded?.moves.single, move);
    expect(await storage.load(options.copyWith(pgn: '1. d4 d5'), mainline), isNull);
  });
}
