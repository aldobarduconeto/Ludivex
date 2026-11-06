import 'package:flutter/material.dart';

import '../../models/library_game.dart';

class LibraryGameCard extends StatelessWidget {
  const LibraryGameCard({
    super.key,
    required this.game,
    required this.busy,
    required this.unavailableLabel,
    required this.onPlay,
    required this.onEdit,
    required this.onRemove,
  });
  final LibraryGame game;
  final bool busy;
  final String? unavailableLabel;
  final VoidCallback onPlay, onEdit, onRemove;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: c.secondary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: c.secondary, size: 27),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Opções de ${game.title}',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onRemove(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar jogo')),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remover da biblioteca'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                game.source.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.secondary,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w700,
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
                  onPressed: busy || unavailableLabel != null ? null : onPlay,
                  icon: Icon(
                    busy ? Icons.hourglass_top : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    busy ? 'Iniciando…' : unavailableLabel ?? 'Jogar',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
