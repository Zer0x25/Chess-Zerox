import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/preloaded_data.dart';
import 'package:lichess_mobile/src/model/game/game_repository.dart';
import 'package:lichess_mobile/src/model/import/chesscom_client.dart';
import 'package:lichess_mobile/src/model/import/import_repository.dart';
import 'package:lichess_mobile/src/network/http.dart';

/// Provides the repository used to list and fetch games from the supported platforms.
final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return ImportRepository(ref.watch(gameRepositoryProvider));
}, name: 'ImportRepositoryProvider');

/// Client for the Chess.com Published-Data API.
///
/// The API asks clients to identify themselves, so this client has its own user agent instead of
/// the one shared by the rest of the app.
final chessComClientProvider = Provider<ChessComClient>((ref) {
  final packageInfo = ref.read(preloadedDataProvider).requireValue.packageInfo;
  final client = DefaultClient(
    ref.read(httpClientFactoryProvider)(),
    userAgent: 'ChessZerox/${packageInfo.version} (+https://chesszerox.app)',
  );
  ref.onDispose(client.close);
  return ChessComClient(client);
}, name: 'ChessComClientProvider');
