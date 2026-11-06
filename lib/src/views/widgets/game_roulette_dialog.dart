import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/library_game.dart';
import '../../services/library_service.dart';

class GameRouletteDialog extends StatefulWidget {
  const GameRouletteDialog({super.key, required this.games});
  final List<LibraryGame> games;

  static Future<void> show(BuildContext context, List<LibraryGame> games) {
    if (games.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum jogo instalado para sortear. Escaneie sua biblioteca primeiro!',
          ),
        ),
      );
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GameRouletteDialog(games: games),
    );
  }

  @override
  State<GameRouletteDialog> createState() => _GameRouletteDialogState();
}

class _GameRouletteDialogState extends State<GameRouletteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final Random _random = Random();
  late LibraryGame _selectedGame;
  bool _isSpinning = false;
  Timer? _spinTimer;
  int _spinTicks = 0;

  @override
  void initState() {
    super.initState();
    _selectedGame = widget.games[_random.nextInt(widget.games.length)];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _spin();
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (widget.games.isEmpty) return;
    setState(() {
      _isSpinning = true;
      _spinTicks = 0;
    });

    _spinTimer?.cancel();
    int intervalMs = 60;

    void tick() {
      _spinTicks++;
      setState(() {
        _selectedGame = widget.games[_random.nextInt(widget.games.length)];
      });

      if (_spinTicks < 18) {
        intervalMs = (intervalMs * 1.08).toInt().clamp(60, 400);
        _spinTimer = Timer(Duration(milliseconds: intervalMs), tick);
      } else {
        setState(() => _isSpinning = false);
        _controller.forward(from: 0.0);
      }
    }

    _spinTimer = Timer(Duration(milliseconds: intervalMs), tick);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.casino_rounded,
                      color: c.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Roleta Gamer',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Sem saber o que jogar hoje?',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Game Display Box
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isSpinning
                        ? c.primary.withValues(alpha: 0.5)
                        : c.primary,
                    width: _isSpinning ? 1 : 2,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          _selectedGame.local
                              ? Icons.computer_rounded
                              : Icons.sports_esports_rounded,
                          size: 42,
                          color: c.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedGame.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _isSpinning ? c.onSurfaceVariant : c.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _selectedGame.source.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSpinning ? null : _spin,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Girar de novo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSpinning
                          ? null
                          : () {
                              Navigator.pop(context);
                              LibraryService.instance.launch(_selectedGame);
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Jogar Agora'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
