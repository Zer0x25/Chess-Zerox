import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lichess_mobile/src/model/import/imported_game.dart';

/// The API is documented at https://www.chess.com/announcements/view/published-data-api
const _chessComBaseHost = 'api.chess.com';
const _chessComUserAgent = 'ChessZerox/0.1 (contact: dev@chesszerox.local)';
const _cacheTtl = Duration(hours: 12);

/// Thrown when Chess.com cannot be reached or returns an unexpected response.
class const ChessComException(final String message) implements Exception {
  const new playerNotFound() : this('Player not found on Chess.com.');

  const new rateLimited()
    : this('Chess.com is rate limiting requests. Wait a minute and try again.');

  @override
  String toString() => message;
}

/// A small, serial client for the Chess.com Published-Data API.
///
/// The API asks for serial requests, a recognizable User-Agent and caching. This client keeps one
/// request in flight at a time, reuses cached responses for 12 hours and honors `ETag` and
/// `Last-Modified`.
class ChessComClient(final http.Client _client, {final DateTime Function() _clock = DateTime.now}) {
  final Map<String, _CacheEntry> _cache = {};

  Future<void> _queue = Future.value();

  /// Lists the most recent standard games of [username].
  ///
  /// [months] is the number of monthly archives to scan, starting from the most recent one. The
  /// API only exposes archives by month, so this is the smallest number of requests that can find
  /// recent games without downloading a player's whole history.
  Future<List<ImportedGame>> fetchRecentGames(String username, {int months = 3, int max = 30}) {
    return _enqueue(() async {
      final trimmedUsername = username.trim();
      if (trimmedUsername.isEmpty || max <= 0) return const <ImportedGame>[];

      final archivesUri = Uri.https(
        _chessComBaseHost,
        '/pub/player/${Uri.encodeComponent(trimmedUsername)}/games/archives',
      );
      final archivesJson = await _getJson(archivesUri);
      final archives =
          (archivesJson['archives'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[];

      if (archives.isEmpty) return const <ImportedGame>[];

      final games = <ImportedGame>[];
      for (final archive in archives.reversed.take(months)) {
        final monthJson = await _getJson(Uri.parse(archive));
        games.addAll(parseChessComMonth(monthJson));
      }

      games.sort((a, b) {
        final aDate = a.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return games.take(max).toList(growable: false);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final cacheKey = uri.toString();
    final cached = _cache[cacheKey];
    if (cached != null && _clock().difference(cached.fetchedAt) < _cacheTtl) {
      return _decodeJson(cached.body);
    }

    final etag = cached?.etag;
    final lastModified = cached?.lastModified;
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': _chessComUserAgent,
        'If-None-Match': ?etag,
        'If-Modified-Since': ?lastModified,
      },
    );

    if (response.statusCode == 304 && cached != null) {
      _cache[cacheKey] = cached.withFetchedAt(_clock());
      return _decodeJson(cached.body);
    }

    if (response.statusCode == 404) {
      throw const ChessComException.playerNotFound();
    }
    if (response.statusCode == 429) {
      throw const ChessComException.rateLimited();
    }
    if (response.statusCode != 200) {
      throw ChessComException('Chess.com returned HTTP ${response.statusCode}.');
    }

    final body = response.body;
    _cache[cacheKey] = _CacheEntry(
      fetchedAt: _clock(),
      body: body,
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'],
    );
    return _decodeJson(body);
  }
}

Map<String, dynamic> _decodeJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const ChessComException('Unexpected response from Chess.com.');
  }
  return decoded;
}

/// Parses the response of `/pub/player/{username}/games/{year}/{month}`.
///
/// Variants are skipped for now: the local review assumes standard chess. Games without a PGN are
/// skipped as well, because there is nothing to analyze.
List<ImportedGame> parseChessComMonth(Map<String, dynamic> json) {
  final rawGames = json['games'];
  if (rawGames is! List<dynamic>) return const <ImportedGame>[];

  return rawGames
      .whereType<Map<String, dynamic>>()
      .map(_parseGame)
      .nonNulls
      .toList(growable: false);
}

ImportedGame? _parseGame(Map<String, dynamic> json) {
  final rules = json['rules'];
  if (rules is String && rules != 'chess') return null;

  final pgn = json['pgn'];
  if (pgn is! String || pgn.trim().isEmpty) return null;

  final white = _asMap(json['white']);
  final black = _asMap(json['black']);
  final url = json['url'] is String ? json['url'] as String : null;
  final endTime = json['end_time'];
  final playedAt = endTime is int
      ? DateTime.fromMillisecondsSinceEpoch(endTime * 1000, isUtc: true).toLocal()
      : null;
  final uuid = json['uuid'] is String ? json['uuid'] as String : null;

  return ImportedGame(
    source: .chessCom,
    id: uuid ?? url ?? pgn.hashCode.toString(),
    white: _string(white['username']) ?? 'White',
    black: _string(black['username']) ?? 'Black',
    whiteRating: _int(white['rating']),
    blackRating: _int(black['rating']),
    result: _pgnResult(pgn) ?? _resultFromPlayers(white, black),
    playedAt: playedAt,
    speed: _string(json['time_class']),
    variant: rules is String ? rules : null,
    pgn: pgn,
    url: url,
  );
}

Map<String, dynamic> _asMap(Object? value) {
  return value is Map<String, dynamic> ? value : const <String, dynamic>{};
}

String? _string(Object? value) => value is String && value.isNotEmpty ? value : null;

int? _int(Object? value) => value is int ? value : null;

String? _pgnResult(String pgn) {
  final match = RegExp(r'^\[Result\s+"([^"]+)"\]', multiLine: true).firstMatch(pgn);
  final result = match?.group(1);
  return result == '1-0' || result == '0-1' || result == '1/2-1/2' || result == '*' ? result : null;
}

String _resultFromPlayers(Map<String, dynamic> white, Map<String, dynamic> black) {
  if (white['result'] == 'win') return '1-0';
  if (black['result'] == 'win') return '0-1';
  return '1/2-1/2';
}

class const _CacheEntry({
  required final DateTime fetchedAt,
  required final String body,
  final String? etag,
  final String? lastModified,
}) {
  _CacheEntry withFetchedAt(DateTime value) {
    return _CacheEntry(fetchedAt: value, body: body, etag: etag, lastModified: lastModified);
  }
}
