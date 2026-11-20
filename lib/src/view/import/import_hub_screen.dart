import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/import/username_import_screen.dart';
import 'package:lichess_mobile/src/view/more/import_pgn_screen.dart';
import 'package:lichess_mobile/src/view/settings/import_data_screen.dart';
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
      appBar: PlatformAppBar(title: Text(context.l10n.mobileImportGame)),
      body: ListView(
        children: [
          ListSection(
            header: SettingsSectionTitle(context.l10n.mobileImportSources),
            hasLeading: true,
            children: [
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Lichess'),
                subtitle: Text(context.l10n.mobileImportByUsername),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () =>
                    Navigator.of(context).push(UsernameImportScreen.buildRoute(source: .lichess)),
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_outlined),
                title: const Text('Chess.com'),
                subtitle: Text(context.l10n.mobileImportByUsername),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () =>
                    Navigator.of(context).push(UsernameImportScreen.buildRoute(source: .chessCom)),
              ),
            ],
          ),
          ListSection(
            header: SettingsSectionTitle(context.l10n.mobileImportLocal),
            hasLeading: true,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: Text(context.l10n.importPgn),
                subtitle: Text(context.l10n.mobileImportPgnSubtitle),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () => Navigator.of(context).push(ImportPgnScreen.buildRoute()),
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(context.l10n.mobileImportData),
                trailing: isIOS ? const CupertinoListTileChevron() : null,
                onTap: () => Navigator.of(context).push(ImportDataScreen.buildRoute()),
              ),
            ],
          ),
          Padding(
            padding: Styles.bodySectionPadding,
            child: Text(
              context.l10n.mobileImportDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
