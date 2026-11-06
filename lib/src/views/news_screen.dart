import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_transport.dart';
import '../services/game_news_service.dart';
import '../services/library_service.dart';
import '../services/preferences_store.dart';

typedef _NewsGame = ({String id, String title, String source, String? target});

class NewsScreen extends StatefulWidget {
  const NewsScreen({
    super.key,
    required this.library,
    required this.transport,
    required this.active,
  });

  final LibraryService library;
  final ApiTransport transport;
  final bool active;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  static const _followedKey = 'news.followed_titles.v1';
  List<String> _followed = const [];
  bool _busy = true;
  bool _storageError = false;
  _NewsGame? _selected;

  List<_NewsGame> get _games => [
    for (final game in widget.library.items)
      (
        id: 'library:${game.id}',
        title: game.title,
        source: game.source,
        target: game.target,
      ),
    for (final title in _followed)
      (id: 'followed:$title', title: title, source: 'Seguindo', target: null),
  ];
  Future<List<GameNews>?>? _news;

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_libraryChanged);
    _syncSelection();
    _loadFollowed();
  }

  @override
  void didUpdateWidget(covariant NewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) {
      oldWidget.library.removeListener(_libraryChanged);
      widget.library.addListener(_libraryChanged);
    }
    if (oldWidget.transport != widget.transport || !widget.active) {
      _news = null;
    }
    _syncSelection();
  }

  @override
  void dispose() {
    widget.library.removeListener(_libraryChanged);
    super.dispose();
  }

  void _libraryChanged() => setState(_syncSelection);

  void _syncSelection() {
    final games = _games;
    final index = games.indexWhere((game) => game.id == _selected?.id);
    final game = games.isEmpty ? null : games[index < 0 ? 0 : index];
    if (game != _selected) {
      _selected = game;
      _news = null;
    }
    if (widget.active && game != null) {
      _news ??= GameNewsService(widget.transport)
          .load(game.title, target: game.target);
    }
  }

  Future<void> _loadFollowed() async {
    setState(() => _busy = true);
    try {
      final storage = await PreferencesStore.open();
      final titles = await storage.getStringList(_followedKey);
      if (!mounted) return;
      setState(() {
        _followed = titles ?? const [];
        _storageError = false;
        _syncSelection();
      });
    } on Exception {
      if (mounted) setState(() => _storageError = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFollowed() async {
    var title = '';
    final added = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seguir jogo'),
        content: TextField(
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Título do jogo na Steam',
          ),
          onChanged: (value) => title = value,
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, title.trim()),
            child: const Text('Seguir'),
          ),
        ],
      ),
    );
    if (!mounted || added == null || added.isEmpty) return;
    for (final existing in _followed) {
      if (existing.toLowerCase() == added.toLowerCase()) {
        setState(() => _selectFollowed(existing));
        return;
      }
    }
    await _saveFollowed([..._followed, added], select: added);
  }

  void _selectFollowed(String title) {
    _selected = _games.firstWhere((game) => game.id == 'followed:$title');
    _news = null;
    _syncSelection();
  }

  Future<void> _saveFollowed(List<String> titles, {String? select}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final storage = await PreferencesStore.open();
      await PreferencesStore.write(
        () => storage.setStringList(_followedKey, titles),
      );
      if (!mounted) return;
      setState(() {
        _followed = titles;
        if (select == null) {
          _syncSelection();
        } else {
          _selectFollowed(select);
        }
      });
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar os jogos seguidos.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openArticle(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } on Exception {
      // The platform may have no browser available.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir a notícia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();

    final games = _games;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Notícias dos jogos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Selecione um jogo para ver as publicações da Steam.'),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : _storageError
                  ? _loadFollowed
                  : _addFollowed,
              icon: Icon(_storageError ? Icons.refresh : Icons.add),
              label: Text(
                _storageError ? 'Recarregar jogos seguidos' : 'Seguir jogo',
              ),
            ),
          ),
          if (games.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: DropdownButton<_NewsGame>(
                    value: _selected,
                    isExpanded: true,
                    items: [
                      for (final game in games)
                        DropdownMenuItem(
                          value: game,
                          child: Text(
                            '${game.title} · ${game.source}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (game) {
                      if (game == null || game == _selected) return;
                      setState(() {
                        _selected = game;
                        _news = GameNewsService(widget.transport)
                            .load(game.title, target: game.target);
                      });
                    },
                  ),
                ),
                if (_selected?.target == null)
                  IconButton(
                    tooltip: 'Deixar de seguir',
                    onPressed: _busy || _storageError
                        ? null
                        : () => _saveFollowed(
                            _followed
                                .where((title) => title != _selected?.title)
                                .toList(),
                          ),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
              ],
            ),
          if (games.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Siga um jogo ou adicione-o à biblioteca para ver notícias.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: FutureBuilder<List<GameNews>?>(
                future: _news,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _news = null;
                          _syncSelection();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Falha ao carregar. Tentar novamente',
                        ),
                      ),
                    );
                  }
                  final articles = snapshot.data;
                  if (articles == null || articles.isEmpty) {
                    return Center(
                      child: Text(
                        articles == null
                            ? 'Nenhuma correspondência única na Steam para este jogo.'
                            : 'Nenhuma notícia disponível para este jogo.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    key: ValueKey(_selected?.id),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return Card(
                        child: ListTile(
                          title: Text(article.title),
                          subtitle: Text(
                            MaterialLocalizations.of(context)
                                .formatCompactDate(article.date),
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => _openArticle(article.url),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
