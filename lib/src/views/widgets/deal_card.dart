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
  bool _hovered = false;

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
    final deal = widget.deal, c = Theme.of(context).colorScheme;
    final unknown = deal.sourceLabel == 'Aguardando atualização do preço';
    final is100Free = deal.isFree || deal.discount >= 100;
    final isSuperDiscount = deal.discount >= 80;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? c.secondary.withValues(alpha: .55)
                : c.outlineVariant.withValues(alpha: .4),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(17),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: deal.storeUrl == null
                ? null
                : () => openStore(context, deal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: widget.compact ? 92 : 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              deal.platform.tint.withValues(alpha: .24),
                              c.surfaceContainerHighest,
                            ],
                          ),
                        ),
                        child: deal.imageUrl == null
                            ? Center(
                                child: Icon(
                                  deal.platform.icon,
                                  size: 54,
                                  color: deal.platform.tint.withValues(
                                    alpha: .65,
                                  ),
                                ),
                              )
                            : Image.network(
                                gaplessPlayback: true,
                                deal.imageUrl!,
                                fit: BoxFit.cover,
                                cacheWidth: 640,
                                filterQuality: FilterQuality.low,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    deal.platform.icon,
                                    size: 48,
                                    color: deal.platform.tint,
                                  ),
                                ),
                              ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x33000000),
                              Colors.transparent,
                              Color(0x88000000),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 60,
                        top: 10,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: is100Free
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF20B969),
                                            Color(0xFF138A4B),
                                          ],
                                        )
                                      : isSuperDiscount
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFF3D00),
                                            Color(0xFFD50000),
                                          ],
                                        )
                                      : null,
                                  color: (is100Free || isSuperDiscount)
                                      ? null
                                      : const Color(0xFFBDF46B),
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (is100Free) ...[
                                      const Icon(
                                        Icons.card_giftcard_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                    ] else if (isSuperDiscount) ...[
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                    ],
                                    Text(
                                      unknown
                                          ? 'SALVO'
                                          : is100Free
                                          ? '100% GRÁTIS'
                                          : deal.discount > 0
                                          ? '${deal.discount}% OFF'
                                          : 'PREÇO ATUAL',
                                      style: TextStyle(
                                        fontSize: widget.compact ? 14 : 16,
                                        color: is100Free || isSuperDiscount
                                            ? Colors.white
                                            : const Color(0xFF14210A),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 7,
                        child: IconButton.filledTonal(
                          tooltip: widget.saved
                              ? 'Remover da lista'
                              : 'Acompanhar preço',
                          onPressed: widget.onToggle,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xC4161D27),
                            minimumSize: const Size(36, 36),
                          ),
                          icon: Icon(
                            widget.saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: widget.saved
                                ? const Color(0xFFF198B6)
                                : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: widget.compact
                        ? const EdgeInsets.all(12)
                        : const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF172131),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: deal.platform.tint.withValues(
                                    alpha: .65,
                                  ),
                                  width: .8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    deal.platform.icon,
                                    size: 17,
                                    color: deal.platform.tint,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      deal.platform.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.compact &&
                                deal.expiresAt != null &&
                                !deal.isExpired)
                              Tooltip(
                                message: _formatExpiry(deal.expiresAt!),
                                child: Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            if (!widget.compact &&
                                deal.expiresAt != null &&
                                !deal.isExpired) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.timer_outlined,
                                size: 11,
                                color: c.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatExpiry(deal.expiresAt!),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (!widget.current || deal.isExpired)
                              Text(
                                'Último preço visto',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (deal.platform == GamePlatform.xbox)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              deal.xboxCompatibility.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(height: widget.compact ? 6 : 8),
                        Text(
                          deal.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.compact ? 13 : 15,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.2,
                            color: c.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Divider(
                          height: widget.compact ? 12 : 21,
                          thickness: .7,
                          color: c.outlineVariant.withValues(alpha: .55),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!unknown &&
                                      (deal.discount > 0 || is100Free))
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          is100Free && deal.originalPrice > 0
                                              ? 'De ${deal.formattedOriginalPrice}'
                                              : deal.formattedOriginalPrice,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: c.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        if (!widget.compact &&
                                            deal
                                                .formattedSavings
                                                .isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  (is100Free || isSuperDiscount)
                                                  ? (is100Free
                                                        ? const Color(
                                                            0xFF20B969,
                                                          ).withValues(
                                                            alpha: .18,
                                                          )
                                                        : Colors.redAccent
                                                              .withValues(
                                                                alpha: .18,
                                                              ))
                                                  : c.onSurfaceVariant
                                                        .withValues(alpha: .12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              is100Free
                                                  ? 'Economize 100%'
                                                  : '−${deal.formattedSavings}',
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: is100Free
                                                    ? const Color(0xFF20B969)
                                                    : isSuperDiscount
                                                    ? Colors.redAccent
                                                    : c.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  const SizedBox(height: 3),
                                  Text(
                                    unknown
                                        ? 'Aguardando preço'
                                        : is100Free
                                        ? '100% GRÁTIS'
                                        : deal.formattedPrice,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: widget.compact ? 18 : 22,
                                      height: 1.1,
                                      letterSpacing: -.6,
                                      fontWeight: FontWeight.w800,
                                      color: is100Free
                                          ? const Color(0xFF20B969)
                                          : c.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Compartilhar oferta',
                              icon: const Icon(Icons.share_outlined, size: 18),
                              onPressed: () => _shareDeal(context, deal),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              tooltip: 'Ver oferta na loja',
                              onPressed: deal.storeUrl == null
                                  ? null
                                  : () => openStore(context, deal),
                              style: IconButton.styleFrom(
                                backgroundColor: deal.platform.tint.withValues(
                                  alpha: .12,
                                ),
                                foregroundColor: deal.platform.tint,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
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
        ),
      ),
    );
  }
}
