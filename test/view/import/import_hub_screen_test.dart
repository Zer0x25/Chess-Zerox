import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/view/import/import_hub_screen.dart';
import 'package:lichess_mobile/src/view/import/username_import_screen.dart';
import 'package:lichess_mobile/src/view/settings/import_data_screen.dart';

import '../../test_provider_scope.dart';

void main() {
  testWidgets('offers Lichess, Chess.com and PGN sources', (tester) async {
    final app = await makeTestProviderScopeApp(tester, home: const ImportHubScreen());
    await tester.pumpWidget(app);

    expect(find.text('Lichess'), findsOneWidget);
    expect(find.text('Chess.com'), findsOneWidget);
    expect(find.text('Import PGN'), findsOneWidget);
  });

  testWidgets('opens the username import screen for Lichess', (tester) async {
    final app = await makeTestProviderScopeApp(tester, home: const ImportHubScreen());
    await tester.pumpWidget(app);

    await tester.tap(find.text('Lichess'));
    await tester.pumpAndSettle();

    expect(find.byType(UsernameImportScreen), findsOneWidget);
    expect(find.text('Import from Lichess'), findsOneWidget);
  });

  testWidgets('opens saved import data', (tester) async {
    final app = await makeTestProviderScopeApp(tester, home: const ImportHubScreen());
    await tester.pumpWidget(app);
    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportDataScreen), findsOneWidget);
  });
}
