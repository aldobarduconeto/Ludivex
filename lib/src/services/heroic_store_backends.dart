part of 'desktop_store.dart';

enum StoreProvider {
  epic('Epic Games', 'epic', 'Legendary'),
  gog('GOG', 'gog', 'gogdl'),
  amazon('Amazon Games', 'amazon', 'Nile'),
  ea('EA', 'ea', 'EA App');

  const StoreProvider(this.label, this.key, this.backend);
  final String label, key, backend;

  String target(String id) => 'ludivex-$key://$id';

  DesktopStore open(LauncherSettings settings) => switch (this) {
    epic => EpicStore(settings),
    gog => _GogStore(settings),
    amazon => _AmazonStore(settings),
    ea => _EaStore(settings),
  };
}

abstract interface class DesktopStore {
  LauncherSettings get settings;
  Future<Uri> loginUrl();
  Future<void> signIn(String code);
  Future<void> signOut();
  Future<List<StoreGame>> games();
  Future<void> install(StoreGame game, void Function(String) onProgress);
  Future<void> launch(String id);
}

extension on LauncherSettings {
  List<String> get wrapperOptions => !supportsCompatibility
      ? const []
      : switch (runtime) {
          GameRuntime.system => const [],
          GameRuntime.wine => [
            '--wine=$wine',
            if (prefix.isNotEmpty) '--wine-prefix=$prefix',
          ],
          GameRuntime.proton => [
            '--no-wine',
            '--wrapper="${umu.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"',
          ],
        };
}

final _validIdRegex = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$');
final _gogNumericRegex = RegExp(r'^\d+$');

bool _validId(String id) => _validIdRegex.hasMatch(id);

Future<void> _launchBackend(
  String binary,
  List<String> args,
  Map<String, String> environment,
) async {
  final process = await startStoreProcess(
    binary,
    args,
    environment: environment,
  );
  unawaited(process.stdout.drain<void>());
  unawaited(process.stderr.drain<void>());
  await process.stdin.close();
  if (await process.exitCode != 0) {
    throw StateError('O backend não conseguiu iniciar o jogo.');
  }
}

class _AmazonStore implements DesktopStore {
  _AmazonStore(this.settings);

  @override
  final LauncherSettings settings;
  Map<String, dynamic>? _login;
  Future<String> get _directory => storeDataDirectory('amazon');

  Future<Map<String, String>> _environment() async => {
    'NILE_CONFIG_PATH': await _directory,
  };

  Future<String> _run(
    List<String> args, {
    void Function(String)? progress,
  }) async => _runStore(
    settings.nile,
    args,
    environment: await _environment(),
    saveOutput: progress == null,
    onProgress: progress,
  );

  @override
  Future<Uri> loginUrl() async {
    _login = null;
    final data = jsonDecode(
      await _run(['auth', '--login', '--non-interactive']),
    ) as Map<String, dynamic>;
    final url = Uri.parse(data['url'] as String);
    if (url.scheme != 'https' ||
        (url.host != 'amazon.com' && !url.host.endsWith('.amazon.com'))) {
      throw const FormatException('Página de login inválida.');
    }
    _login = data;
    return url;
  }

  @override
  Future<void> signIn(String code) async {
    final data = _login;
    _login = null;
    if (data == null) throw StateError('Abra o login no navegador primeiro.');
    await _run([
      'register',
      '--code=$code',
      '--client-id=${data['client_id']}',
      '--code-verifier=${data['code_verifier']}',
      '--serial=${data['serial']}',
    ]);
  }

  @override
  Future<void> signOut() async {
    _login = null;
    await _run(['auth', '--logout']);
  }

  Future<Set<String>> _installed() async {
    final file = await readStoreFile('${await _directory}/nile/installed.json');
    return {
      for (final item in (jsonDecode(file ?? '[]') as List).whereType<Map>())
        if (item['id'] case final String id) id,
    };
  }

  @override
  Future<List<StoreGame>> games() async {
    final status = jsonDecode(await _run(['auth', '--status'])) as Map;
    if (status['LoggedIn'] != true) throw StateError('Conecte a conta Amazon.');
    await _run(['library', 'sync']);
    final file = await readStoreFile('${await _directory}/nile/library.json');
    final installed = await _installed();
    return [
      for (final item in (jsonDecode(file ?? '[]') as List).whereType<Map>())
        if (item['product'] case final Map product)
          if (product['id'] case final String id)
            if (product['title'] case final String title)
              if (_validId(id) && title.trim().isNotEmpty)
                (id: id, title: title, installed: installed.contains(id)),
    ];
  }

  @override
  Future<void> install(StoreGame game, void Function(String) onProgress) async {
    await _run([
      'install',
      game.id,
      if (settings.installFolder.isNotEmpty)
        '--base-path=${settings.installFolder}',
    ], progress: onProgress);
    if (!(await _installed()).contains(game.id)) {
      throw StateError('A instalação não apareceu na lista do Nile.');
    }
  }

  @override
  Future<void> launch(String id) async {
    if (!(await _installed()).contains(id)) {
      throw StateError('Instale o jogo pelo Nile.');
    }
    await _launchBackend(
      settings.nile,
      ['launch', id, ...settings.wrapperOptions],
      {
        ...await _environment(),
        if (supportsCompatibility) ...settings.environment,
      },
    );
  }
}

class _GogStore implements DesktopStore {
  const _GogStore(this.settings);

  @override
  final LauncherSettings settings;
  Future<String> get _directory => storeDataDirectory('gog');

  Future<String> _run(
    List<String> args, {
    void Function(String)? progress,
  }) async {
    final directory = await _directory;
    return _runStore(
      settings.gogdl,
      ['--auth-config-path', '$directory/auth.json', ...args],
      environment: {'GOGDL_CONFIG_PATH': directory},
      saveOutput: progress == null,
      onProgress: progress,
    );
  }

  @override
  Future<Uri> loginUrl() async => Uri.https('auth.gog.com', '/auth', {
    'client_id': '46899977096215655',
    'redirect_uri': 'https://embed.gog.com/on_login_success?origin=client',
    'response_type': 'code',
    'layout': 'galaxy',
  });

  @override
  Future<void> signIn(String code) async {
    await _run(['auth', '--code=$code']);
  }

  @override
  Future<void> signOut() async =>
      deleteStoreFile('${await _directory}/auth.json');

  Future<Map> _get(Uri url, String token) async {
    final response = await http
        .get(url, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200)
      throw StateError('A API da GOG recusou a consulta.');
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
  }

  String _installKey(String id) => 'launcher.gog.install.$id';

  Future<String?> _installedPath(String id) async =>
      (await PreferencesStore.open()).getString(_installKey(id));

  Future<bool> _hasGame(String path, String id) => storeFileExists(
    gogPlatform == 'osx'
        ? '$path/Contents/Resources/goggame-$id.info'
        : '$path/goggame-$id.info',
  );

  @override
  Future<List<StoreGame>> games() async {
    final credentials = jsonDecode(await _run(['auth'])) as Map;
    final user = credentials['user_id'] as String;
    final token = credentials['access_token'] as String;
    final ids = <String>{};
    final pages = <String>{};
    String? page;
    do {
      final data = await _get(
        Uri.https('galaxy-library.gog.com', '/users/$user/releases', {
          if (page != null) 'page_token': page,
        }),
        token,
      );
      for (final item in (data['items'] as List).whereType<Map>()) {
        final id = item['external_id'].toString();
        if (item['platform_id'] == 'gog' && _gogNumericRegex.hasMatch(id)) {
          ids.add(id);
        }
      }
      page = data['next_page_token'] as String?;
    } while (page != null && page.isNotEmpty && pages.add(page));

    final games = <StoreGame>[];
    final products = ids.toList();
    for (var offset = 0; offset < products.length; offset += 8) {
      final batch = await Future.wait(
        products.skip(offset).take(8).map((id) async {
          final product = await _get(
            Uri.https('api.gog.com', '/products/$id'),
            token,
          );
          final title = product['title'] as String? ?? 'GOG $id';
          final path = await _installedPath(id);
          return (
            id: id,
            title: title,
            installed: path != null && await _hasGame(path, id),
          );
        }),
      );
      games.addAll(batch);
    }
    return games
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  @override
  Future<void> install(StoreGame game, void Function(String) onProgress) async {
    final base = settings.installFolder.isEmpty
        ? await storeDataDirectory('games')
        : settings.installFolder;
    final destination = '$base/GOG-${game.id}';
    await _run([
      'download',
      game.id,
      '--path=$destination',
      '--platform=$gogPlatform',
      '--skip-dlcs',
    ], progress: onProgress);
    String? path;
    for (final candidate in [
      destination,
      ...await storeSubdirectories(destination),
    ]) {
      if (await _hasGame(candidate, game.id)) {
        path = candidate;
        break;
      }
    }
    if (path == null) {
      throw StateError(
        'A instalação não contém os dados de inicialização da GOG.',
      );
    }
    final prefs = await PreferencesStore.open();
    await PreferencesStore.write(
      () => prefs.setString(_installKey(game.id), path!),
    );
  }

  @override
  Future<void> launch(String id) async {
    final path = await _installedPath(id);
    if (path == null || !await _hasGame(path, id)) {
      throw StateError('Instale o jogo pelo gogdl.');
    }
    final directory = await _directory;
    await _launchBackend(
      settings.gogdl,
      [
        '--auth-config-path',
        '$directory/auth.json',
        'launch',
        path,
        id,
        '--platform=$gogPlatform',
        ...settings.wrapperOptions,
      ],
      {
        'GOGDL_CONFIG_PATH': directory,
        if (supportsCompatibility) ...settings.environment,
      },
    );
  }
}

class _EaStore implements DesktopStore {
  const _EaStore(this.settings);

  @override
  final LauncherSettings settings;
  Future<String> get _directory => storeDataDirectory('ea');

  @override
  Future<Uri> loginUrl() async => Uri.https('accounts.ea.com', '/connect/auth', {
    'client_id': 'ORIGIN_JS_SDK',
    'response_type': 'code',
    'redirect_uri': 'https://www.ea.com/login_check',
    'display': 'junoWeb/login',
    'locale': 'pt_BR',
  });

  @override
  Future<void> signIn(String code) async {
    String token = code;
    String? refresh;
    try {
      final response = await http.post(
        Uri.https('accounts.ea.com', '/connect/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': 'ORIGIN_JS_SDK',
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': 'https://www.ea.com/login_check',
        },
      ).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['access_token'] is String) {
          token = data['access_token'] as String;
          refresh = data['refresh_token'] as String?;
        }
      }
    } catch (_) {
      // Keep code directly if token endpoint was unneeded or deferred
    }

    final directory = await _directory;
    await writeStoreFile(
      '$directory/auth.json',
      jsonEncode({
        'access_token': token,
        if (refresh != null) 'refresh_token': refresh,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> signOut() async =>
      deleteStoreFile('${await _directory}/auth.json');

  @override
  Future<List<StoreGame>> games() async {
    final rawAuth = await readStoreFile('${await _directory}/auth.json');
    if (rawAuth == null) throw StateError('Conecte a conta EA primeiro.');
    final authData = jsonDecode(rawAuth) as Map<String, dynamic>;
    final token = authData['access_token'] as String;

    final games = <String, StoreGame>{};

    String? userId;
    try {
      final pidResponse = await http.get(
        Uri.https('gateway.ea.com', '/proxy/identity/pids/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
      if (pidResponse.statusCode == 200) {
        final pidData = jsonDecode(pidResponse.body) as Map<String, dynamic>;
        userId = pidData['pid']?['pidId']?.toString();
      }
    } catch (_) {}

    if (userId == null || userId.isEmpty) {
      try {
        final userinfoResponse = await http.get(
          Uri.https('accounts.ea.com', '/connect/userinfo'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 20));
        if (userinfoResponse.statusCode == 200) {
          final infoData = jsonDecode(userinfoResponse.body) as Map<String, dynamic>;
          userId = infoData['sub']?.toString();
        }
      } catch (_) {}
    }

    if (userId != null && userId.isNotEmpty) {
      try {
        final entResponse = await http.get(
          Uri.https('api1.origin.com', '/ecommerce2/consolidatedentitlements/$userId', {
            'machine_hash': '1',
          }),
          headers: {
            'Accept': 'application/vnd.origin.v3+json',
            'AuthToken': token,
          },
        ).timeout(const Duration(seconds: 25));
        if (entResponse.statusCode == 200) {
          final entData = jsonDecode(entResponse.body) as Map<String, dynamic>;
          final entitlements = entData['entitlements'] as List? ?? [];
          for (final item in entitlements.whereType<Map>()) {
            final offerId = item['offerId']?.toString() ?? '';
            final title = (item['productTitle']?.toString() ??
                    item['originDisplayType']?.toString() ??
                    offerId)
                .trim();
            if (offerId.isNotEmpty && _validId(offerId)) {
              games[offerId] = (
                id: offerId,
                title: title.isEmpty ? offerId : title,
                installed: false,
              );
            }
          }
        }
      } catch (_) {}
    }

    final cachedLibrary = await readStoreFile('${await _directory}/library.json');
    if (cachedLibrary != null) {
      try {
        final cached = jsonDecode(cachedLibrary) as List;
        for (final item in cached.whereType<Map>()) {
          final id = item['id']?.toString() ?? '';
          final title = item['title']?.toString() ?? '';
          final installed = item['installed'] == true;
          if (id.isNotEmpty && _validId(id) && title.isNotEmpty) {
            games[id] = (id: id, title: title, installed: installed);
          }
        }
      } catch (_) {}
    }

    if (games.isNotEmpty) {
      await writeStoreFile(
        '${await _directory}/library.json',
        jsonEncode([
          for (final g in games.values)
            {'id': g.id, 'title': g.title, 'installed': g.installed},
        ]),
      );
    }

    return games.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  @override
  Future<void> install(StoreGame game, void Function(String) onProgress) async {
    await launch(game.id);
  }

  @override
  Future<void> launch(String id) async {
    final uri = Uri.parse('origin2://game/launch?offerIds=$id');
    final eaUri = Uri.parse('link2ea://launch/$id');
    try {
      if (await launchUrl(eaUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (settings.ea.isNotEmpty) {
      try {
        await startStoreProcess(settings.ea, [id], detached: true);
        return;
      } catch (_) {}
    }
    throw StateError('Não foi possível iniciar o jogo pela EA App.');
  }
}
