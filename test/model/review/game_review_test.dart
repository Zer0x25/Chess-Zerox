import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/review/game_review.dart';

void main() {
  group('win percentage', () {
    test('maps centipawns and mates from White’s point of view', () {
      expect(whiteWinPercent(const ExternalEval(cp: 0, mate: null)), 50);
      expect(whiteWinPercent(const ExternalEval(cp: 200, mate: null)), greaterThan(50));
      expect(whiteWinPercent(const ExternalEval(cp: -200, mate: null)), lessThan(50));
      expect(whiteWinPercent(const ExternalEval(cp: 0, mate: 3)), 100);
      expect(whiteWinPercent(const ExternalEval(cp: 0, mate: -3)), 0);
    });
  });

  group('accuracy', () {
    test('a move keeping all winning chances is perfect', () {
      expect(moveAccuracy(0), 100);
      expect(moveAccuracy(-5), 100);
    });

    test('losing all winning chances gives no accuracy', () {
      expect(moveAccuracy(100), lessThan(1));
    });

    test('one bad move cannot be averaged away', () {
      final steady = gameAccuracy(IList(const [90.0, 90.0, 90.0, 90.0]));
      final withLoss = gameAccuracy(IList(const [90.0, 90.0, 90.0, 5.0]));
      expect(steady, greaterThan(80));
      expect(withLoss, lessThan(steady));
    });

    test('an empty game has no accuracy', () {
      expect(gameAccuracy(IList(const [])), 0);
      expect(averageCentipawnLoss(IList(const [])), 0);
    });
  });

  group('move classification', () {
    test('a move with no better alternative is best', () {
      expect(
        classifyMove(
          shift: 0.3,
          hasBetterMove: false,
          winPercentBefore: 80,
          winPercentAfter: 50,
          wasWinning: true,
          isBestMove: true,
        ),
        ReviewVerdict.best,
      );
    });

    test('small losses are inaccuracies and big ones blunders', () {
      expect(
        classifyMove(
          shift: 0.08,
          hasBetterMove: true,
          winPercentBefore: 50,
          winPercentAfter: 40,
          wasWinning: false,
          isBestMove: false,
        ),
        ReviewVerdict.inaccuracy,
      );
      expect(
        classifyMove(
          shift: 0.3,
          hasBetterMove: true,
          winPercentBefore: 50,
          winPercentAfter: 10,
          wasWinning: false,
          isBestMove: false,
        ),
        ReviewVerdict.blunder,
      );
    });

    test('a winning position thrown away is a missed chance', () {
      expect(
        classifyMove(
          shift: 0.3,
          hasBetterMove: true,
          winPercentBefore: 85,
          winPercentAfter: 30,
          wasWinning: true,
          isBestMove: false,
        ),
        ReviewVerdict.missedChance,
      );
    });

    test('turning a losing position into a winning one with the best move is a star move', () {
      expect(
        classifyMove(
          shift: 0,
          hasBetterMove: false,
          winPercentBefore: 40,
          winPercentAfter: 85,
          wasWinning: false,
          isBestMove: true,
        ),
        ReviewVerdict.star,
      );
    });
  });
}
