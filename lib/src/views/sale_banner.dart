import 'package:flutter/material.dart';

import '../models/sale_campaign.dart';
import '../models/platform.dart';

class SaleBanner extends StatefulWidget {
  const SaleBanner({super.key, required this.campaign, required this.onTap});
  final SaleCampaign campaign;
  final VoidCallback onTap;
  @override
  State<SaleBanner> createState() => _SaleBannerState();
}

class _SaleBannerState extends State<SaleBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final campaign = widget.campaign;
    final tint = campaign.platform.tint;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovered
                ? tint.withValues(alpha: .5)
                : Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: .4),
          ),
        ),
        child: Material(
          color: const Color(0xFF131C27),
          borderRadius: BorderRadius.circular(19),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.withValues(alpha: .38),
                        const Color(0xFF101822),
                      ],
                    ),
                  ),
                ),
                if (campaign.imageUrl != null)
                  Image.network(
                    campaign.imageUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    excludeFromSemantics: true,
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x880C141D), Color(0xEA0D141F)],
                    ),
                  ),
                ),
                Positioned(
                  right: -16,
                  bottom: -22,
                  child: Icon(
                    campaign.platform.icon,
                    size: 148,
                    color: tint.withValues(alpha: .18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: tint.withValues(alpha: .35),
                                width: .8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  campaign.platform.icon,
                                  size: 11,
                                  color: tint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  campaign.platform.label.toUpperCase(),
                                  style: TextStyle(
                                    color: tint,
                                    fontSize: 9,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tint.withValues(
                                alpha: _hovered ? .25 : .12,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              size: 18,
                              color: _hovered ? tint : const Color(0xFFCEDBEA),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        campaign.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.18,
                          letterSpacing: -.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        campaign.storewide
                            ? 'Catálogo completo · Ofertas e jogos grátis'
                            : 'Seleção especial por tempo limitado.',
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBAC9DA),
                        ),
                      ),
                    ],
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
