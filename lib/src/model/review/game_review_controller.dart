import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/engine/engine_budget.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_context.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_preferences.dart';
import 'package:lichess_mobile/src/model/engine/position_evaluator.dart';
import 'package:lichess_mobile/src/model/engine/work.dart';
import 'package:lichess_mobile/src/model/review/game_review.dart';

/// Time spent on each position of a first-pass review.
///
/// Deliberately short: the report is a guide, and a long batch would keep the board hostage.
const _kSearchTime = Duration(milliseconds: 900);

/// How long the engine must stay silent before we accept its last reported evaluation.
const _kResultQuietPeriod = Duration(milliseconds: 500);

/// Safety net so a stuck engine can never keep the review waiting forever.
const _kSearchTimeout = Duration(seconds: 4);

final gameReviewControllerProvider = AsyncNotifierProvider.autoDispose
    .family<GameReviewController, GameReviewState, AnalysisOptions>(
      GameReviewController.new,
      name: 'GameReviewControllerProvider',
    );

/// Runs a local Stockfish review of the game currently open in the analysis board.
class GameReviewController(final AnalysisOptions options) extends AsyncNotifier<GameReviewState> {
  StreamSubscription<EvalResult>? _subscription;
  PositionEvaluator? _evaluator;
  bool _cancelled = false;

  @override
  Future<GameReviewState> build() async {
    _cancelled = false;
    ref.onDispose(() {
      _cancelled = true;
      unawaited(_subscription?.cancel());
      _evaluator?.stop();
    });

    final analysisState = ref.read(analysisControllerProvider(options)).requireValue;
    final mainline = analysisState.root.mainline.toList(growable: false);

    // The analysis screen and the review share the same engine. Stop the interactive evaluator so
    // its searches cannot supersede ours (and ours cannot make the board flicker).
    try {
      ref.read(positionEvaluatorProvider(analysisState.evaluationContext).notifier).release();
    } catch (_) {
      // The analysis evaluator may not have been started yet.
    }

    if (mainline.isEmpty) {
      return GameReviewState(
        status: .done,
        review: buildGameReview(moves: IList(const [])),
      );
    }

    final context = EvaluationContext(
      id: StringId('review-${options.contextId.value}'),
      variant: analysisState.variant,
      initialPosition: analysisState.root.position,
      enginePref: analysisState.evaluationContext.enginePref,
    );
    _evaluator = ref.read(positionEvaluatorProvider(context).notifier);

    unawaited(_run(mainline: mainline, analysisState: analysisState, context: context));

    return GameReviewState(evaluated: 0, total: mainline.length + 1);
  }

  Future<void> _run({
    required List<ViewBranch> mainline,
    required AnalysisState analysisState,
    required EvaluationContext context,
  }) async {
    try {
      final prefs = ref.read(engineEvaluationPreferencesProvider);
      final threads = ref.read(engineBudgetProvider).analysisThreads(prefs.numEngineCores);
      final evals = <ClientEval?>[];
      final paths = <UciPath>[];
      var path = UciPath.empty;
      var steps = IList<Step>(const []);

      evals.add(
        await _evaluate(
          id: StringId('${context.id.value}-0'),
          path: path,
          steps: steps,
          analysisState: analysisState,
          context: context,
          threads: threads,
        ),
      );
      _reportProgress(done: 1, total: mainline.length + 1);

      for (var i = 0; i < mainline.length; i++) {
        if (_cancelled || !ref.mounted) return;
        final branch = mainline[i];
        path = path + branch.id;
        paths.add(path);
        steps = steps.add(Step.fromNode(branch.branch));
        evals.add(
          await _evaluate(
            id: StringId('${context.id.value}-${i + 1}'),
            path: path,
            steps: steps,
            analysisState: analysisState,
            context: context,
            threads: threads,
          ),
        );
        _reportProgress(done: i + 2, total: mainline.length + 1);
      }

      if (_cancelled || !ref.mounted) return;

      final moves = <ReviewMove>[];
      for (var i = 0; i < mainline.length; i++) {
        final before = evals[i];
        final after = evals[i + 1];
        if (before == null || after == null) continue;
        moves.add(
          _reviewMove(
            branch: mainline[i],
            path: paths[i],
            before: before,
            after: after,
            ply: i + 1,
          ),
        );
      }

      if (!ref.mounted) return;
      state = AsyncData(
        GameReviewState(
          status: .done,
          progress: 1,
          evaluated: moves.length,
          total: mainline.length,
          review: buildGameReview(moves: moves.toIList()),
        ),
      );
    } catch (error) {
      if (ref.mounted) {
        state = AsyncData(GameReviewState(status: .failed, error: '$error'));
      }
    }
  }

  Future<ClientEval?> _evaluate({
    required StringId id,
    required UciPath path,
    required IList<Step> steps,
    required AnalysisState analysisState,
    required EvaluationContext context,
    required int threads,
  }) async {
    final evaluator = _evaluator!;
    final work = EvalWork(
      id: id,
      variant: analysisState.variant,
      threads: threads,
      path: path,
      searchTime: _kSearchTime,
      multiPv: 2,
      threatMode: false,
      initialPosition: analysisState.root.position,
      steps: steps,
    );

    // The evaluator's result stream is a broadcast stream that stays open for the lifetime of the
    // evaluator, so it never completes on its own. Wait instead until the engine stops reporting
    // results for this position (the evaluator emits a final result when `bestmove` arrives).
    LocalEval? result;
    final finished = Completer<void>();
    Timer? quietTimer;
    Timer? hardTimer;

    void finish() {
      if (finished.isCompleted) return;
      quietTimer?.cancel();
      hardTimer?.cancel();
      finished.complete();
    }

    void scheduleFinish() {
      quietTimer?.cancel();
      quietTimer = Timer(_kResultQuietPeriod, finish);
    }

    await _subscription?.cancel();
    _subscription = evaluator.evaluate(work).listen((value) {
      if (value.$1 == work) {
        result = value.$2;
        scheduleFinish();
      }
    }, onError: (_) => finish());
    hardTimer = Timer(_kSearchTimeout, finish);
    await finished.future;
    await _subscription?.cancel();
    _subscription = null;

    if (_cancelled || !ref.mounted) return null;
    return result;
  }

  void _reportProgress({required int done, required int total}) {
    if (!ref.mounted) return;
    state = AsyncData(GameReviewState(evaluated: done, total: total, progress: done / total));
  }

  ReviewMove _reviewMove({
    required ViewBranch branch,
    required UciPath path,
    required ClientEval before,
    required ClientEval after,
    required int ply,
  }) {
    final side = branch.position.turn == Side.white ? Side.black : Side.white;
    final beforeWin = before.winningChances(side) * 100;
    final afterWin = after.winningChances(side) * 100;
    final shift = Eval.winningChancesPovDiff(side, before, after).clamp(0, 1).toDouble();
    final isBestMove = before.bestMove == branch.sanMove.move;
    final verdict = classifyMove(
      shift: shift,
      hasBetterMove: !isBestMove && before.bestMove != null,
      winPercentBefore: beforeWin,
      winPercentAfter: afterWin,
      wasWinning: beforeWin >= 70,
      isBestMove: isBestMove,
    );

    final beforeCp = before.cp;
    final afterCp = after.cp;
    final cpLoss = beforeCp != null && afterCp != null
        ? (side == Side.white ? beforeCp - afterCp : afterCp - beforeCp).clamp(0, 10000)
        : 0;

    return ReviewMove(
      ply: ply,
      side: side,
      sanMove: branch.sanMove,
      path: path,
      winPercentBefore: beforeWin,
      winPercentAfter: afterWin,
      cpBefore: beforeCp,
      cpAfter: afterCp,
      centipawnLoss: cpLoss,
      accuracy: moveAccuracy(beforeWin - afterWin),
      verdict: verdict,
      bestMoveUci: before.bestMove?.uci,
    );
  }

  /// Stops the batch and leaves the engine free for the board.
  void cancel() {
    _cancelled = true;
    unawaited(_subscription?.cancel());
    _evaluator?.stop();
    if (ref.mounted) {
      state = const AsyncData(GameReviewState(status: .cancelled));
    }
  }
}
