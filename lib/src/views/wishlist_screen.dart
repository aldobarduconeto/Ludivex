import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/game_deal.dart';
import '../models/platform.dart';
import '../models/wishlist_item.dart';
import '../services/wishlist_service.dart';
import 'widgets/deal_card.dart';
import 'widgets/page_components.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    super.key,
    required this.service,
    required this.onAdd,
    required this.onEdit,
    required this.onRefresh,
  });
  final WishlistService service;
  final VoidCallback onAdd;
  final ValueChanged<WishlistItem> onEdit;
  final Future<void> Function() onRefresh;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _onlyDiscounted = false;
  WishlistService get service => widget.service;
  VoidCallback get onAdd => widget.onAdd;
  ValueChanged<WishlistItem> get onEdit => widget.onEdit;
  Future<void> Function() get onRefresh => widget.onRefresh;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remove(BuildContext context, WishlistItem item) async {
    try {
      await service.remove(item.id);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} removido.'),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () async {
                try {
                  await service.restore(item);
                } catch (_) {
                  /* A failed restore does not remove other items. */
                }
              },
            ),
          ),
        );
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover o jogo.')),
        );
    }
  }

  void _history(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: AnimatedBuilder(
            animation: service,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Avisos de preço',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: service.alerts.isEmpty
                            ? null
                            : service.clearAlerts,
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                ),
                if (service.alerts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Nenhuma queda ou meta detectada ainda.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: service.alerts.length,
                      itemBuilder: (context, index) {
                        final event = service.alerts[index];
                        final deal = GameDeal.fromJson(
                          event['deal'] as Map<String, dynamic>,
                        );
                        final date = DateTime.tryParse(
                          event['createdAt'] as String? ?? '',
                        );
                        return ListTile(
                          leading: Icon(
                            Icons.trending_down,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(deal.title),
                          subtitle: Text(
                            '${deal.formattedPrice} · ${deal.platform.shortLabel}${date == null ? '' : '\n${DateFormat('dd/MM HH:mm').format(date.toLocal())}'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Ver loja',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => openStore(context, deal),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final rawItems = service.items;
      double totalOriginal = 0;
      double totalCurrent = 0;
      int onSaleCount = 0;
      for (final item in rawItems) {
        final q = item.quote;
        if (q != null) {
          totalOriginal +=
              q.originalPrice > 0 ? q.originalPrice : q.currentPrice;
          totalCurrent += q.currentPrice;
          if (q.discount > 0) {
            onSaleCount++;
          }
        }
      }
      final totalSavings = totalOriginal - totalCurrent;
      final items = rawItems
          .where((item) =>
              item.title.toLowerCase().contains(_query) &&
              (!_onlyDiscounted ||
                  (item.quote != null && item.quote!.discount > 0)))
          .toList();
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: RefreshIndicator.noSpinner(
            onRefresh: onRefresh,
            child: ListView.builder(
              key: const PageStorageKey('wishlist'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PageIntro(
                        eyebrow: 'NO SEU RADAR',
                        title: 'Sua lista. Seu próximo jogo.',
                        description: 'Acompanhe seus favoritos e receba avisos quando o preço chegar à sua meta.',
                        icon: Icons.favorite_outline_rounded,
                        metrics: [
                          MetricPill(
                            icon: Icons.bookmark_border_rounded,
                            label: '${service.items.length} jogos salvos',
                          ),
                          MetricPill(
                            icon: Icons.notifications_none_rounded,
                            label: '${service.alerts.length} avisos',
                          ),
                        ],
                        actions: [
                          FilledButton.icon(
                            key: const Key('add-wishlist-item'),
                            onPressed: onAdd,
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar jogo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _history(context),
                            icon: const Icon(Icons.notifications_none),
                            label: const Text('Ver avisos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (totalSavings > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.savings_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Economia Total: R\$ ${totalSavings.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '$onSaleCount em promoção',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'De R\$ ${totalOriginal.toStringAsFixed(2)} por R\$ ${totalCurrent.toStringAsFixed(2)} aproveitando as ofertas ativas hoje!',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilterChip(
                                label: const Text('Apenas promoções'),
                                selected: _onlyDiscounted,
                                onSelected: (val) =>
                                    setState(() => _onlyDiscounted = val),
                              ),
                            ],
                          ),
                        ),
                      CollectionSearchField(
                        controller: _search,
                        hint: 'Buscar na lista de desejos',
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 20),
                      if (items.isEmpty)
                        AppEmptyState(
                          icon: _query.isEmpty
                              ? Icons.favorite_outline
                              : Icons.search_off_rounded,
                          title: _query.isEmpty
                              ? 'Sua próxima aventura começa aqui.'
                              : 'Nenhum jogo encontrado.',
                          description: _query.isEmpty
                              ? 'Busque um jogo ou cole o link da loja para começar a acompanhar seu preço.'
                              : 'Tente outro nome ou limpe a busca para ver todos os jogos.',
                        ),
                    ],
                  );
                final item = items[index - 1];
                final scheme = Theme.of(context).colorScheme;
                final quote = item.quote;
                final historicalLow = item.lowestPrice;
                final aboveHistoricalLow =
                    quote != null &&
                    historicalLow != null &&
                    (quote.currentPrice * 100).round() >
                        (historicalLow * 100).round();
                return Card(
                  key: ValueKey(item.id),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 76,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: item.platform.tint.withValues(
                                  alpha: .14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: quote?.imageUrl != null
                                  ? Image.network(
                                      quote!.imageUrl!,
                                      fit: BoxFit.cover,
                                      cacheWidth: 180,
                                      excludeFromSemantics: true,
                                      errorBuilder: (_, __, ___) => Icon(
                                        item.platform.icon,
                                        color: item.platform.tint,
                                      ),
                                    )
                                  : Icon(
                                      item.platform.icon,
                                      color: item.platform.tint,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${item.platform.label}${item.platform == GamePlatform.xbox ? ' · ${quote?.xboxCompatibility.label ?? XboxCompatibility.unknown.label}' : ''}',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Opções do jogo',
                              onSelected: (value) => value == 'edit'
                                  ? onEdit(item)
                                  : _remove(context, item),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar preço e avisos'),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remover da lista'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              quote?.formattedPrice ??
                                  'Preço ainda não consultado',
                              style: TextStyle(
                                fontSize: quote == null ? 15 : 22,
                                fontWeight: FontWeight.w800,
                                color: quote == null
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                            ),
                            if (quote != null && historicalLow != null)
                              Chip(
                                label: Text(
                                  'MPH: ${quote.formattedHistoricalLow(historicalLow)}',
                                ),
                              ),
                            if (aboveHistoricalLow)
                              Chip(
                                avatar: Icon(
                                  Icons.trending_up,
                                  color: scheme.onErrorContainer,
                                ),
                                backgroundColor: scheme.errorContainer,
                                label: Text(
                                  'Preço atual acima do MPH',
                                  style: TextStyle(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            if (item.targetPrice != null)
                              Chip(
                                label: Text(
                                  'Meta: ${item.targetCurrency} ${item.targetPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                                ),
                              ),
                            Icon(
                              item.notify
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_off_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quote == null
                              ? 'O jogo fica salvo mesmo sem cotação disponível na API.'
                              : quote.isExpired
                              ? 'Último preço visto · promoção encerrada'
                              : 'Último preço consultado · confirme as condições na loja',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton.icon(
                              onPressed: () => onEdit(item),
                              icon: const Icon(Icons.tune, size: 17),
                              label: const Text('Editar acompanhamento'),
                            ),
                            TextButton.icon(
                              onPressed: item.storeUrl == null
                                  ? null
                                  : () => openStoreLink(
                                      context,
                                      item.platform,
                                      item.storeUrl,
                                    ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Ver loja'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
