import 'dart:convert';
import 'package:html/parser.dart' as html;
import '../models/game_deal.dart';
import '../models/store_region.dart';
import '../models/sale_campaign.dart';
import 'store_providers.dart' show JsonRequest;

/// Anonymous storefront requests. No user account or private API key is used.
class PublicStoreCatalogs {
  PublicStoreCatalogs(this.request, {this.region = StoreRegion.brazil});
  final JsonRequest request;
  final StoreRegion region;

  Future<DealPage> page(
    GamePlatform platform, {
    String? cursor,
    String query = '',
    bool discountedOnly = true,
  }) async {
    final index = int.tryParse(cursor ?? '0');
    if (index == null || index < 0)
      throw const FormatException('Página inválida');
    return switch (platform) {
      GamePlatform.nuuvem => _nuuvem(index, query, discountedOnly),
      GamePlatform.ubisoft => _ubisoft(index, query, discountedOnly),
      GamePlatform.ea => _ea(index, query, discountedOnly),
      GamePlatform.nintendo => _nintendo(index, query, discountedOnly),
      _ => throw const FormatException('Loja sem catálogo público integrado'),
    };
  }

  Future<String> _html(Uri uri) async {
    final response = await request(uri);
    if (response['html'] is! String)
      throw const FormatException('Página da loja inválida');
    return response['html'] as String;
  }

  Future<DealPage> _nintendo(
    int index,
    String query,
    bool discountedOnly,
  ) async {
    if (region.country != 'BR' || index > 0) return const DealPage([]);

    final storefront = Uri.https(
      'www.nintendo.com',
      '/pt-br/store/sales-and-deals/',
    );
    final document = html.parse(await _html(storefront));
    final data = jsonDecode(
      document.querySelector('#__NEXT_DATA__')?.text ?? '{}',
    );
    final products =
        data['props']?['pageProps']?['page']?['content']?['merchandisedGrid'];
    if (products is! List) {
      throw const FormatException('Catálogo Nintendo eShop indisponível');
    }
    final slugPattern = RegExp(r'^[a-z0-9-]+$');
    final deals = <String, GameDeal>{};
    for (final product in products.whereType<Map>()) {
      final id = product['urlKey'];
      final title = product['name'];
      final prices = product['prices'];
      if (id is! String ||
          !slugPattern.hasMatch(id) ||
          title is! String ||
          title.trim().isEmpty ||
          prices is! Map ||
          prices['currency'] != region.currency) {
        continue;
      }
      final current = prices['finalPrice'];
      final original = prices['regularPrice'];
      if (current is! num ||
          original is! num ||
          current < 0 ||
          original < current ||
          (discountedOnly && current == original)) {
        continue;
      }
      final end = product['eshopDetails']?['discountPriceEnd'];
      final expires = current < original && end is String
          ? DateTime.tryParse(end)
          : null;
      final deal = GameDeal.fromJson({
        'id': id,
        'title': title,
        'platform': 'nintendo',
        'currentPrice': current,
        'originalPrice': original,
        'currency': region.currency,
        'storeUrl': storefront.resolve('/pt-br/store/products/$id/').toString(),
        'imageUrl': product['productImageSquare']?['url'],
        if (expires != null) 'expiresAt': expires.toIso8601String(),
        'source': 'Nintendo eShop · Brasil',
      });
      if (!deal.isExpired) deals[id] = deal;
    }
    final term = query.trim().toLowerCase();
    return DealPage([
      for (final deal in deals.values)
        if (deal.title.toLowerCase().contains(term)) deal,
    ]);
  }

  Future<DealPage> _nuuvem(int index, String query, bool discountedOnly) async {
    final storefront = region.nuuvemLocale;
    if (storefront == null)
      throw FormatException(
        'A Nuuvem não oferece catálogo integrado para ${region.label}',
      );
    final uri = Uri.https('www.nuuvem.com', '/$storefront/catalog').replace(
      pathSegments: [
        storefront,
        'catalog',
        'types',
        'games',
        if (discountedOnly) ...['price', 'promo'],
        'sort',
        'bestselling',
        'sort-mode',
        'desc',
        if (query.isNotEmpty) ...['search', query],
        if (index > 0) ...['page', '${index + 1}'],
      ],
    );
    final document = html.parse(await _html(uri));
    final cards = document.querySelectorAll('[data-component="product-card"]');
    if (cards.isEmpty &&
        document.querySelector(
              '.pagination, .catalog, [data-component="catalog"]',
            ) ==
            null &&
        !(document.text ?? '').contains('resultados')) {
      throw const FormatException('Catálogo Nuuvem indisponível');
    }
    final deals = <GameDeal>[];
    for (final card in cards) {
      if (!card.classes.contains('product__purchasable')) continue;
      final priceElement = card.querySelector('[data-price]');
      if (priceElement == null) continue;
      try {
        final price = jsonDecode(priceElement.attributes['data-price']!) as Map;
        final base =
            jsonDecode(
                  priceElement.attributes['data-base-price'] ??
                      priceElement.attributes['data-price']!,
                )
                as Map;
        final meta =
            jsonDecode(
                  card
                          .querySelector(
                            '[data-wishlist-button-product-data-value]',
                          )
                          ?.attributes['data-wishlist-button-product-data-value'] ??
                      '{}',
                )
                as Map;
        final currency = meta['currency'] ?? region.currency;
        if (!region.allowedCurrencies.contains(currency)) continue;
        final link = card.parent?.attributes['href'];
        final uri = Uri.tryParse(link ?? '');
        if (uri == null ||
            uri.host != 'www.nuuvem.com' ||
            !uri.path.contains('/item/'))
          continue;
        final title =
            card.querySelector('.game-card__product-name')?.text.trim() ?? '';
        if (title.isEmpty || price['v'] is! num || base['v'] is! num) continue;
        final deal = GameDeal.fromJson({
          'id': uri.pathSegments.last,
          'platform': 'nuuvem',
          'title': title,
          'currentPrice': (price['v'] as num) / 100,
          'originalPrice': (base['v'] as num) / 100,
          'currency': currency,
          'storeUrl': link,
          'imageUrl': card.querySelector('img')?.attributes['src'],
          if (price['e'] is String) 'expiresAt': price['e'],
          'source': 'Nuuvem · ${region.label}',
        });
        if (!deal.isExpired && (!discountedOnly || deal.discount > 0))
          deals.add(deal);
      } on FormatException {
        continue;
      }
    }
    final next = document.querySelector('a[rel="next"]');
    return DealPage(deals, nextCursor: next == null ? null : '${index + 1}');
  }

  Future<DealPage> _ubisoft(
    int index,
    String query,
    bool discountedOnly,
  ) async {
    final source = await _html(
      Uri.https('store.ubisoft.com', '/${_ubisoftStorefront()}/home', {
        'lang': region.underscoreLocale,
      }),
    );
    final document = html.parse(source);
    final config = document.querySelector('mooncake-data[algolia-app-id]');
    final app = config?.attributes['algolia-app-id'] ?? '';
    final key = config?.attributes['algolia-api-key'] ?? '';
    final match = RegExp(
      r'"ALGOLIA_INDEXES_V2"\s*:\s*("(?:\\.|[^"\\])*")',
    ).firstMatch(source);
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(app) ||
        key.isEmpty ||
        match == null) {
      throw const FormatException('Busca pública Ubisoft indisponível');
    }
    // The storefront publishes a search-only credential. Read it at runtime;
    // users never need to obtain, configure or ship their own key.
    final indexes = jsonDecode(jsonDecode(match.group(1)!) as String) as Map;
    final catalog = indexes[region.underscoreLocale]?['defaultIndex'];
    if (catalog is! String || catalog.isEmpty)
      throw const FormatException('Catálogo Ubisoft indisponível nesta região');
    final result = await request(
      Uri.https('${app.toLowerCase()}-dsn.algolia.net', '/1/indexes/$catalog', {
        'x-algolia-application-id': app,
        'x-algolia-api-key': key,
        'query': query,
        'page': '$index',
        'hitsPerPage': '48',
        'filters': 'product_type:Games',
      }),
    );
    if (result['hits'] is! List || result['nbPages'] is! num)
      throw const FormatException('Resposta Ubisoft inválida');
    final deals = <GameDeal>[];
    for (final row in result['hits'] as List) {
      if (row is! Map ||
          row['product_type'] != 'Games' ||
          row['availability'] != 1)
        continue;
      final current = row['price']?[region.currency];
      final original = row['default_price']?[region.currency];
      final url = Uri.tryParse(row['link']?.toString() ?? '');
      if (current is! num ||
          original is! num ||
          current < 0 ||
          original < current ||
          url?.host != 'store.ubisoft.com' ||
          url?.scheme != 'https')
        continue;
      final title = row['title']?.toString().trim() ?? '';
      final id = row['id']?.toString() ?? '';
      if (title.isEmpty || id.isEmpty) continue;
      final deal = GameDeal.fromJson({
        'id': id,
        'platform': 'ubisoft',
        'title': title,
        'currentPrice': current,
        'originalPrice': original,
        'currency': region.currency,
        'storeUrl': url.toString(),
        'imageUrl': row['image_link'],
        'source': 'Ubisoft Store · ${region.label}',
      });
      if (!deal.isExpired && (!discountedOnly || deal.discount > 0))
        deals.add(deal);
    }
    return DealPage(
      deals,
      total: (result['nbHits'] as num?)?.toInt(),
      nextCursor: index + 1 < (result['nbPages'] as num).toInt()
          ? '${index + 1}'
          : null,
    );
  }

  Future<DealPage> _ea(int index, String query, bool discountedOnly) async {
    final source = await _html(
      Uri.https('www.ea.com', '/${region.lowerLocale}/sales/deals'),
    );
    final document = html.parse(source);
    final games = <String, Map<String, String>>{};
    for (final tile in document.querySelectorAll(
      'ea-hybrid-themedsale-product[game-slug]',
    )) {
      final slug = tile.attributes['game-slug']!;
      final title = tile.attributes['title-text']?.trim() ?? '';
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(slug) || title.isEmpty) continue;
      if (query.isNotEmpty &&
          !title.toLowerCase().contains(query.toLowerCase()) &&
          slug != query)
        continue;
      String? link;
      for (final element in document.querySelectorAll('[link-url], a[href]')) {
        final raw =
            element.attributes['link-url'] ?? element.attributes['href'] ?? '';
        final candidate = Uri.https('www.ea.com').resolve(raw);
        if (candidate.host == 'www.ea.com' &&
            candidate.path.contains('/games/') &&
            candidate.pathSegments.last == slug) {
          link = candidate.toString();
          break;
        }
      }
      if (link == null) continue;
      games[slug] = {
        'title': title,
        'url': link,
        'image': tile.querySelector('img')?.attributes['data-src'] ?? '',
      };
    }
    if (games.isEmpty &&
        document.querySelector('ea-hybrid-themedsale-product') == null)
      throw const FormatException('Catálogo EA indisponível');
    const count = 12;
    final entries = games.entries.skip(index * count).take(count).toList();
    if (entries.isEmpty) return const DealPage([]);
    final fields = <String>[];
    for (var i = 0; i < entries.length; i++) {
      fields.add(
        'g$i: game(slug: ${jsonEncode(entries[i].key)}, locale: "${region.locale}") { lowestPriceGameProduct { anonymousOffer(overrideCountryCode: "${region.country}", subscriptionLevel: NON_SUBSCRIBER) { lowestPricePurchaseOption { displayOriginalTotal displayTotalWithDiscount currency } } } }',
      );
    }
    final result = await request(
      Uri.https('service-aggregation-layer.juno.ea.com', '/graphql'),
      body: {'query': 'query ludivexPrices { ${fields.join(' ')} }'},
    );
    if (result['data'] is! Map)
      throw const FormatException('Preços públicos EA indisponíveis');
    final deals = <GameDeal>[];
    var quoted = 0;
    for (var i = 0; i < entries.length; i++) {
      final price =
          result['data']['g$i']?['lowestPriceGameProduct']?['anonymousOffer']?['lowestPricePurchaseOption'];
      if (price is! Map ||
          !region.allowedCurrencies.contains(price['currency']))
        continue;
      final current = region.parsePrice(
        price['displayTotalWithDiscount'] as String?,
      );
      final original = region.parsePrice(
        price['displayOriginalTotal'] as String?,
      );
      if (current == null ||
          original == null ||
          current < 0 ||
          current > original)
        continue;
      quoted++;
      final game = entries[i];
      final deal = GameDeal.fromJson({
        'id': game.key,
        'platform': 'ea',
        'title': game.value['title'],
        'currentPrice': current,
        'originalPrice': original,
        'currency': price['currency'],
        'imageUrl': game.value['image'],
        'storeUrl': game.value['url'],
        'source': 'EA Store · ${region.label}',
      });
      if (!deal.isExpired && (!discountedOnly || deal.discount > 0))
        deals.add(deal);
    }
    if (quoted == 0)
      throw FormatException(
        'A EA não disponibilizou preços para ${region.label}',
      );
    return DealPage(
      deals,
      nextCursor: (index + 1) * count < games.length ? '${index + 1}' : null,
    );
  }

  String _ubisoftStorefront() => switch (region.country) {
    'BR' || 'MX' || 'AR' || 'CL' || 'CO' => 'ofertas',
    'US' => 'us',
    'CA' => 'ca',
    'GB' => 'uk',
    'AU' => 'anz',
    'JP' => 'jp',
    'IN' => 'in',
    _ => 'eu',
  };
}
