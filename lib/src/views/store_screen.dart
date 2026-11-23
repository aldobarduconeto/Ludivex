import 'package:flutter/material.dart';

import '../models/library_game.dart';
import '../services/account_library.dart';
import '../services/desktop_store.dart';
import '../services/library_service.dart';
import 'store_login_screen.dart';
import 'widgets/page_components.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.library,
    this.initialProvider = StoreProvider.epic,
  });

  final LibraryService library;
  final StoreProvider initialProvider;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _legendary = TextEditingController();
  final _gogdl = TextEditingController();
  final _nile = TextEditingController();
  final _ea = TextEditingController();
  final _folder = TextEditingController();
  final _wine = TextEditingController();
  final _umu = TextEditingController();
  final _proton = TextEditingController();
  final _prefix = TextEditingController();
  final _code = TextEditingController();
  var _runtime = GameRuntime.system;
  List<StoreGame>? _games;
  late var _provider = widget.initialProvider;

  void _publish(List<StoreGame> games) {
    _games = games;
    AccountLibrary.instance.replace(_provider, games);
  }

  bool _busy = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    final cached = AccountLibrary.instance.games
        .where((entry) => entry.store == _provider)
        .map((entry) => entry.game)
        .toList();
    if (cached.isNotEmpty) _games = cached;
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await LauncherSettings.load();
      if (!mounted) return;
      _legendary.text = settings.legendary;
      _gogdl.text = settings.gogdl;
      _nile.text = settings.nile;
      _ea.text = settings.ea;
      _folder.text = settings.installFolder;
      _wine.text = settings.wine;
      _umu.text = settings.umu;
      _proton.text = settings.proton;
      _prefix.text = settings.prefix;
      _runtime = settings.runtime;
    } catch (_) {
      _status = 'Não foi possível carregar as configurações.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _legendary.dispose();
    _gogdl.dispose();
    _nile.dispose();
    _ea.dispose();
    _folder.dispose();
    _wine.dispose();
    _umu.dispose();
    _proton.dispose();
    _prefix.dispose();
    _code.dispose();
    super.dispose();
  }

  LauncherSettings get _settings => LauncherSettings(
    legendary: _legendary.text.trim().isEmpty
        ? 'legendary'
        : _legendary.text.trim(),
    gogdl: _gogdl.text.trim().isEmpty ? 'gogdl' : _gogdl.text.trim(),
    nile: _nile.text.trim().isEmpty ? 'nile' : _nile.text.trim(),
    ea: _ea.text.trim().isEmpty ? 'EADesktop.exe' : _ea.text.trim(),
    installFolder: _folder.text.trim(),
    wine: _wine.text.trim().isEmpty ? 'wine' : _wine.text.trim(),
    umu: _umu.text.trim().isEmpty ? 'umu-run' : _umu.text.trim(),
    proton: _proton.text.trim(),
    prefix: _prefix.text.trim(),
    runtime: _runtime,
  );

  Future<void> _run(
    String status,
    Future<void> Function(DesktopStore) action, {
    String failure = 'Confira o executável da loja, a conta e a conexão.',
    String? success = 'Operação concluída.',
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      final settings = _settings;
      await settings.save();
      await action(_provider.open(settings));
      if (mounted && success != null) setState(() => _status = success);
    } catch (_) {
      if (mounted) setState(() => _status = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLogin() => _run(
    'Abrindo login…',
    (store) async {
      final uri = await store.loginUrl();
      if (!mounted) return;
      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => StoreLoginScreen(provider: _provider, loginUrl: uri),
        ),
      );
      if (!mounted) return;
      if (code == null) {
        setState(() => _status = 'Login encerrado.');
        return;
      }
      setState(() => _status = 'Sincronizando biblioteca…');
      await store.signIn(code);
      if (!mounted) return;
      _publish(await store.games());
      if (mounted) setState(() => _status = 'Biblioteca da loja carregada.');
    },
    failure: 'Não foi possível conectar a conta. Confira o executável da loja e tente novamente.',
    success: null,
  );
  Future<void> _add(StoreGame game) => _run(
    game.installed ? 'Adicionando jogo…' : 'Instalando ${game.title}…',
    (store) async {
      if (!game.installed) {
        await store.install(game, (progress) {
          if (mounted) {
            setState(() => _status = 'Instalando ${game.title} · $progress');
          }
        });
        if (mounted) {
          setState(() {
            _publish([
              for (final item in _games!)
                if (item.id == game.id)
                  (id: item.id, title: item.title, installed: true)
                else
                  item,
            ]);
          });
        }
      }
      await widget.library.importGames([
        LibraryGame(
          id: _provider.target(game.id),
          title: game.title,
          source: _provider.label,
          target: _provider.target(game.id),
        ),
      ]);
    },
    failure:
        'Não foi possível instalar ou adicionar o jogo. Confira a pasta, '
        'o espaço livre e a sessão da loja.',
    success: '${game.title} está na Biblioteca.',
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      enabled: !_busy,
      autocorrect: false,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final games = _games;
    final libraryTargets = {
      for (final game in widget.library.items) game.target,
    };
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Lojas e compatibilidade')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList.list(
                    children: [
                      SectionPanel(
                        title: 'Conta da loja',
                        icon: Icons.manage_accounts_outlined,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final provider in StoreProvider.values)
                                ChoiceChip(
                                  label: Text(provider.label),
                                  selected: _provider == provider,
                                  onSelected: _busy
                                      ? null
                                      : (_) {
                                          if (_provider == provider) return;
                                          final games = AccountLibrary
                                              .instance
                                              .games
                                              .where(
                                                (entry) =>
                                                    entry.store == provider,
                                              )
                                              .map((entry) => entry.game)
                                              .toList();
                                          setState(() {
                                            _provider = provider;
                                            _games = games.isEmpty
                                                ? null
                                                : games;
                                            _status = null;
                                          });
                                        },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _field(switch (_provider) {
                            StoreProvider.epic => _legendary,
                            StoreProvider.gog => _gogdl,
                            StoreProvider.amazon => _nile,
                            StoreProvider.ea => _ea,
                          }, 'Executável · ${_provider.backend}'),
                          _field(_folder, 'Pasta de instalação (opcional)'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _busy ? null : _openLogin,
                                icon: const Icon(Icons.login_rounded),
                                label: Text('Entrar na ${_provider.label}'),
                              ),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        'Carregando jogos…',
                                        (store) async {
                                          _publish(await store.games());
                                        },
                                        success:
                                            'Biblioteca da loja carregada.',
                                      ),
                                child: const Text('Carregar jogos'),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run('Encerrando sessão…', (
                                        store,
                                      ) async {
                                        await store.signOut();
                                        _games = null;
                                        AccountLibrary.instance.replace(
                                          _provider,
                                          [],
                                        );
                                      }, success: 'Sessão encerrada.'),
                                child: const Text('Desconectar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (supportsCompatibility) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Wine e Proton',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<GameRuntime>(
                          initialValue: _runtime,
                          decoration: const InputDecoration(
                            labelText: 'Modo de execução',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: GameRuntime.system,
                              child: Text('Padrão'),
                            ),
                            DropdownMenuItem(
                              value: GameRuntime.wine,
                              child: Text('Wine'),
                            ),
                            DropdownMenuItem(
                              value: GameRuntime.proton,
                              child: Text('Proton via umu'),
                            ),
                          ],
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _runtime = value!),
                        ),
                        const SizedBox(height: 12),
                        if (_runtime == GameRuntime.wine)
                          _field(_wine, 'Executável do Wine'),
                        if (_runtime == GameRuntime.proton) ...[
                          _field(_umu, 'Executável do umu-run'),
                          _field(
                            _proton,
                            'Pasta do Proton (opcional)',
                            hint: 'GE-Proton',
                          ),
                        ],
                        if (_runtime != GameRuntime.system)
                          _field(_prefix, 'Prefixo Wine (opcional)'),
                        if (_runtime != GameRuntime.system)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      'Verificando runtime…',
                                      (store) => store.settings.checkRuntime(),
                                      failure: 'Confira o executável e a pasta do Proton.',
                                      success: 'Executável disponível.',
                                    ),
                              child: const Text('Verificar runtime'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  'Salvando…',
                                  (_) async {},
                                  failure: 'Não foi possível salvar as configurações.',
                                  success: 'Configurações salvas.',
                                ),
                          child: const Text('Salvar configurações'),
                        ),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      if (_status != null)
                        Semantics(liveRegion: true, child: Text(_status!)),
                      if (_games != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Jogos da conta (${_games!.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),
                ),
                if (games != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList.separated(
                      itemCount: games.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final game = games[index];
                        final added =
                            game.installed &&
                            libraryTargets.contains(_provider.target(game.id));
                        return Card(
                          child: ListTile(
                            title: Text(game.title),
                            subtitle: Text(
                              game.installed ? 'Instalado' : 'Disponível',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: _busy || added
                                  ? null
                                  : () => _add(game),
                              child: Text(
                                added
                                    ? 'Na biblioteca'
                                    : game.installed
                                    ? 'Adicionar'
                                    : 'Instalar',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
