import 'package:flutter/material.dart';

import '../../models/library_game.dart';

class LibraryGameCard extends StatelessWidget {
  const LibraryGameCard({
    super.key,
    required this.game,
    required this.busy,
    required this.unavailableLabel,
    required this.onPlay,
    required this.onDetails,
    required this.onFavorite,
    required this.onEdit,
    required this.onRemove,
    this.installAction = false,
    this.compact = false,
  });
  final LibraryGame game;
  final bool busy;
  final String? unavailableLabel;
  final VoidCallback onPlay, onDetails, onFavorite;
  final VoidCallback? onEdit, onRemove;
  final bool installAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (compact) {
      return Card(
        child: ListTile(
          onTap: onDetails,
          title: Text(game.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            unavailableLabel ??
                (installAction
                    ? '${game.source} · Para instalar'
                    : game.source),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: game.favorite ? 'Remover dos favoritos' : 'Favoritar',
                onPressed: onFavorite,
                icon: Icon(
                  game.favorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                ),
              ),
              IconButton(
                tooltip: busy
                    ? 'Iniciando…'
                    : installAction
                    ? 'Ver instalação'
                    : 'Jogar',
                onPressed: busy || unavailableLabel != null ? null : onPlay,
                icon: Icon(
                  busy
                      ? Icons.hourglass_top
                      : installAction
                      ? Icons.download_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final android = LibraryGame.androidPackage(game.target) != null;
    final icon = android
        ? Icons.sports_esports_rounded
        : game.local
        ? Icons.computer_rounded
        : Icons.rocket_launch_outlined;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Ink(
        color: c.surface,
        child: Column(
          children: [
            Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.primaryContainer, c.surfaceContainerHigh],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onDetails,
                      child: SizedBox(
                        height: 92,
                        child: Center(
                          child: Icon(
                            icon,
                            color: c.onPrimaryContainer,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: game.favorite
                        ? 'Remover dos favoritos'
                        : 'Favoritar',
                    onPressed: onFavorite,
                    color: game.favorite ? c.primary : c.onSurfaceVariant,
                    icon: Icon(
                      game.favorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções de ${game.title}',
                    onSelected: (value) {
                      switch (value) {
                        case 'details':
                          onDetails();
                        case 'edit':
                          onEdit?.call();
                        case 'remove':
                          onRemove?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Detalhes'),
                      ),
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar jogo'),
                        ),
                      if (onRemove != null)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remover da biblioteca'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: c.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      android
                          ? 'Jogo do celular'
                          : game.local
                          ? 'Arquivo neste dispositivo'
                          : 'Abrir pela plataforma',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy || unavailableLabel != null
                            ? null
                            : onPlay,
                        icon: Icon(
                          busy
                              ? Icons.hourglass_top
                              : installAction
                              ? Icons.download_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          busy
                              ? 'Iniciando…'
                              : unavailableLabel ??
                                    (installAction
                                        ? 'Ver instalação'
                                        : 'Jogar'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
