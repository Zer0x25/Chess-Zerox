import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/db/database.dart';
import 'package:lichess_mobile/src/model/import/imported_game.dart';
import 'package:lichess_mobile/src/model/import/imported_game_store.dart';
import 'package:lichess_mobile/src/view/settings/import_data_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_provider_scope.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
    addTearDown(db.close);
  });

  testWidgets('lists saved usernames and deletes their games', (tester) async {
    final store = ImportedGameStore(db);
    await store.insertGames(
      source: ImportSource.chessCom,
      username: 'hikaru',
      games: [
        ImportedGame(
          source: ImportSource.chessCom,
          id: 'g1',
          white: 'Hikaru',
          black: 'Rival',
          result: '1-0',
          playedAt: DateTime.utc(2026, 1, 1),
          pgn: '*',
        ),
        ImportedGame(
          source: ImportSource.chessCom,
          id: 'g2',
          white: 'Hikaru',
          black: 'Rival',
          result: '1-0',
          playedAt: DateTime.utc(2026, 1, 2),
          pgn: '*',
        ),
      ],
    );

    final app = await makeTestProviderScopeApp(
      tester,
      home: const ImportDataScreen(),
      overrides: {databaseProvider: databaseProvider.overrideWith((ref) => db)},
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Import data'), findsOneWidget);
    expect(find.text('hikaru'), findsOneWidget);
    expect(find.textContaining('2 games'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete saved data?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No saved data'), findsOneWidget);
    expect(await store.listGames(), isEmpty);
  });
}
