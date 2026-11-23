import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/game_deal.dart';
import '../../models/platform.dart';

Future<void> openStore(BuildContext context, GameDeal deal) =>
    openStoreLink(context, deal.platform, deal.storeUrl);

Future<void> openStoreLink(
  BuildContext context,
  GamePlatform platform,
  String? url,
) async {
  final uri = Uri.tryParse(url ?? '');
  final hosts = switch (platform) {
    GamePlatform.playstation => ['store.playstation.com'],
    GamePlatform.xbox => ['www.xbox.com', 'www.microsoft.com', 'xbox.com'],
    GamePlatform.steam => ['store.steampowered.com'],
    GamePlatform.epic => ['store.epicgames.com'],
    GamePlatform.nuuvem => ['www.nuuvem.com', 'nuuvem.com'],
    GamePlatform.ubisoft => ['store.ubisoft.com'],
    GamePlatform.ea => ['www.ea.com', 'ea.com'],
    GamePlatform.nintendo => ['www.nintendo.com', 'nintendo.com'],
  };
  var opened = false;
  if (uri != null && uri.scheme == 'https' && hosts.contains(uri.host)) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o endereço oficial desta oferta.',
        ),
      ),
    );
  }
}

String _formatExpiry(DateTime expiresAt) {
  final now = DateTime.now().toUtc();
  final diff = expiresAt.toUtc().difference(now);
  if (diff.isNegative) return 'Encerrado';
  if (diff.inHours < 1) return '${diff.inMinutes}m restantes';
  if (diff.inHours < 24) return '${diff.inHours}h restantes';
  if (diff.inDays == 1) return 'Termina amanhã';
  return 'Termina em ${diff.inDays}d';
}

class DealCard extends StatefulWidget {
  const DealCard({
    super.key,
    required this.deal,
    required this.saved,
    required this.onToggle,
    this.compact = false,
    this.current = true,
  });
  final GameDeal deal;
  final bool saved, compact, current;
  final VoidCallback onToggle;
  @override
  State<DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<DealCard> {
  Future<void> _shareDeal(BuildContext context, GameDeal deal) async {
    final savingsText = deal.discount > 0 ? ' (${deal.discount}% OFF)' : '';
    final priceText = (deal.isFree || deal.discount >= 100)
        ? '100% GRÁTIS'
        : deal.formattedPrice;
    final text =
        '🎮 *${deal.title}* por apenas *$priceText*$savingsText na ${deal.platform.label}!\n${deal.storeUrl ?? ''}\n(Compartilhado via Ludivex)';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Oferta de "${deal.title}" copiada para compartilhar!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deal = widget.deal;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unknown = deal.sourceLabel == 'Aguardando atualização do preço';
    final free = deal.isFree || deal.discount >= 100;
    final image = deal.imageUrl;
    final original =
        !unknown && deal.originalPrice > 0 && (free || deal.discount > 0);
    final expiry = deal.expiresAt;
    final canOpen = deal.storeUrl != null;
    final storeText = [
      deal.platform.label,
      if (deal.platform == GamePlatform.xbox) deal.xboxCompatibility.label,
    ].join(' · ');
    final fallback = Center(
      child: Icon(deal.platform.icon, size: 36, color: colors.onSurfaceVariant),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOpen ? () => openStore(context, deal) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: widget.compact ? 88 : 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: image == null
                        ? fallback
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            cacheWidth: 640,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => fallback,
                          ),
                  ),
                  if (!unknown && (free || deal.discount > 0))
                    Positioned(
                      top: 10,
                      left: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            free ? 'Grátis' : '−${deal.discount}%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      tooltip: widget.saved
                          ? 'Remover da lista'
                          : 'Acompanhar preço',
                      onPressed: widget.onToggle,
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: widget.saved
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      icon: Icon(
                        widget.saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storeText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!widget.current || deal.isExpired || expiry != null)
                      Text(
                        !widget.current || deal.isExpired
                            ? 'Último preço visto'
                            : _formatExpiry(expiry!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (original)
                                Text(
                                  deal.formattedOriginalPrice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                unknown
                                    ? 'Aguardando preço'
                                    : free
                                    ? 'Grátis'
                                    : deal.formattedPrice,
                                maxLines: unknown ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: free
                                      ? colors.primary
                                      : colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Compartilhar oferta',
                          icon: const Icon(Icons.share_outlined, size: 17),
                          onPressed: () => _shareDeal(context, deal),
                        ),
                        IconButton(
                          tooltip: 'Ver oferta na loja',
                          onPressed: canOpen
                              ? () => openStore(context, deal)
                              : null,
                          icon: const Icon(
                            Icons.arrow_outward_rounded,
                            size: 19,
                          ),
                        ),
                      ],
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
