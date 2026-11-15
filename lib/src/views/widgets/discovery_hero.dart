import 'package:flutter/material.dart';

import '../../models/game_deal.dart';

class DiscoveryHero extends StatelessWidget {
  const DiscoveryHero({
    super.key,
    required this.offerCount,
    required this.storeCount,
    required this.onExplore,
    this.featured,
  });

  final int offerCount, storeCount;
  final GameDeal? featured;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final image = featured?.imageUrl;
    const backdrop = Color(0xFF171421);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: backdrop)),
          if (image != null)
            Positioned.fill(
              child: Image.network(
                image,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                cacheWidth: 1280,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    backdrop,
                    backdrop.withValues(alpha: image == null ? .92 : .84),
                    const Color(0x80302A55),
                  ],
                  stops: const [0, .38, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    featured?.title ?? 'Ofertas de jogos',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: const Color(0xFFF8F7FF),
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    featured == null
                        ? '$offerCount ofertas em $storeCount lojas'
                        : '${featured!.formattedPrice} · $offerCount ofertas em $storeCount lojas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFDED9EF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onExplore,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFBCACFF),
                      foregroundColor: const Color(0xFF211743),
                      shadowColor: colors.shadow,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Explorar ofertas'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
