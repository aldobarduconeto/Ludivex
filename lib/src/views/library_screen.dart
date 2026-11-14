import 'package:flutter/material.dart';

import '../models/library_game.dart';
import '../services/library_service.dart';
import '../services/account_library.dart';
import '../services/desktop_store.dart';
import 'store_screen.dart';
import '../services/local_game_launcher.dart';
import '../services/game_scanner.dart';
import '../services/game_scan_result.dart';
import '../services/mobile_game_launcher.dart';
import 'widgets/page_components.dart';
import 'widgets/library_game_card.dart';
import 'widgets/game_roulette_dialog.dart';

import 'package:flutter/foundation.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.service,
    this.scanner,
    this.active = true,
  });
  final LibraryService service;
  final bool active;
  final Future<GameScanResult> Function({String? steamFolder})? scanner;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryFilter { all, favorites, recent, installed, available }

enum _LibrarySort {
  title('Nome (A–Z)'),
  reverseTitle('Nome (Z–A)'),
  store('Loja'),
  recent('Última inicialização');

  const _LibrarySort(this.label);
  final String label;
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  String _query = '';
  String? _source;
  _LibraryFilter _filter = _LibraryFilter.all;
  _LibrarySort? _sort;
  bool _listView = false;
  final _accounts = AccountLibrary.instance;
  bool _requestedAccounts = false;
  final _launching = <String>{};
  final _scanFolder = TextEditingController();
  final _searchController = TextEditingController();
  bool _scanning = false;
  bool _includeAndroidApps = false;
  GameScanResult? _mobileScan;
  String? _mobileScanError;
  bool _askingToScan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && MobileGameLauncher.supported) _scan(automatic: true);
      if (mounted) _loadAccountsOnEntry();
    });
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAccountsOnEntry();
      });
    }
  }

  void _loadAccountsOnEntry() {
    if (widget.active && supportsStoreAccounts && !_requestedAccounts) {
      _requestedAccounts = true;
      _refreshAccounts(automatic: true);
    }
  }

  Future<void> _refreshAccounts({bool automatic = false}) async {
    try {
      final failures = await _accounts.refresh();
      if (automatic || !mounted) return;
      _message(
        failures.isEmpty
            ? 'Bibliotecas das lojas atualizadas.'
            : 'Sem atualização para ${failures.map((store) => store.label).join(', ')}. Confira as conexões em Lojas e compatibilidade.',
      );
    } catch (_) {
      if (!automatic) _message('Não foi possível atualizar as lojas.');
    }
  }

  Future<void> _openStore(StoreProvider provider) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              StoreScreen(library: widget.service, initialProvider: provider),
        ),
      );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && MobileGameLauncher.supported) {
      _scan(automatic: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanFolder.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scan({bool automatic = false}) async {
    if (!mounted || _scanning || _askingToScan) return;
    if (!automatic) {
      _askingToScan = true;
      var includeOtherApps = _includeAndroidApps;
      try {
        final allowed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, updateDialog) => AlertDialog(
              title: Text(
                MobileGameLauncher.supported
                    ? 'Buscar jogos no celular'
                    : 'Permitir busca de jogos?',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MobileGameLauncher.supported
                            ? 'O ludivex vai consultar os aplicativos que podem ser abertos neste celular e identificar os classificados como jogos pelo Android. Você escolhe quais adicionar ao seu launcher.'
                            : 'O ludivex vai consultar os registros da Steam e da Epic Games. No Windows, também vai ler os atalhos da área de trabalho e do menu Iniciar para encontrar jogos da EA e Ubisoft, além dos jogos da Xbox Store registrados no sistema. Bibliotecas adicionais da Steam também serão consultadas.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'A busca fica neste dispositivo. Ao terminar, você escolhe adicionar todos os jogos encontrados ou somente alguns.',
                      ),
                      const SizedBox(height: 16),
                      if (MobileGameLauncher.supported)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Incluir aplicativos sem categoria de jogo',
                          ),
                          subtitle: const Text(
                            'Use se algum jogo não aparecer na busca padrão.',
                          ),
                          value: includeOtherApps,
                          onChanged: (value) => updateDialog(
                            () => includeOtherApps = value ?? false,
                          ),
                        )
                      else
                        TextField(
                          controller: _scanFolder,
                          decoration: const InputDecoration(
                            labelText:
                                'Pasta da Steam ou SteamLibrary (opcional)',
                            helperText: 'Informe se a instalação estiver em outro local.',
                            helperMaxLines: 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    MobileGameLauncher.supported
                        ? 'Buscar jogos'
                        : 'Permitir e buscar',
                  ),
                ),
              ],
            ),
          ),
        );
        if (allowed != true || !mounted) return;
        _includeAndroidApps = includeOtherApps;
      } finally {
        _askingToScan = false;
      }
    }
    setState(() {
      _scanning = true;
      _mobileScanError = null;
    });
    try {
      final scanner =
          widget.scanner ??
          (MobileGameLauncher.supported
              ? ({String? steamFolder}) => MobileGameLauncher.scan(
                  includeOtherApps: _includeAndroidApps,
                )
              : scanInstalledGames);
      final result = await scanner(steamFolder: _scanFolder.text);
      if (!mounted) return;
      setState(() {
        _scanning = false;
        if (MobileGameLauncher.supported) _mobileScan = result;
      });
      if (!automatic) await _reviewScan(result);
    } catch (_) {
      if (!mounted) return;
      if (automatic) {
        setState(
          () => _mobileScanError =
              'Não foi possível buscar os jogos do celular. Tente novamente.',
        );
      } else {
        _message(
          'Não foi possível concluir a busca. Verifique o acesso ao dispositivo e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  List<LibraryGame> _newGames(GameScanResult result) {
    final ids = widget.service.items.map((g) => g.id).toSet();
    final targets = widget.service.items.map((g) => g.target).toSet();
    return result.games
        .where((g) => !ids.contains(g.id) && !targets.contains(g.target))
        .toList();
  }

  Future<void> _reviewScan(GameScanResult result) {
    final fresh = _newGames(result);
    return showDialog<void>(
      context: context,
      builder: (_) => _ScanResultsDialog(
        service: widget.service,
        games: fresh,
        warnings: result.warnings,
        alreadyAdded: result.games.length - fresh.length,
        mobile: MobileGameLauncher.supported,
      ),
    );
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _launch(LibraryGame game, {bool fromAccount = false}) async {
    if (_launching.contains(game.id)) return;
    setState(() => _launching.add(game.id));
    try {
      if (fromAccount) await widget.service.importGames([game]);
      final recorded = await widget.service.launch(game);
      _message(
        recorded ? 'Inicialização solicitada para ${game.title}.' : 'Inicialização solicitada. Não foi possível atualizar o histórico.',
      );
    } catch (_) {
      _message(
        'Não foi possível iniciar ${game.title}. Confira o destino e se o jogo e o launcher estão instalados neste dispositivo.',
      );
    } finally {
      if (mounted) setState(() => _launching.remove(game.id));
    }
  }

  Future<void> _toggleFavorite(LibraryGame game) async {
    try {
      if (!widget.service.items.any((item) => item.id == game.id)) {
        await widget.service.importGames([game]);
      }
      await widget.service.setFavorite(game.id, !game.favorite);
    } catch (_) {
      _message('Não foi possível atualizar os favoritos.');
    }
  }

  String? _unavailableLabel(LibraryGame game) {
    if (LibraryGame.storeTarget(game.target) != null &&
        !supportsStoreAccounts) {
      return 'Disponível no computador';
    }
    if (LibraryGame.androidPackage(game.target) != null &&
        !MobileGameLauncher.supported) {
      return 'Disponível no Android';
    }
    if ((game.local && !supportsLocalGames) ||
        (LibraryGame.isWindowsAppTarget(game.target) && !supportsWindowsApps)) {
      return 'Disponível no computador';
    }
    return null;
  }

  Future<void> _details(
    LibraryGame game, {
    AccountGame? account,
    bool saved = true,
  }) => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final lastLaunch = game.lastLaunchedAt?.toLocal();
      final localization = MaterialLocalizations.of(dialogContext);
      final unavailable = _unavailableLabel(game);
      return AlertDialog(
        title: Text(game.title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.source),
                if (account != null)
                  Text(
                    account.game.installed
                        ? 'Instalado'
                        : 'Disponível para instalar',
                  ),
                const SizedBox(height: 16),
                const Text('Destino de inicialização'),
                SelectableText(game.target),
                const SizedBox(height: 16),
                const Text('Última solicitação de inicialização'),
                Text(
                  lastLaunch == null
                      ? 'Nenhuma registrada'
                      : '${localization.formatShortDate(lastLaunch)} · '
                            '${localization.formatTimeOfDay(TimeOfDay.fromDateTime(lastLaunch))}',
                ),
                if (unavailable != null) Text(unavailable),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          if (saved)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _edit(game);
              },
              child: const Text('Editar'),
            ),
          FilledButton.icon(
            onPressed: unavailable != null || _launching.contains(game.id)
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    if (account != null && !account.game.installed) {
                      _openStore(account.store);
                    } else {
                      _launch(game, fromAccount: !saved);
                    }
                  },
            icon: Icon(
              account != null && !account.game.installed
                  ? Icons.download_rounded
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              account != null && !account.game.installed
                  ? 'Ver instalação'
                  : 'Jogar',
            ),
          ),
        ],
      );
    },
  );

  Future<void> _edit([LibraryGame? game]) => showDialog<void>(
    context: context,
    builder: (_) => _LibraryGameDialog(service: widget.service, game: game),
  );

  Future<void> _remove(LibraryGame game) async {
    try {
      await widget.service.remove(game.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${game.title} removido da biblioteca.'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              try {
                await widget.service.save(game);
              } catch (_) {
                _message('Não foi possível restaurar o jogo.');
              }
            },
          ),
        ),
      );
    } catch (_) {
      _message('Não foi possível remover o jogo.');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.service, _accounts]),
    builder: (context, _) {
      final accounts = {
        if (supportsStoreAccounts)
          for (final entry in _accounts.games)
            entry.store.target(entry.game.id): entry,
      };
      final saved = {
        for (final game in widget.service.items) game.target: game,
      };
      final playable = widget.service.items
          .where(
            (game) =>
                accounts[game.target]?.game.installed != false &&
                _unavailableLabel(game) == null,
          )
          .toList();
      final all = [
        ...widget.service.items,
        for (final entry in accounts.entries)
          if (!saved.containsKey(entry.key))
            LibraryGame(
              id: entry.key,
              title: entry.value.game.title,
              source: entry.value.store.label,
              target: entry.key,
            ),
      ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final mobileGames = _mobileScan == null
          ? const <LibraryGame>[]
          : _newGames(_mobileScan!);
      final sources = all.map((g) => g.source).toSet().toList()..sort();
      final active = sources.contains(_source) ? _source : null;
      final games = all
          .where(
            (g) =>
                (active == null || g.source == active) &&
                g.title.toLowerCase().contains(_query) &&
                switch (_filter) {
                  _LibraryFilter.all => true,
                  _LibraryFilter.favorites => g.favorite,
                  _LibraryFilter.recent => g.lastLaunchedAt != null,
                  _LibraryFilter.installed =>
                    accounts[g.target]?.game.installed ?? false,
                  _LibraryFilter.available =>
                    accounts[g.target]?.game.installed == false,
                },
          )
          .toList();
      final sort =
          _sort ??
          (_filter == _LibraryFilter.recent
              ? _LibrarySort.recent
              : _LibrarySort.title);
      games.sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        final byStore = a.source.toLowerCase().compareTo(
          b.source.toLowerCase(),
        );
        final byRecent = (b.lastLaunchedAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.lastLaunchedAt?.millisecondsSinceEpoch ?? 0);
        return switch (sort) {
          _LibrarySort.title => byTitle,
          _LibrarySort.reverseTitle => -byTitle,
          _LibrarySort.store => byStore == 0 ? byTitle : byStore,
          _LibrarySort.recent => byRecent == 0 ? byTitle : byRecent,
        };
      });
      Widget gameTile(BuildContext context, int index) {
        final game = games[index];
        final account = accounts[game.target];
        final isSaved = saved.containsKey(game.target);
        final install = account?.game.installed == false;
        return LibraryGameCard(
          key: ValueKey(game.id),
          game: game,
          compact: _listView,
          busy: _launching.contains(game.id),
          unavailableLabel: _unavailableLabel(game),
          installAction: install,
          onPlay: () => install
              ? _openStore(account!.store)
              : _launch(game, fromAccount: !isSaved),
          onDetails: () => _details(game, account: account, saved: isSaved),
          onFavorite: () => _toggleFavorite(game),
          onEdit: isSaved ? () => _edit(game) : null,
          onRemove: isSaved ? () => _remove(game) : null,
        );
      }

      return CustomScrollView(
        key: const PageStorageKey('library'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biblioteca de jogos',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (supportsStoreAccounts)
                        OutlinedButton.icon(
                          onPressed: _accounts.loading
                              ? null
                              : _refreshAccounts,
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(
                            _accounts.loading
                                ? 'Atualizando lojas…'
                                : 'Atualizar jogos das contas',
                          ),
                        ),
                      if (supportsStoreAccounts)
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StoreScreen(library: widget.service),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Lojas e compatibilidade'),
                        ),
                      FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar jogo'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: playable.isEmpty
                            ? null
                            : () => GameRouletteDialog.show(context, playable),
                        icon: const Icon(Icons.casino_rounded),
                        label: const Text('Sortear jogo'),
                      ),
                      if (supportsGameScan || MobileGameLauncher.supported)
                        OutlinedButton.icon(
                          onPressed: _scanning ? null : _scan,
                          icon: _scanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.travel_explore),
                          label: Text(
                            _scanning
                                ? 'Buscando jogos…'
                                : MobileGameLauncher.supported
                                ? 'Adicionar jogos do celular'
                                : 'Importar jogos instalados',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (MobileGameLauncher.supported &&
                      (_mobileScan != null || _mobileScanError != null)) ...[
                    SectionPanel(
                      title: 'Jogos detectados no celular',
                      icon: Icons.phone_android_rounded,
                      children: [
                        Text(
                          _mobileScanError ??
                              '${mobileGames.length} ${mobileGames.length == 1 ? 'jogo novo encontrado' : 'jogos novos encontrados'}. Escolha quais adicionar à biblioteca.',
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _mobileScanError != null
                              ? OutlinedButton.icon(
                                  onPressed: _scanning
                                      ? null
                                      : () => _scan(automatic: true),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                )
                              : FilledButton.icon(
                                  onPressed: mobileGames.isEmpty
                                      ? null
                                      : () => _reviewScan(_mobileScan!),
                                  icon: const Icon(Icons.playlist_add),
                                  label: const Text(
                                    'Revisar jogos encontrados',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                  if (defaultTargetPlatform == TargetPlatform.iOS)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'No iPhone, adicione jogos por um link de abertura compatível fornecido pelo jogo. O iOS não permite listar todos os aplicativos instalados.',
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CollectionSearchField(
                            controller: _searchController,
                            hint: 'Buscar na biblioteca',
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (filter, label) in const [
                                (_LibraryFilter.all, 'Todos os jogos'),
                                (_LibraryFilter.favorites, 'Favoritos'),
                                (_LibraryFilter.recent, 'Recentes'),
                                if (supportsStoreAccounts) ...[
                                  (
                                    _LibraryFilter.installed,
                                    'Instalados pelas lojas',
                                  ),
                                  (_LibraryFilter.available, 'Para instalar'),
                                ],
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _filter == filter,
                                  onSelected: (_) =>
                                      setState(() => _filter = filter),
                                ),
                            ],
                          ),
                          if (sources.isNotEmpty) const SizedBox(height: 8),
                          if (sources.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Todas as plataformas'),
                                  selected: active == null,
                                  onSelected: (_) =>
                                      setState(() => _source = null),
                                ),
                                for (final source in sources)
                                  ChoiceChip(
                                    label: Text(source),
                                    selected: source == active,
                                    onSelected: (_) =>
                                        setState(() => _source = source),
                                  ),
                              ],
                            ),
                          if (all.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '${games.length} de ${all.length} jogos',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  PopupMenuButton<_LibrarySort>(
                                    tooltip: 'Ordenar jogos',
                                    initialValue: sort,
                                    onSelected: (value) =>
                                        setState(() => _sort = value),
                                    itemBuilder: (_) => [
                                      for (final option in _LibrarySort.values)
                                        PopupMenuItem(
                                          value: option,
                                          child: Text(option.label),
                                        ),
                                    ],
                                    icon: const Icon(Icons.sort_rounded),
                                  ),
                                  IconButton(
                                    tooltip: _listView
                                        ? 'Exibir grade'
                                        : 'Exibir lista',
                                    onPressed: () =>
                                        setState(() => _listView = !_listView),
                                    icon: Icon(
                                      _listView
                                          ? Icons.grid_view_rounded
                                          : Icons.view_list_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (games.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AppEmptyState(
                  icon: all.isEmpty
                      ? Icons.sports_esports_outlined
                      : Icons.search_off,
                  title: all.isEmpty
                      ? 'Sua biblioteca começa com seu primeiro jogo.'
                      : 'Nenhum jogo encontrado.',
                  description: all.isEmpty
                      ? MobileGameLauncher.supported
                            ? 'Encontre os jogos instalados no celular e escolha quais adicionar à sua coleção.'
                            : 'Adicione seus jogos ou busque instalações neste dispositivo para começar.'
                      : 'Experimente outra busca, plataforma ou filtro.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: _listView
                  ? SliverList.separated(
                      itemCount: games.length,
                      itemBuilder: gameTile,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    )
                  : SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.crossAxisExtent / 300)
                            .floor()
                            .clamp(1, 4);
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent:
                                    290 +
                                    (MediaQuery.textScalerOf(context).scale(1) -
                                                1)
                                            .clamp(0, 3) *
                                        130,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                              ),
                          itemCount: games.length,
                          itemBuilder: gameTile,
                        );
                      },
                    ),
            ),
        ],
      );
    },
  );
}

class _ScanResultsDialog extends StatefulWidget {
  const _ScanResultsDialog({
    required this.service,
    required this.games,
    required this.warnings,
    required this.alreadyAdded,
    this.mobile = false,
  });
  final LibraryService service;
  final List<LibraryGame> games;
  final List<String> warnings;
  final int alreadyAdded;
  final bool mobile;

  @override
  State<_ScanResultsDialog> createState() => _ScanResultsDialogState();
}

class _ScanResultsDialogState extends State<_ScanResultsDialog> {
  final _selected = <String>{};
  bool _saving = false;
  bool _choosing = false;
  String? _error;

  Future<void> _import(List<LibraryGame> games) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.importGames(games);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar os jogos. Tente novamente.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.games.isEmpty
            ? 'Busca concluída'
            : '${widget.games.length} jogos encontrados',
      ),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.games.isEmpty
                  ? widget.alreadyAdded > 0
                        ? 'Os jogos encontrados já estão na sua biblioteca.'
                        : widget.mobile
                        ? 'Nenhum jogo foi identificado. Tente buscar novamente incluindo aplicativos sem categoria de jogo.'
                        : 'Nenhum jogo instalado foi encontrado nas pastas consultadas. Você pode informar uma pasta da Steam na próxima busca ou adicionar jogos manualmente.'
                  : 'Quer adicionar todos ou escolher jogos específicos?',
            ),
            if (widget.alreadyAdded > 0)
              Text(
                '${widget.alreadyAdded} jogos já adicionados foram ignorados.',
              ),
            for (final warning in widget.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(warning),
              ),
            if (widget.games.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_choosing)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Selecionar todos (${_selected.length}/${widget.games.length})',
                  ),
                  value: _selected.length == widget.games.length,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _selected.clear();
                          if (value == true)
                            _selected.addAll(widget.games.map((g) => g.id));
                        }),
                ),
              Flexible(
                child: SizedBox(
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.games.length,
                    itemBuilder: (context, index) {
                      final game = widget.games[index];
                      return _choosing
                          ? CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(game.title),
                              subtitle: Text(game.source),
                              value: _selected.contains(game.id),
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() {
                                      if (value == true) {
                                        _selected.add(game.id);
                                      } else {
                                        _selected.remove(game.id);
                                      }
                                    }),
                            )
                          : ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.sports_esports_outlined,
                              ),
                              title: Text(game.title),
                              subtitle: Text(game.source),
                            );
                    },
                  ),
                ),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(widget.games.isEmpty ? 'Fechar' : 'Cancelar'),
        ),
        if (widget.games.isNotEmpty && !_choosing) ...[
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _choosing = true),
            child: const Text('Escolher jogos'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _import(widget.games),
            child: Text(_saving ? 'Adicionando…' : 'Adicionar todos'),
          ),
        ],
        if (_choosing)
          FilledButton(
            onPressed: _saving || _selected.isEmpty
                ? null
                : () => _import(
                    widget.games
                        .where((g) => _selected.contains(g.id))
                        .toList(),
                  ),
            child: Text(
              _saving
                  ? 'Adicionando…'
                  : 'Adicionar selecionados (${_selected.length})',
            ),
          ),
      ],
    ),
  );
}

class _LibraryGameDialog extends StatefulWidget {
  const _LibraryGameDialog({required this.service, this.game});
  final LibraryService service;
  final LibraryGame? game;
  @override
  State<_LibraryGameDialog> createState() => _LibraryGameDialogState();
}

class _LibraryGameDialogState extends State<_LibraryGameDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.game?.title);
  late final _source = TextEditingController(
    text:
        widget.game?.source ??
        (MobileGameLauncher.supported
            ? 'Android'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'iOS'
            : 'Steam'),
  );
  late final _target = TextEditingController(text: widget.game?.target);
  late bool _local = widget.game?.local ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save(
        LibraryGame(
          id:
              widget.game?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          source: _source.text.trim(),
          target: _target.text.trim(),
          local: _local,
        ),
        preserveActivity: widget.game != null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Tente novamente.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.game == null ? 'Adicionar à biblioteca' : 'Editar jogo',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cadastre seus jogos manualmente. Use um link de inicialização da biblioteca de origem ou um executável local.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Nome do jogo'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o nome do jogo.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _source,
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: 'Plataforma / biblioteca',
                    helperText: 'Selecione uma loja na seta ou digite outra.',
                    helperMaxLines: 2,
                    suffixIcon: PopupMenuButton<String>(
                      tooltip: 'Selecionar plataforma',
                      enabled: !_saving,
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (value) =>
                          setState(() => _source.text = value),
                      itemBuilder: (_) => [
                        for (final source in [
                          'Steam',
                          'Epic Games',
                          'Xbox Store',
                          'EA',
                          'Ubisoft Connect',
                          'GOG',
                          'Android',
                          'iOS',
                        ])
                          PopupMenuItem(value: source, child: Text(source)),
                      ],
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a plataforma.'
                      : null,
                ),
                const SizedBox(height: 16),
                if (supportsLocalGames || _local)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Executável ou atalho local'),
                    subtitle: Text(
                      supportsLocalGames
                          ? 'Iniciar um jogo instalado no computador'
                          : 'A execução local requer um computador',
                    ),
                    value: _local,
                    onChanged: _saving || (!supportsLocalGames && !_local)
                        ? null
                        : (value) => setState(() => _local = value),
                  ),
                TextFormField(
                  controller: _target,
                  enabled: !_saving,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _local
                        ? 'Caminho completo do executável ou atalho'
                        : 'Link de inicialização',
                    helperText: _local
                        ? r'Arquivo .exe ou atalho .lnk do Windows. Informe o caminho completo, sem aspas ou argumentos.'
                        : 'Cole o destino do atalho fornecido pelo launcher. Links de loja abrem a página de compra.',
                    helperMaxLines: 3,
                  ),
                  validator: (v) =>
                      LibraryGame.validateTarget(v ?? '', local: _local),
                ),
                const SizedBox(height: 16),
                const Text(
                  'O launcher correspondente deve estar instalado e conectado à sua conta. Adicionar aqui não instala nem compra o jogo.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando…' : 'Salvar jogo'),
        ),
      ],
    ),
  );
}
