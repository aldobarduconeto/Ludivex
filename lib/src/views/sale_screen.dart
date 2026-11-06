import 'widgets/deal_grid.dart';
import 'widgets/page_components.dart';
import 'widgets/app_preferences.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_deal.dart';
import '../models/sale_campaign.dart';
import '../models/platform.dart';
import '../services/deals_api.dart';
import '../services/wishlist_service.dart';
import 'widgets/deal_card.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({
    super.key,
    required this.campaign,
    required this.api,
    required this.wishlist,
    required this.onToggle,
  });
  final SaleCampaign campaign;
  final DealsApi api;
  final WishlistService wishlist;
  final Future<void> Function(BuildContext, GameDeal) onToggle;
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  final _deals = <String, GameDeal>{};
  String? _cursor, _error;
  int? _total;
  bool _busy = false, _started = false;
  @override
  void initState() {
    super.initState();
    unawaited(_next());
  }

  Future<void> _next() async {
    if (_busy || (_started && _cursor == null)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.api.campaignPage(
        widget.campaign,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        for (final deal in page.deals.where(
          (d) => !d.isExpired && d.discount > 0,
        )) {
          _deals[deal.id] = deal;
        }
        _cursor = page.nextCursor;
        _total = page.total;
        _started = true;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Não foi possível consultar esta categoria agora. Tente novamente após a pausa da API.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.wishlist, AppPreferences.instance]),
    builder: (context, _) {
      final deals = _deals.values.toList()
        ..sort((a, b) => b.discount.compareTo(a.discount));
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      final compact = AppPreferences.instance.compactCards;
      return Scaffold(
        appBar: AppBar(title: Text(widget.campaign.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageIntro(
                          eyebrow: widget.campaign.platform.label.toUpperCase(),
                          title: widget.campaign.title,
                          description: widget.campaign.description.isNotEmpty
                              ? widget.campaign.description
                              : 'Explore as promoções desta seleção. Mais jogos são carregados conforme você avança.',
                          icon: widget.campaign.platform.icon,
                          metrics: [
                            MetricPill(
                              icon: Icons.local_offer_outlined,
                              label: '${deals.length} ofertas carregadas',
                            ),
                            if (_total != null)
                              MetricPill(
                                icon: Icons.grid_view_outlined,
                                label: '$_total resultados na fonte',
                              ),
                          ],
                        ),
                        if (!widget.campaign.isActive)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Esta campanha já encerrou. Confirme as condições na loja.',
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!),
                          ),
                        if (deals.isEmpty && !_busy && _error == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'Nenhuma oferta vigente retornada para esta categoria.',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid(
                      gridDelegate: DealGrid.delegate(
                        constraints.crossAxisExtent,
                        scale,
                        compact: compact,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final deal = deals[index];
                        return DealCard(
                          key: ValueKey(deal.id),
                          deal: deal,
                          compact: compact,
                          saved: widget.wishlist.contains(deal),
                          onToggle: () =>
                              unawaited(widget.onToggle(context, deal)),
                        );
                      }, childCount: deals.length),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: _cursor != null || !_started || _error != null
                          ? OutlinedButton.icon(
                              onPressed: _busy ? null : _next,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _busy
                                    ? 'Consulta em andamento'
                                    : 'Carregar mais ofertas',
                              ),
                            )
                          : const Text(
                              'Você chegou ao fim das ofertas disponíveis nesta categoria.',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
