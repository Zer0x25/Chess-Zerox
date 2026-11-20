import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/review/game_review.dart';
import 'package:lichess_mobile/src/model/review/game_review_controller.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// Report of a local, on-device review of the game open in the analysis board.
class const GameReviewScreen({required final AnalysisOptions options, super.key})
    extends ConsumerWidget {
  static Route<dynamic> buildRoute({required AnalysisOptions options}) {
    return buildScreenRoute(screen: GameReviewScreen(options: options));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(gameReviewControllerProvider(options));

    return PlatformScaffold(
      appBar: PlatformAppBar(title: Text(context.l10n.mobileReviewGame)),
      body: SafeArea(
        child: switch (asyncState) {
          AsyncError(:final error) => _Message(message: '$error'),
          AsyncData(:final value) => switch (value.status) {
            .running => _Progress(
              progress: value.progress,
              evaluated: value.evaluated,
              total: value.total,
              onCancel: () => ref.read(gameReviewControllerProvider(options).notifier).cancel(),
            ),
            .done => switch (value.review) {
              final review? => _Report(review: review, options: options),
              null => _Message(message: context.l10n.mobileReviewEmpty),
            },
            .cancelled => _Message(message: context.l10n.mobileReviewCancelled),
            .failed => _Message(message: context.l10n.mobileReviewFailed),
          },
          _ => const Center(child: CircularProgressIndicator.adaptive()),
        },
      ),
    );
  }
}

class const _Progress({
  required final double progress,
  required final int evaluated,
  required final int total,
  required final VoidCallback onCancel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Styles.bodySectionPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text(
              context.l10n.mobileReviewAnalysing,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('$evaluated / $total'),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onCancel, child: Text(context.l10n.mobileReviewCancel)),
          ],
        ),
      ),
    );
  }
}

class const _Message({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Styles.bodySectionPadding,
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class const _Report({required final GameReview review, required final AnalysisOptions options})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final keyMoments = review.keyMoments;
    return ListView(
      padding: Styles.bodySectionPadding,
      children: [
        Row(
          children: [
            Expanded(
              child: _ScoreCard(
                title: context.l10n.white,
                accuracy: review.whiteAccuracy,
                acpl: review.whiteAcpl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScoreCard(
                title: context.l10n.black,
                accuracy: review.blackAccuracy,
                acpl: review.blackAcpl,
              ),
            ),
          ],
        ),
        if (keyMoments.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.l10n.mobileReviewKeyMoments, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...keyMoments.map((move) => _MoveTile(move: move, options: options)),
        ],
        const SizedBox(height: 20),
        Text(context.l10n.mobileReviewAllMoves, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...review.moves.map((move) => _MoveTile(move: move, options: options)),
        const SizedBox(height: 20),
        Text(context.l10n.mobileReviewNote, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class const _ScoreCard({
  required final String title,
  required final double accuracy,
  required final int acpl,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${context.l10n.mobileReviewAccuracy} ${accuracy.toStringAsFixed(1)}%'),
            Text('${context.l10n.mobileReviewAcpl} $acpl'),
          ],
        ),
      ),
    );
  }
}

class const _MoveTile({required final ReviewMove move, required final AnalysisOptions options})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (move.verdict) {
      .star => context.l10n.mobileReviewStar,
      .missedChance => context.l10n.mobileReviewMissed,
      .best => context.l10n.mobileReviewBest,
      .excellent => context.l10n.mobileReviewExcellent,
      .good => context.l10n.mobileReviewGood,
      .inaccuracy => context.l10n.mobileReviewInaccuracy,
      .mistake => context.l10n.mobileReviewMistake,
      .blunder => context.l10n.mobileReviewBlunder,
    };

    return ListTile(
      dense: true,
      leading: CircleAvatar(child: Text('${move.ply}')),
      title: Text('${move.sanMove.san} · $label'),
      subtitle: Text(
        '${move.winPercentBefore.toStringAsFixed(0)}% → '
        '${move.winPercentAfter.toStringAsFixed(0)}% · '
        '${context.l10n.mobileReviewAccuracy} ${move.accuracy.toStringAsFixed(0)}%',
      ),
      onTap: () {
        Navigator.of(context).pop();
        ref
            .read(analysisControllerProvider(options).notifier)
            .jumpToNthNodeOnMainline(move.ply - 1);
      },
    );
  }
}
