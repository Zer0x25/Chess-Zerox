/// Where an imported game comes from.
enum ImportSource() {
  lichess,
  chessCom;

  String get label => switch (this) {
    .lichess => 'Lichess',
    .chessCom => 'Chess.com',
  };
}

/// A game that has been listed by an external source, and may be opened in the analysis board.
///
/// The PGN is optional because some sources only return it when the game is opened. Sources that
/// already have it (Chess.com monthly archives, PGN import) can set it directly.
class const ImportedGame({
  required final ImportSource source,

  /// Identifier in the source platform.
  required final String id,

  required final String white,
  required final String black,
  final int? whiteRating,
  final int? blackRating,

  /// The result as a PGN result: `1-0`, `0-1`, `1/2-1/2` or `*`.
  required final String result,

  final DateTime? playedAt,

  /// Human readable speed, such as `blitz` or `rapid`.
  final String? speed,

  /// Variant as reported by the source, if any.
  final String? variant,

  /// The full PGN, when the source already provided it.
  final String? pgn,

  final String? url,
}) {
  bool get isStandardVariant {
    final value = variant?.toLowerCase();
    return value == null || value == 'standard' || value == 'chess';
  }

  String get playersLabel => '$white vs $black';

  String get ratingsLabel {
    final whiteLabel = whiteRating != null ? '$whiteRating' : '?';
    final blackLabel = blackRating != null ? '$blackRating' : '?';
    return '$whiteLabel vs $blackLabel';
  }
}
