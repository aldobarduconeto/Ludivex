import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'preferences_store.dart';
import 'store_process_stub.dart' if (dart.library.io) 'store_process_io.dart';

export 'store_process_stub.dart'
    if (dart.library.io) 'store_process_io.dart'
    show supportsStoreAccounts, supportsCompatibility;

part 'heroic_store_backends.dart';

enum GameRuntime { system, wine, proton }

class LauncherSettings {
  const LauncherSettings({
    this.legendary = 'legendary',
    this.gogdl = 'gogdl',
    this.nile = 'nile',
    this.installFolder = '',
    this.runtime = GameRuntime.system,
    this.wine = 'wine',
    this.umu = 'umu-run',
    this.proton = '',
    this.prefix = '',
  });

  final String gogdl, nile;
  final String legendary, installFolder, wine, umu, proton, prefix;
  final GameRuntime runtime;
  static const _key = 'launcher.settings.v1';

  Map<String, String> get environment => {
    if (runtime != GameRuntime.system && prefix.isNotEmpty)
      'WINEPREFIX': prefix,
    if (runtime == GameRuntime.proton)
      'PROTONPATH': proton.isEmpty ? 'GE-Proton' : proton,
  };

  static Future<LauncherSettings> load() async {
    final raw = await (await PreferencesStore.open()).getString(_key);
    if (raw == null) return const LauncherSettings();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return LauncherSettings(
      legendary: json['legendary'] as String,
      gogdl: json['gogdl'] as String? ?? 'gogdl',
      nile: json['nile'] as String? ?? 'nile',
      installFolder: json['installFolder'] as String,
      runtime: GameRuntime.values.byName(json['runtime'] as String),
      wine: json['wine'] as String,
      umu: json['umu'] as String,
      proton: json['proton'] as String,
      prefix: json['prefix'] as String,
    );
  }

  Future<void> save() async {
    final prefs = await PreferencesStore.open();
    await PreferencesStore.write(
      () => prefs.setString(
        _key,
        jsonEncode({
          'legendary': legendary,
          'gogdl': gogdl,
          'nile': nile,
          'installFolder': installFolder,
          'runtime': runtime.name,
          'wine': wine,
          'umu': umu,
          'proton': proton,
          'prefix': prefix,
        }),
      ),
    );
  }

  Future<bool> launchWindowsExecutable(String path) async {
    if (!supportsCompatibility ||
        runtime == GameRuntime.system ||
        !path.toLowerCase().endsWith('.exe')) {
      return false;
    }
    if (!await storeFileExists(path)) {
      throw StateError('Executável não encontrado.');
    }
    await startStoreProcess(
      runtime == GameRuntime.proton ? umu : wine,
      [path],
      environment: environment,
      workingDirectory: path.substring(0, path.lastIndexOf('/') + 1),
      detached: true,
    );
    return true;
  }

  Future<void> checkRuntime() async {
    if (!supportsCompatibility || runtime == GameRuntime.system) return;
    if (runtime == GameRuntime.proton &&
        proton.isNotEmpty &&
        (!proton.startsWith('/') || !await storeFileExists('$proton/proton'))) {
      throw StateError('Pasta do Proton inválida.');
    }
    final process = await startStoreProcess(
      runtime == GameRuntime.proton ? umu : wine,
      ['--version'],
    );
    await Future.wait([
      process.stdout.drain<void>(),
      process.stderr.drain<void>(),
      process.stdin.close(),
    ]);
    if (await process.exitCode != 0) {
      throw StateError('Runtime indisponível.');
    }
  }
}

typedef StoreGame = ({String id, String title, bool installed});

class EpicStore implements DesktopStore {
  const EpicStore(this.settings);

  final LauncherSettings settings;

  Future<Uri> loginUrl() async => Uri.https('www.epicgames.com', '/id/login', {
    'redirectUrl': Uri.https('www.epicgames.com', '/id/api/redirect', {
      'clientId': '34a02cf8f4414e29b15921876da36f9a',
      'responseType': 'code',
    }).toString(),
  });

  Future<String> _run(
    List<String> args, {
    void Function(String)? onProgress,
    bool saveOutput = false,
  }) => _runStore(
    settings.legendary,
    ['-y', ...args],
    onProgress: onProgress,
    saveOutput: saveOutput,
  );
  Future<void> signIn(String code) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code)) {
      throw const FormatException('Código de autorização inválido.');
    }
    await _run(['auth', '--code', code]);
  }

  Future<void> signOut() async => _run(['auth', '--delete']);

  Future<List<dynamic>> _list(String command) async =>
      jsonDecode(await _run([command, '--json'], saveOutput: true)) as List;

  Future<List<StoreGame>> games() async {
    final owned = await _list('list');
    final installed = await _list('list-installed');
    final installedIds = installed
        .whereType<Map>()
        .map((item) => item['app_name'])
        .toSet();
    return [
      for (final item in owned.whereType<Map>())
        if (item['app_name'] case final String id)
          if (item['app_title'] case final String title)
            if (RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$').hasMatch(id) &&
                title.trim().isNotEmpty)
              (id: id, title: title, installed: installedIds.contains(id)),
    ];
  }

  Future<void> install(StoreGame game, void Function(String) onProgress) async {
    await _run([
      'install',
      game.id,
      if (settings.installFolder.isNotEmpty)
        '--base-path=${settings.installFolder}',
      '--skip-dlcs',
      '--skip-sdl',
    ], onProgress: onProgress);
    final installed = await _list('list-installed');
    if (!installed.whereType<Map>().any(
      (item) => item['app_name'] == game.id,
    )) {
      throw StateError('A instalação não apareceu na lista do Legendary.');
    }
  }

  Future<void> launch(String id) async {
    final installed = await _list('list-installed');
    if (!installed.whereType<Map>().any((item) => item['app_name'] == id)) {
      throw StateError('O jogo precisa ser instalado pelo Legendary.');
    }
    final runtime = supportsCompatibility
        ? settings.runtime
        : GameRuntime.system;
    final process = await startStoreProcess(settings.legendary, [
      'launch',
      id,
      if (runtime == GameRuntime.wine) ...[
        '--wine=${settings.wine}',
        if (settings.prefix.isNotEmpty) '--wine-prefix=${settings.prefix}',
      ],
      if (runtime == GameRuntime.proton) ...[
        '--no-wine',
        '--wrapper="${settings.umu.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"',
      ],
    ], environment: supportsCompatibility ? settings.environment : null);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    await process.stdin.close();
    if (await process.exitCode != 0) {
      throw StateError('O Legendary não conseguiu iniciar o jogo.');
    }
  }
}

Future<String> _runStore(
  String executable,
  List<String> args, {
  void Function(String)? onProgress,
  bool saveOutput = false,
  Map<String, String>? environment,
}) async {
  final process = await startStoreProcess(
    executable,
    args,
    environment: environment,
  );
  final output = StringBuffer();
  final stdout = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .forEach((chunk) {
        if (saveOutput) output.write(chunk);
      });
  final stderr = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .forEach((line) {
        final progress = RegExp(r'\b\d+(?:\.\d+)?%').firstMatch(line);
        if (progress != null) onProgress?.call(progress[0]!);
      });
  await Future.wait([stdout, stderr, process.stdin.close()]);
  if (await process.exitCode != 0) {
    throw StateError('O backend da loja não concluiu a operação.');
  }
  return output.toString();
}
