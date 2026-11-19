import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/import/username_import_screen.dart';
import 'package:lichess_mobile/src/view/more/import_pgn_screen.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';
import 'package:material_ui/material_ui.dart';

/// Entry point for importing a game from Lichess, Chess.com or a PGN.
class const ImportHubScreen({super.key}) extends StatelessWidget {
  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const ImportHubScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return PlatformScaffold(
      appBar: const PlatformAppBar(title: Text('Import game')),
      body: ListView(
        children: [
          ListSection(
            header: const SettingsSectionTitle('Sources'),
            hasLeading: true,
            children: [
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Lichess'),
                subtitle: const Text('Import public games by username'),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () =>
                    Navigator.of(context).push(UsernameImportScreen.buildRoute(source: .lichess)),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: const Text('Chess.com'),
                subtitle: const Text('Import public games by username'),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () =>
                    Navigator.of(context).push(UsernameImportScreen.buildRoute(source: .chessCom)),
              ),
            ],
          ),
          ListSection(
            header: const SettingsSectionTitle('Local'),
            hasLeading: true,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(context.l10n.importPgn),
                subtitle: const Text('Paste a PGN or open a file'),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () => Navigator.of(context).push(ImportPgnScreen.buildRoute()),
              ),
            ],
          ),
          Padding(
            padding: Styles.bodySectionPadding,
            child: Text(
              'Games are fetched from the public Lichess and Chess.com APIs. '
              'This app is not affiliated with either platform.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
