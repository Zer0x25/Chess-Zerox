import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';

part 'game_review.freezed.dart';

/// Our own classification of a played move.
///
/// The two special labels are heuristics and are always explained as such in the UI. They are not
/// copied from any other app's assessment system.
enum ReviewVerdict() {
  best,
  excellent,
  good,
  inaccuracy,
  mistake,
  blunder,
  star,
  missedChance,
}

/// Status of a local review run.
enum ReviewStatus() {
  running,
  done,
  failed,
  cancelled,
}

/// A move assessed by the local engine.
@freezed
sealed class const ReviewMove._() with _$ReviewMove {
  const factory({
    /// Ply of the move in the mainline, starting at 1.
    required int ply,
    required Side side,
    required SanMove sanMove,
    required UciPath path,
    required double winPercentBefore,
    required double winPercentAfter,
    int? cpBefore,
    int? cpAfter,
    required int centipawnLoss,
    required double accuracy,
    required ReviewVerdict verdict,
    String? bestMoveUci,
  }) = _ReviewMove;

  /// A winning move which was also a material or attacking breakthrough.
  bool get isStar => verdict == .star;

  /// A move which threw away an already winning position.
  bool get isMissedChance => verdict == .missedChance;
}

/// Number of moves of each kind, for one side.
@freezed
sealed class const ReviewCounts._() with _$ReviewCounts {
  const factory({
    @Default(0) int best,
    @Default(0) int excellent,
    @Default(0) int good,
    @Default(0) int inaccuracy,
    @Default(0) int mistake,
    @Default(0) int blunder,
    @Default(0) int star,
    @Default(0) int missedChance,
  }) = _ReviewCounts;
}

/// The finished report of a game.
@freezed
sealed class const GameReview._() with _$GameReview {
  const factory({
    required IList<ReviewMove> moves,
    required double whiteAccuracy,
    required double blackAccuracy,
    required int whiteAcpl,
    required int blackAcpl,
    required ReviewCounts whiteCounts,
    required ReviewCounts blackCounts,
  }) = _GameReview;

  /// Moves worth showing first in the report.
  IList<ReviewMove> get keyMoments => moves
      .where(
        (move) =>
            move.isStar ||
            move.isMissedChance ||
            move.verdict == .blunder ||
            move.verdict == .mistake,
      )
      .toIList();
}

/// State of the review controller.
@freezed
sealed class const GameReviewState._() with _$GameReviewState {
  const factory({
    @Default(ReviewStatus.running) ReviewStatus status,
    @Default(0.0) double progress,
    @Default(0) int evaluated,
    @Default(0) int total,
    GameReview? review,
    String? error,
  }) = _GameReviewState;
}

/// Converts a centipawn score to a win percentage from White's point of view.
double whiteWinPercent(Eval eval) {
  if (eval.mate != null) return eval.mate! > 0 ? 100 : 0;
  final cp = eval.cp ?? 0;
  return 100 / (1 + math.exp(-0.00368208 * cp));
}

/// Accuracy of a single move from the win percentage it lost (0-100).
double moveAccuracy(double winPercentDrop) {
  final value =
      103.1668100711649 * math.exp(-0.04354415386753951 * winPercentDrop.clamp(0, 100)) -
      3.166924740191411 +
      1;
  return value.clamp(0, 100).toDouble();
}

/// Game accuracy from the per-move accuracies of one side.
///
/// This follows the shape of the Lichess formula: a volatility-weighted mean combined with a
/// harmonic mean, so a single bad move cannot be hidden by many good ones. It is an approximation
/// of the reference implementation, not a copy of it.
double gameAccuracy(IList<double> moveAccuracies) {
  if (moveAccuracies.isEmpty) return 0;
  final windowSize = ((moveAccuracies.length - 1) / 10).round().clamp(2, 8);
  final weights = <double>[];
  for (var i = 0; i < moveAccuracies.length; i++) {
    final start = math.max(0, i - windowSize ~/ 2);
    final end = math.min(moveAccuracies.length, start + windowSize);
    final slice = moveAccuracies.sublist(start, end);
    final mean = slice.reduce((a, b) => a + b) / slice.length;
    final variance =
        slice.fold<double>(0, (sum, value) {
          final diff = value - mean;
          return sum + diff * diff;
        }) /
        slice.length;
    weights.add(math.sqrt(variance));
  }

  final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);
  final weighted = totalWeight == 0
      ? moveAccuracies.reduce((a, b) => a + b) / moveAccuracies.length
      : moveAccuracies.asMap().entries.fold<double>(0, (sum, entry) {
              return sum + entry.value * weights[entry.key];
            }) /
            totalWeight;
  final harmonic =
      moveAccuracies.length /
      moveAccuracies.fold<double>(0, (sum, value) => sum + 1 / math.max(value, 1));
  return ((weighted + harmonic) / 2).clamp(0, 100).toDouble();
}

/// Average centipawn loss of one side, rounded to an integer.
int averageCentipawnLoss(IList<int> losses) {
  if (losses.isEmpty) return 0;
  return (losses.reduce((a, b) => a + b) / losses.length).round();
}

ReviewCounts _countVerdicts(Iterable<ReviewVerdict> verdicts) {
  var counts = const ReviewCounts();
  for (final verdict in verdicts) {
    counts = switch (verdict) {
      .best => counts.copyWith(best: counts.best + 1),
      .excellent => counts.copyWith(excellent: counts.excellent + 1),
      .good => counts.copyWith(good: counts.good + 1),
      .inaccuracy => counts.copyWith(inaccuracy: counts.inaccuracy + 1),
      .mistake => counts.copyWith(mistake: counts.mistake + 1),
      .blunder => counts.copyWith(blunder: counts.blunder + 1),
      .star => counts.copyWith(star: counts.star + 1),
      .missedChance => counts.copyWith(missedChance: counts.missedChance + 1),
    };
  }
  return counts;
}

/// Builds the report from the per-move engine evaluations.
///
/// [evals] contains one entry per ply, with `evals[0]` being the initial position.
GameReview buildGameReview({required IList<ReviewMove> moves}) {
  final whiteMoves = moves.where((move) => move.side == Side.white).toIList();
  final blackMoves = moves.where((move) => move.side == Side.black).toIList();

  return GameReview(
    moves: moves,
    whiteAccuracy: gameAccuracy(whiteMoves.map((move) => move.accuracy).toIList()),
    blackAccuracy: gameAccuracy(blackMoves.map((move) => move.accuracy).toIList()),
    whiteAcpl: averageCentipawnLoss(whiteMoves.map((move) => move.centipawnLoss).toIList()),
    blackAcpl: averageCentipawnLoss(blackMoves.map((move) => move.centipawnLoss).toIList()),
    whiteCounts: _countVerdicts(whiteMoves.map((move) => move.verdict)),
    blackCounts: _countVerdicts(blackMoves.map((move) => move.verdict)),
  );
}

/// Classifies a move from its effect on the winning chances.
///
/// `shift` is positive when the move lost winning chances, expressed like the reference
/// thresholds of the practice feature (0.05 good, 0.11 inaccuracy, 0.24 mistake).
ReviewVerdict classifyMove({
  required double shift,
  required bool hasBetterMove,
  required double winPercentBefore,
  required double winPercentAfter,
  required bool wasWinning,
  required bool isBestMove,
}) {
  // A winning position thrown away is the most useful thing to surface first.
  if (wasWinning && winPercentAfter < 50 && shift >= 0.11) return .missedChance;

  // Turning an equal or losing position into a clearly winning one, with the engine's approval,
  // is our own heuristic for a star move.
  if (isBestMove &&
      shift < 0.05 &&
      winPercentBefore <= 50 &&
      winPercentAfter >= 70 &&
      !wasWinning) {
    return .star;
  }

  if (!hasBetterMove) return .best;
  if (shift < 0.02) return .excellent;
  if (shift < 0.05) return .good;
  if (shift < 0.11) return .inaccuracy;
  if (shift < 0.24) return .mistake;
  return .blunder;
}
