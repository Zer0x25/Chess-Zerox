import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_preferences.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/view/import/username_import_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../network/fake_http_client_factory.dart';
import '../../test_provider_scope.dart';

const _archivesPath = '/pub/player/hikaru/games/archives';
const _novemberPath = '/pub/player/hikaru/games/2026/11';

const _archivesJson = '''
{
  "archives": [
    "https://api.chess.com/pub/player/hikaru/games/2026/11"
  ]
}
''';

const _novemberJson = '''
{
  "games": [
    {
      "uuid": "november-rapid",
      "url": "https://www.chess.com/game/live/1",
      "pgn": "[Event \\"Live Chess\\"]\\n[White \\"Hikaru\\"]\\n[Black \\"Rival\\"]\\n[Result \\"1-0\\"]\\n\\n1. e4 e5 2. Nf3 Nc6 3. Bb5 1-0",
      "time_class": "rapid",
      "rules": "chess",
      "end_time": 1763500000,
      "white": {"username": "Hikaru", "rating": 3300, "result": "win"},
      "black": {"username": "Rival", "rating": 3100, "result": "resigned"}
    }
  ]
}
''';

MockClient _mockChessCom({List<String>? requestedPaths}) {
  return MockClient((request) async {
    requestedPaths?.add(request.url.path);
    return switch (request.url.path) {
      _archivesPath => http.Response(_archivesJson, 200),
      _novemberPath => http.Response(_novemberJson, 200),
      _ => http.Response('', 404),
    };
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MockClient client,
  Map<String, Object>? defaultPreferences,
}) async {
  final app = await makeTestProviderScopeApp(
    tester,
    home: const UsernameImportScreen(source: ImportSource.chessCom),
    overrides: {
      httpClientFactoryProvider: httpClientFactoryProvider.overrideWith(
        (ref) => FakeHttpClientFactory(() => client),
      ),
    },
    defaultPreferences: defaultPreferences,
  );
  await tester.pumpWidget(app);
}

void main() {
  testWidgets('searches the Chess.com public archives and lists standard games', (tester) async {
    final requestedPaths = <String>[];
    await _pumpScreen(tester, client: _mockChessCom(requestedPaths: requestedPaths));

    await tester.enterText(find.byType(TextField), 'hikaru');
    await tester.tap(find.text('Search games'));
    await tester.pumpAndSettle();

    expect(requestedPaths.where((path) => path.startsWith('/pub/')), [
      _archivesPath,
      _novemberPath,
    ]);
    expect(find.text('Hikaru vs Rival'), findsOneWidget);
    expect(find.textContaining('1-0'), findsOneWidget);
    expect(find.textContaining('rapid'), findsOneWidget);
  });

  testWidgets('opens a listed game in the analysis board', (tester) async {
    await _pumpScreen(
      tester,
      client: _mockChessCom(),
      defaultPreferences: {
        PrefCategory.engineEvaluation.storageKey: jsonEncode(
          EngineEvaluationPrefState.defaults.copyWith(isEnabled: false).toJson(),
        ),
      },
    );

    await tester.enterText(find.byType(TextField), 'hikaru');
    await tester.tap(find.text('Search games'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hikaru vs Rival'));
    await tester.pumpAndSettle();

    expect(find.byType(UsernameImportScreen), findsNothing);
  });

  testWidgets('shows an error state when the player does not exist', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));
    await _pumpScreen(tester, client: client);

    await tester.enterText(find.byType(TextField), 'unknown');
    await tester.tap(find.text('Search games'));
    await tester.pumpAndSettle();

    expect(find.text('Player not found on Chess.com.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
