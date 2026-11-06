import 'dart:convert';
import 'dart:io';
import '../models/library_game.dart';
import 'game_scan_result.dart';
import 'windows_game_scanner.dart';

bool get supportsGameScan =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

String _join(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';

// These readers also accept explicit folders so tests never inspect real libraries.
Future<GameScanResult> scanGameFolders({
  required Iterable<String> steamRoots,
  required Iterable<String> epicManifestFolders,
}) async {
  final games = <String, LibraryGame>{};
  final warnings = <String>[];
  final roots = steamRoots.map((p) => Directory(p).absolute.path).toSet();
  final checked = <String>{};
  while (roots.isNotEmpty) {
    final root = roots.first;
    roots.remove(root);
    final key = Platform.isWindows ? root.toLowerCase() : root;
    if (!checked.add(key)) continue;
    final apps = Directory(_join(root, 'steamapps'));
    try {
      if (!await apps.exists()) continue;
      final folders = File(_join(apps.path, 'libraryfolders.vdf'));
      if (await folders.exists()) {
        final text = await folders.readAsString();
        for (final match in RegExp(
          r'"path"\s+"((?:\\.|[^"\\])*)"',
        ).allMatches(text)) {
          roots.add(Directory(match[1]!.replaceAll(r'\\', r'\')).absolute.path);
        }
      }
      await for (final entity in apps.list(followLinks: false)) {
        if (entity is! File ||
            !RegExp(r'appmanifest_\d+\.acf$').hasMatch(entity.path))
          continue;
        try {
          final fields = <String, String>{
            for (final match in RegExp(
              r'"([^"\r\n]+)"\s+"([^"\r\n]*)"',
            ).allMatches(await entity.readAsString()))
              match[1]!: match[2]!,
          };
          final id = fields['appid'];
          final title = fields['name'];
          final folder = fields['installdir'];
          final flags = int.tryParse(fields['StateFlags'] ?? '') ?? 0;
          if (id == null ||
              !RegExp(r'^\d+$').hasMatch(id) ||
              title == null ||
              title.trim().isEmpty ||
              folder == null ||
              (flags & 4) == 0 ||
              !await Directory(
                _join(_join(apps.path, 'common'), folder),
              ).exists())
            continue;
          games['steam:$id'] = LibraryGame(
            id: 'scan:steam:$id',
            title: title,
            source: 'Steam',
            target: 'steam://rungameid/$id',
          );
        } on Object {
          warnings.add('Não foi possível ler um dos registros da Steam.');
        }
      }
    } on FileSystemException {
      warnings.add('Sem acesso a uma das pastas da Steam.');
    }
  }
  for (final folder in epicManifestFolders.toSet()) {
    try {
      final dir = Directory(folder);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.item')) continue;
        try {
          final data =
              jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          final app = data['AppName'] as String?;
          final title = data['DisplayName'] as String?;
          final location = data['InstallLocation'] as String?;
          if (app == null ||
              app.isEmpty ||
              title == null ||
              title.trim().isEmpty ||
              location == null ||
              data['bIsIncompleteInstall'] == true ||
              data['bIsApplication'] == false ||
              !await Directory(location).exists())
            continue;
          final namespace = data['CatalogNamespace'] as String?;
          final catalog = data['CatalogItemId'] as String?;
          final launchId =
              namespace != null &&
                  namespace.isNotEmpty &&
                  catalog != null &&
                  catalog.isNotEmpty
              ? '$namespace:$catalog:$app'
              : app;
          // Epic Games Protocol Activation: apps/[SandboxID]:[CatalogID]:[ArtifactId].
          games['epic:$launchId'] = LibraryGame(
            id: 'scan:epic:$launchId',
            title: title,
            source: 'Epic Games',
            target:
                'com.epicgames.launcher://apps/${Uri.encodeComponent(launchId)}?action=launch&silent=true',
          );
        } on Object {
          warnings.add('Não foi possível ler um dos registros da Epic Games.');
        }
      }
    } on FileSystemException {
      warnings.add('Sem acesso à pasta de registros da Epic Games.');
    }
  }
  return GameScanResult(
    games.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
    warnings: warnings.toSet().toList(),
  );
}

Future<GameScanResult> scanInstalledGames({String? steamFolder}) async {
  if (!supportsGameScan)
    throw UnsupportedError('A busca requer um computador.');
  final env = Platform.environment;
  final roots = <String>[];
  final epic = <String>[];
  if (steamFolder != null && steamFolder.trim().isNotEmpty)
    roots.add(steamFolder.trim());
  if (Platform.isWindows) {
    for (final variable in [
      'ProgramFiles(x86)',
      'ProgramFiles',
      'LOCALAPPDATA',
    ]) {
      final path = env[variable];
      if (path != null) roots.add(_join(path, 'Steam'));
    }
    for (var letter = 67; letter <= 90; letter++) {
      roots.add('${String.fromCharCode(letter)}:\\SteamLibrary');
      roots.add('${String.fromCharCode(letter)}:\\Steam');
    }
    final programData = env['ProgramData'];
    if (programData != null)
      epic.add(_join(programData, r'Epic\EpicGamesLauncher\Data\Manifests'));
  } else {
    final home = env['HOME'];
    if (home != null) {
      roots.addAll(
        Platform.isMacOS
            ? [_join(home, 'Library/Application Support/Steam')]
            : [
                _join(home, '.local/share/Steam'),
                _join(home, '.steam/steam'),
                _join(
                  home,
                  '.var/app/com.valvesoftware.Steam/.local/share/Steam',
                ),
              ],
      );
    }
  }
  final result = await scanGameFolders(
    steamRoots: roots,
    epicManifestFolders: epic,
  );
  if (!Platform.isWindows) return result;
  try {
    final windows = await scanWindowsGames();
    return GameScanResult(
      [
        ...result.games,
        ...windows.games,
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())),
      warnings: [...result.warnings, ...windows.warnings],
    );
  } on Object {
    return GameScanResult(
      result.games,
      warnings: [
        ...result.warnings,
        'Não foi possível concluir a busca da Xbox Store, EA e Ubisoft. Você ainda pode adicionar esses jogos manualmente.',
      ],
    );
  }
}
