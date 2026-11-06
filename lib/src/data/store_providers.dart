import '../models/game_deal.dart';
import '../models/store_region.dart';
import 'public_store_catalogs.dart';
import 'console_catalogs.dart';
import '../models/sale_campaign.dart';

import 'package:html/parser.dart' as html;

typedef JsonRequest = Future<Map<String, dynamic>> Function(
  Uri uri, {
  String? token,
  Map<String, dynamic>? body,
});

/// Direct API adapters. No application server or background worker is required.
class StoreProviders {
  StoreProviders(
    this.request, {
    this.region = StoreRegion.brazil,
    this.apiUrls = const {},
    this.xboxProductIds = const [],
  });
  final JsonRequest request;
  final StoreRegion region;
  final Map<GamePlatform, String> apiUrls;
  final List<String> xboxProductIds;

  Future<List<GameDeal>> collect(
    GamePlatform platform, {
    String query = '',
    bool discountedOnly = true,
  }) async {
    if (query.isEmpty) {
      return (await page(platform, discountedOnly: discountedOnly)).deals;
    }
    final feed = apiUrls[platform];
    List<dynamic> rows;
    if (feed != null && feed.isNotEmpty) {
      final base = Uri.parse(feed);
      final result = await request(
        base.replace(
          queryParameters: {
            ...base.queryParameters,
            'region': region.country,
            if (query.isNotEmpty) 'q': query,
          },
        ),
      );
      rows = result['deals'] as List;
    } else {
      rows = switch (platform) {
        GamePlatform.steam => await _steam(query),
        GamePlatform.epic => await _epic(
          query: query,
          discountedOnly: discountedOnly,
        ),
        GamePlatform.xbox => (await ConsoleCatalogs(request, region).xbox(
          query: query,
          discountedOnly: discountedOnly,
        )).deals.map((d) => d.toJson()).toList(),
        GamePlatform.nuuvem ||
        GamePlatform.ubisoft ||
        GamePlatform.ea ||
        GamePlatform.nintendo =>
          (await PublicStoreCatalogs(request, region: region).page(
            platform,
            query: query,
            discountedOnly: discountedOnly,
          )).deals.map((d) => d.toJson()).toList(),
        GamePlatform.playstation =>
          (await ConsoleCatalogs(request, region).playstation(
            query: query,
            discountedOnly: discountedOnly,
          )).deals.map((d) => d.toJson()).toList(),
      };
    }
    final unique = <String, GameDeal>{};
    for (final row in rows) {
      final deal = GameDeal.fromJson({
        ...row as Map<String, dynamic>,
        'platform': platform.key,
        'currency': (row as Map)['currency'] ?? region.currency,
      });
      if (!region.allowedCurrencies.contains(deal.currency)) continue;
      if ((discountedOnly && deal.currentPrice >= deal.originalPrice) ||
          deal.isExpired) {
        continue;
      }
      if (query.isNotEmpty &&
          !deal.title.toLowerCase().contains(query.toLowerCase()) &&
          !deal.id.endsWith(query)) {
        continue;
      }
      if (!unique.containsKey(deal.id) ||
          unique[deal.id]!.currentPrice > deal.currentPrice) {
        unique[deal.id] = deal;
      }
    }
    return unique.values.toList();
  }

  Future<DealPage> page(
    GamePlatform platform, {
    String? cursor,
    String? campaignId,
    bool discountedOnly = true,
  }) async {
    final feed = apiUrls[platform];
    if (feed?.isNotEmpty ?? false) {
      final base = Uri.parse(feed!);
      final response = await request(
        base.replace(
          queryParameters: {
            ...base.queryParameters,
            'region': region.country,
            if (cursor != null) 'cursor': cursor,
            if (campaignId != null) 'campaignId': campaignId,
          },
        ),
      );
      final campaigns = <SaleCampaign>[];
      for (final raw in response['campaigns'] as List? ?? []) {
        try {
          final c = SaleCampaign.fromJson(
            raw as Map<String, dynamic>,
            platform,
          );
          if (c.isActive) campaigns.add(c);
        } catch (_) {
          /* Invalid campaign metadata must not hide real prices. */
        }
      }
      final deals =
          _normalize(
                response['deals'] as List,
                platform,
                discountedOnly: discountedOnly,
              )
              .where(
                (d) =>
                    campaignId == null ||
                    d.campaignIds.contains(campaignId) ||
                    response['campaignId'] == campaignId,
              )
              .toList();
      final next = response['nextCursor']?.toString();
      return DealPage(
        deals,
        campaigns: campaigns,
        total: (response['total'] as num?)?.toInt(),
        nextCursor: next == null || next.isEmpty || next == cursor
            ? null
            : next,
      );
    }
    if (campaignId != null) {
      throw const FormatException('A API desta loja não fornece esta campanha');
    }
    if (platform == GamePlatform.steam) return _steamPage(cursor);
    if (platform == GamePlatform.epic) {
      return _epicPage(cursor, discountedOnly: discountedOnly);
    }
    if (platform == GamePlatform.nuuvem ||
        platform == GamePlatform.ubisoft ||
        platform == GamePlatform.ea ||
        platform == GamePlatform.nintendo) {
      return PublicStoreCatalogs(
        request,
        region: region,
      ).page(platform, cursor: cursor, discountedOnly: discountedOnly);
    }
    if (platform == GamePlatform.playstation) {
      return ConsoleCatalogs(
        request,
        region,
      ).playstation(cursor: cursor, discountedOnly: discountedOnly);
    }
    return ConsoleCatalogs(
      request,
      region,
    ).xbox(cursor: cursor, discountedOnly: discountedOnly);
  }

  List<GameDeal> _normalize(
    List<dynamic> rows,
    GamePlatform platform, {
    required bool discountedOnly,
  }) {
    final unique = <String, GameDeal>{};
    for (final row in rows) {
      final deal = GameDeal.fromJson({
        ...row as Map<String, dynamic>,
        'platform': platform.key,
        'currency': (row as Map)['currency'] ?? region.currency,
      });
      if (!region.allowedCurrencies.contains(deal.currency)) continue;
      if (deal.isExpired || (discountedOnly && deal.discount <= 0)) continue;
      if (!unique.containsKey(deal.id) ||
          unique[deal.id]!.currentPrice > deal.currentPrice) {
        unique[deal.id] = deal;
      }
    }
    return unique.values.toList();
  }

  Future<DealPage> _steamPage(String? cursor) async {
    final start = int.tryParse(cursor ?? '0');
    if (start == null || start < 0) {
      throw const FormatException('Página inválida');
    }
    final data = await request(
      Uri.https('store.steampowered.com', '/search/results/', {
        'start': '$start',
        'count': '50',
        'specials': '1',
        'category1': '998',
        'infinite': '1',
        'cc': region.country.toLowerCase(),
        'l': region.steamLanguage,
      }),
    );
    if (data['results_html'] is! String || data['success'] != 1) {
      throw const FormatException('Catálogo Steam inválido');
    }
    final document = html.parseFragment(data['results_html'] as String);
    final rows = document.querySelectorAll('a.search_result_row');
    final deals = <GameDeal>[];
    for (final row in rows) {
      final id = row.attributes['data-ds-appid'] ?? '';
      if (!RegExp(r'^\d+$').hasMatch(id)) continue;
      final originalText =
          row.querySelector('.discount_original_price')?.text ?? '';
      if (originalText.trim().isEmpty) continue;
      final original = region.parsePrice(originalText);
      final cents = int.tryParse(
        row
                .querySelector('[data-price-final]')
                ?.attributes['data-price-final'] ??
            '',
      );
      final title = row.querySelector('.title')?.text.trim() ?? '';
      if (original == null ||
          cents == null ||
          title.isEmpty ||
          original <= cents / 100) {
        continue;
      }
      deals.add(
        GameDeal.fromJson({
          'id': id,
          'platform': 'steam',
          'title': title,
          'currentPrice': cents / 100,
          'originalPrice': original,
          'currency': region.country == 'AR' ? 'USD' : region.currency,
          'imageUrl': row.querySelector('img')?.attributes['src'],
          'storeUrl': 'https://store.steampowered.com/app/$id/',
          'source': 'Steam · Promoções ${region.label}',
        }),
      );
    }
    final total = (data['total_count'] as num?)?.toInt() ?? start + rows.length;
    final next = start + rows.length;
    return DealPage(
      deals,
      total: total,
      nextCursor: rows.isEmpty || next >= total ? null : '$next',
    );
  }

  Future<DealPage> _epicPage(
    String? cursor, {
    bool discountedOnly = true,
  }) async {
    final start = int.tryParse(cursor ?? '0');
    if (start == null || start < 0)
      throw const FormatException('Página inválida');
    const count = 40;
    final now = DateTime.now().toUtc();
    final rows = <Map<String, dynamic>>[];
    int? total;

    // First page: always include free giveaway games
    if (start == 0) {
      try {
        final freeResult = await request(
          Uri.https(
            'store-site-backend-static.ak.epicgames.com',
            '/freeGamesPromotions',
            {
              'locale': region.locale,
              'country': region.country,
              'allowCountries': region.country,
            },
          ),
        );
        final freeItems =
            freeResult['data']?['Catalog']?['searchStore']?['elements']
                as List? ??
            [];
        for (final item in freeItems) {
          if (item is Map<String, dynamic>) {
            final parsed = _parseEpicElement(
              item,
              now: now,
              discountedOnly: discountedOnly,
            );
            if (parsed != null) rows.add(parsed);
          }
        }
      } catch (_) {
        /* Continue with GraphQL promotions */
      }
    }

    final result = await _epicSearch(
      start: start,
      discountedOnly: discountedOnly,
    );
    final elements = result['offers'] as List;
    total = (result['total'] as num?)?.toInt();
    for (final item in elements.whereType<Map<String, dynamic>>()) {
      final parsed = _parseEpicElement(
        _epicPrice(item),
        now: now,
        discountedOnly: discountedOnly,
      );
      if (parsed != null) rows.add(parsed);
    }

    final deals = _normalize(
      rows,
      GamePlatform.epic,
      discountedOnly: discountedOnly,
    );
    final next = start + count;
    return DealPage(
      deals,
      total: total,
      nextCursor: elements.isEmpty || total == null || next >= total
          ? null
          : '$next',
    );
  }

  Future<Map<String, dynamic>> _epicSearch({
    int start = 0,
    String query = '',
    bool discountedOnly = true,
  }) async {
    final result = await request(
      Uri.https('api.egdata.app', '/search/v2/search', {
        'country': region.country,
        'locale': region.locale,
      }),
      body: {
        'offerType': 'BASE_GAME',
        'page': start ~/ 40 + 1,
        'limit': 40,
        if (discountedOnly) 'onSale': true,
        if (query.isNotEmpty) 'title': query,
      },
    );
    if (result['offers'] is! List || result['total'] is! num) {
      throw const FormatException('Catálogo Epic inválido');
    }
    return result;
  }

  Map<String, dynamic> _epicPrice(Map<String, dynamic> item) => {
    ...item,
    'price': {
      'totalPrice': item['price']?['price'],
      'lineOffers': [
        {'appliedRules': item['price']?['appliedRules'] ?? []},
      ],
    },
  };

  Future<GameDeal?> lookup(GamePlatform platform, String productId) async {
    if (apiUrls[platform]?.isNotEmpty ?? false) {
      final games = await collect(
        platform,
        query: productId,
        discountedOnly: false,
      );
      return games
          .where((d) => d.id == '${platform.key}_$productId')
          .firstOrNull;
    }
    if (platform == GamePlatform.steam &&
        RegExp(r'^\d+$').hasMatch(productId)) {
      final data = await request(
        Uri.https('store.steampowered.com', '/api/appdetails', {
          'appids': productId,
          'cc': region.country.toLowerCase(),
          'l': region.steamLanguage,
        }),
      );
      final entry = data[productId];
      if (entry?['success'] != true) return null;
      final game = entry['data'];
      final price = game['price_overview'];
      if (price == null && game['is_free'] != true) return null;
      return GameDeal.fromJson({
        'id': productId,
        'platform': 'steam',
        'title': game['name'],
        'currentPrice': price == null ? 0 : price['final'] / 100,
        'originalPrice': price == null ? 0 : price['initial'] / 100,
        'currency': price?['currency'] ?? region.currency,
        'imageUrl': game['header_image'],
        'storeUrl': 'https://store.steampowered.com/app/$productId/',
        'source': 'Steam · ${region.label}',
      });
    }
    if (platform == GamePlatform.xbox) {
      final provider = StoreProviders(
        request,
        region: region,
        xboxProductIds: [productId],
      );
      return provider.xboxQuotes().then((deals) => deals.firstOrNull);
    }
    if (platform == GamePlatform.epic) {
      final id = productId.split(':').last;
      final offer = await request(
        Uri.https('api.egdata.app', '/offers/$id', {'locale': region.locale}),
      );
      final price = await request(
        Uri.https('api.egdata.app', '/offers/$id/price', {
          'country': region.country,
        }),
      );
      final parsed = _parseEpicElement(
        _epicPrice({...offer, 'price': price}),
        now: DateTime.now().toUtc(),
        discountedOnly: false,
      );
      return parsed == null
          ? null
          : GameDeal.fromJson({...parsed, 'platform': 'epic'});
    }

    return (await collect(
      platform,
      discountedOnly: false,
    )).where((d) => d.id == '${platform.key}_$productId').firstOrNull;
  }

  Future<List<dynamic>> _steam(String query) async {
    final result = await request(
      Uri.https('store.steampowered.com', '/api/storesearch/', {
        'term': query,
        'l': region.steamLanguage,
        'cc': region.country.toLowerCase(),
      }),
    );
    final items = result['items'] as List;
    return [
      for (final item in items)
        if (item['price'] is Map &&
            item['price']['final'] is num &&
            item['price']['initial'] is num &&
            item['price']['initial'] >= 0)
          {
            'id': '${item['id']}',
            'title': item['name'],
            'currentPrice': item['price']['final'] / 100,
            'originalPrice': item['price']['initial'] / 100,
            'currency': item['price']['currency'] ?? region.currency,
            'imageUrl': item['tiny_image'],
            'storeUrl': 'https://store.steampowered.com/app/${item['id']}/',
            'source': 'Steam · ${region.label}',
          },
    ];
  }

  Future<List<dynamic>> _epic({
    String query = '',
    bool discountedOnly = true,
  }) async {
    final now = DateTime.now().toUtc();
    final rows = <Map<String, dynamic>>[];

    final result = await _epicSearch(
      query: query,
      discountedOnly: discountedOnly,
    );
    for (final item
        in (result['offers'] as List).whereType<Map<String, dynamic>>()) {
      final parsed = _parseEpicElement(
        _epicPrice(item),
        now: now,
        discountedOnly: discountedOnly,
      );
      if (parsed != null) rows.add(parsed);
    }

    return rows;
  }

  Map<String, dynamic>? _parseEpicElement(
    Map<String, dynamic> item, {
    required DateTime now,
    bool discountedOnly = true,
  }) {
    final price = item['price']?['totalPrice'];
    if (price == null) return null;
    final currency = price['currencyCode']?.toString();
    if (!region.allowedCurrencies.contains(currency)) return null;

    final originalCents = price['originalPrice'];
    final discountCents = price['discountPrice'];
    if (originalCents is! num || discountCents is! num) return null;
    if (originalCents <= 0 && discountCents <= 0) return null;

    final original = originalCents / 100.0;
    final current = discountCents / 100.0;

    if (current > original) return null;
    if (discountedOnly && current >= original) return null;

    DateTime? expires;
    final promoGroups = item['promotions']?['promotionalOffers'] as List? ?? [];
    for (final group in promoGroups) {
      if (group is! Map) continue;
      final offers = group['promotionalOffers'] as List? ?? [];
      for (final promo in offers) {
        if (promo is! Map) continue;
        final start = DateTime.tryParse(promo['startDate']?.toString() ?? '');
        final end = DateTime.tryParse(promo['endDate']?.toString() ?? '');
        if (start != null &&
            end != null &&
            !start.isAfter(now) &&
            end.isAfter(now)) {
          if (expires == null || end.isBefore(expires)) expires = end;
        }
      }
    }

    final lineOffers = item['price']?['lineOffers'] as List? ?? [];
    for (final offer in lineOffers) {
      if (offer is! Map) continue;
      final rules = offer['appliedRules'] as List? ?? [];
      for (final rule in rules) {
        if (rule is! Map) continue;
        final end = DateTime.tryParse(rule['endDate']?.toString() ?? '');
        if (end != null && end.isAfter(now)) {
          if (expires == null || end.isBefore(expires)) expires = end;
        }
      }
    }
    if (current == 0 && original == 0) return null;
    if (current == 0 && expires == null) return null;
    final mappings = item['catalogNs']?['mappings'] as List? ?? [];
    final offerMappings = item['offerMappings'] as List? ?? [];
    final firstMapping = mappings.isNotEmpty ? mappings.first : null;
    final firstOfferMapping = offerMappings.isNotEmpty
        ? offerMappings.first
        : null;
    final dynamic rawSlug =
        (firstMapping is Map ? firstMapping['pageSlug'] : null) ??
        (firstOfferMapping is Map ? firstOfferMapping['pageSlug'] : null) ??
        item['productSlug'] ??
        item['urlSlug'];
    final slug = rawSlug?.toString().replaceAll('/home', '');
    final storeUrl = slug != null && slug.isNotEmpty
        ? 'https://store.epicgames.com/${region.locale}/p/$slug'
        : null;
    final images = item['keyImages'] as List? ?? [];
    Map? selectedImage;
    for (final img in images) {
      if (img is! Map) continue;
      final type = img['type']?.toString();
      if (type == 'OfferImageWide' || type == 'DieselStoreFrontWide') {
        selectedImage = img;
        break;
      }
    }
    if (selectedImage == null) {
      for (final img in images) {
        if (img is! Map) continue;
        final type = img['type']?.toString();
        if (type == 'OfferImageTall' ||
            type == 'DieselStoreFrontTall' ||
            type == 'Thumbnail') {
          selectedImage = img;
          break;
        }
      }
    }
    selectedImage ??= images.whereType<Map>().firstOrNull;

    final imageUrl = selectedImage?['url']?.toString();
    final title = (item['title'] ?? '').toString().trim();
    if (title.isEmpty) return null;

    final id = '${item['namespace'] ?? 'epic'}:${item['id']}';
    final isFreeGiveaway = current == 0;
    final discountPercent = original > 0
        ? ((1 - current / original) * 100).round()
        : 0;

    final source = isFreeGiveaway
        ? 'Epic · Grátis por tempo limitado'
        : discountPercent > 0
        ? 'Epic Games · -$discountPercent%'
        : 'Epic Games Store';

    return {
      'id': id,
      'title': title,
      'currentPrice': current,
      'originalPrice': original,
      'currency': currency,
      'imageUrl': imageUrl != null && imageUrl.startsWith('http')
          ? imageUrl
          : null,
      'storeUrl': storeUrl,
      if (expires != null) 'expiresAt': expires.toUtc().toIso8601String(),
      'source': source,
    };
  }

  Future<List<GameDeal>> xboxQuotes() async =>
      _normalize(await _xbox(), GamePlatform.xbox, discountedOnly: false);

  Future<List<dynamic>> _xbox() async {
    final ids = xboxProductIds;
    if (ids.isEmpty) {
      throw const FormatException(
        'Adicione IDs de produtos Xbox ou configure uma API de catálogo',
      );
    }
    if (ids.length > 100 ||
        ids.any((id) => !RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(id))) {
      throw const FormatException('Use até 100 IDs Xbox de 12 caracteres');
    }
    final result = await request(
      Uri.https('displaycatalog.mp.microsoft.com', '/v7.0/products', {
        'bigIds': ids.join(','),
        'market': region.country,
        'languages': region.lowerLocale,
      }),
    );
    final rows = <Map<String, dynamic>>[];
    for (final product in result['Products'] as List) {
      final info = (product['LocalizedProperties'] as List).first;
      final images = info['Images'] as List? ?? [];
      var image =
          images.where((i) => i['ImagePurpose'] == 'Poster').firstOrNull?['Uri']
              as String?;
      if (image != null && image.startsWith('//')) image = 'https:$image';
      for (final sku in product['DisplaySkuAvailabilities'] as List? ?? []) {
        if (sku['Sku']?['Properties']?['IsTrial'] == true) continue;
        for (final availability in sku['Availabilities'] as List? ?? []) {
          // Only an outright purchase counts; subscription/trial prices must not appear as free purchases.
          final actions = availability['Actions'] as List? ?? [];
          if (!actions.contains('Purchase')) continue;
          final conditions = availability['Conditions'] as Map? ?? {};
          final end = DateTime.tryParse(
            conditions['EndDate']?.toString() ?? '',
          );
          final start = DateTime.tryParse(
            conditions['StartDate']?.toString() ?? '',
          );
          if ((end != null && !end.isAfter(DateTime.now().toUtc())) ||
              (start != null && start.isAfter(DateTime.now().toUtc()))) {
            continue;
          }
          final price = availability['OrderManagementData']?['Price'];
          if (price == null ||
              !region.allowedCurrencies.contains(price['CurrencyCode']) ||
              price['ListPrice'] is! num ||
              price['MSRP'] is! num ||
              price['MSRP'] < 0 ||
              price['ListPrice'] > price['MSRP']) {
            continue;
          }
          rows.add({
            'id': product['ProductId'],
            'xboxCompatibility': XboxCompatibility.fromStore(product as Map)
                .name,
            'title': info['ProductTitle'],
            'imageUrl': image,
            'currentPrice': price['ListPrice'],
            'originalPrice': price['MSRP'],
            'currency': price['CurrencyCode'],
            if (end != null) 'expiresAt': end.toUtc().toIso8601String(),
            'storeUrl':
                'https://www.xbox.com/${region.locale}/games/store/-/${product['ProductId']}',
            'source': 'Xbox · ${region.label}',
          });
        }
      }
    }
    return rows;
  }
}
