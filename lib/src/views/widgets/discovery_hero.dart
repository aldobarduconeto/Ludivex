import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/game_deal.dart';
import 'page_components.dart';

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
    final actions = [
      FilledButton.icon(
        onPressed: onExplore,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        iconAlignment: IconAlignment.end,
        label: const Text('Explorar ofertas'),
      ),
      if (featured != null)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            '${featured!.title} · ${featured!.formattedPrice}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
          if (constraints.maxWidth < 300 || scale > 1.25) {
            return _flutterHero(actions);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 240 * scale,
                child: UiKitView(
                  key: ValueKey((offerCount, storeCount)),
                  viewType: 'ludivex/discovery_hero',
                  creationParams: {'offers': offerCount, 'stores': storeCount},
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          );
        },
      );
    }
    return _flutterHero(actions);
  }

  Widget _flutterHero(List<Widget> actions) => PageIntro(
    eyebrow: 'DESCOBRIR',
    title: 'Seu próximo jogo começa aqui.',
    description: 'Ofertas de PC e consoles, reunidas em um só lugar.',
    icon: Icons.explore_outlined,
    metrics: [
      MetricPill(
        icon: Icons.local_offer_outlined,
        label: '$offerCount ofertas',
      ),
      MetricPill(icon: Icons.storefront_outlined, label: '$storeCount lojas'),
    ],
    actions: actions,
  );
}
