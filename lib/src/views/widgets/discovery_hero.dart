import 'package:flutter/material.dart';

import '../../models/game_deal.dart';

class DiscoveryHero extends StatelessWidget {
  const DiscoveryHero({
    super.key,
    required this.offerCount,
    required this.onExplore,
    required this.onRefresh,
    required this.onAdd,
    this.featured,
  });

  final int offerCount;
  final GameDeal? featured;
  final VoidCallback onExplore, onAdd;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final offer = featured;
    final image = offer?.imageUrl;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 660 &&
            MediaQuery.textScalerOf(context).scale(16) <= 21;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ofertas de jogos', style: theme.textTheme.headlineMedium),
            Text(
              '$offerCount ofertas disponíveis',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
        final actions = Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            IconButton(
              tooltip: 'Atualizar ofertas',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar à lista'),
            ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  children: [
                    Expanded(child: heading),
                    actions,
                  ],
                )
              else ...[
                heading,
                const SizedBox(height: 8),
                actions,
              ],
              if (offer != null) ...[
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: onExplore,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: image == null
                        ? Icon(
                            Icons.local_offer_outlined,
                            color: colors.primary,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              image,
                              width: 48,
                              height: 40,
                              fit: BoxFit.cover,
                              cacheWidth: 144,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox(width: 48),
                            ),
                          ),
                    title: Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(offer.formattedPrice),
                    trailing: const Icon(Icons.arrow_downward_rounded),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
