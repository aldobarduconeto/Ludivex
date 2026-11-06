import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/game_deal.dart';
import '../models/sale_campaign.dart';
import '../models/store_region.dart';
import 'store_providers.dart' show JsonRequest;

/// Public storefront catalogs. Neither endpoint requires a personal API key.
class ConsoleCatalogs {
  ConsoleCatalogs(this.request, this.region);
  final JsonRequest request;
  final StoreRegion region;

  // Public persisted operation from the PS Store category client. This is a
  // query identifier, not an account credential. Changes fail visibly.
  static const psnCategoryHash =
      '88c0b9a1273c6d320c51cd73e390924e21ae28bf09f01cde8b84b1034b16cd03';
  static const psnDealsCategory = '3f772501-f6f8-49b7-abac-874a88ca4897';

  Future<DealPage> playstation({
    String? cursor,
    bool discountedOnly = true,
    String query = '',
  }) async {
    final offset = int.tryParse(cursor ?? '0');
    if (offset == null || offset < 0)
      throw const FormatException('Página PSN inválida');
    final response = await request(
      Uri.https('web.np.playstation.com', '/api/graphql/v1/op', {
        'locale': region.lowerLocale,
        'operationName': 'categoryGridRetrieve',
        'variables': jsonEncode({
          'id': psnDealsCategory,
          'pageArgs': {'size': 24, 'offset': offset},
        }),
        'extensions': jsonEncode({
          'persistedQuery': {'version': 1, 'sha256Hash': psnCategoryHash},
        }),
      }),
    );
    final grid = response['data']?['categoryGridRetrieve'];
    if (grid is! Map || grid['products'] is! List)
      throw FormatException(
        'Catálogo público PSN indisponível em ${region.label}',
      );
    final deals = <GameDeal>[];
    for (final row in grid['products'] as List) {
      if (row is! Map ||
          !const {
            'FULL_GAME',
            'PREMIUM_EDITION',
            'GAME_BUNDLE',
          }.contains(row['storeDisplayClassification']))
        continue;
      final price = row['price'];
      if (price is! Map ||
          price['isTiedToSubscription'] == true ||
          price['isExclusive'] == true)
        continue;
      final current = region.parsePrice(price['discountedPrice'] as String?);
      final original = region.parsePrice(price['basePrice'] as String?);
      if (current == null ||
          original == null ||
          current < 0 ||
          original < current)
        continue;
      final id = row['id']?.toString() ?? '';
      final title = row['name']?.toString().trim() ?? '';
      if (id.isEmpty ||
          title.isEmpty ||
          (query.isNotEmpty &&
              !title.toLowerCase().contains(query.toLowerCase()) &&
              id != query))
        continue;
      final images = (row['media'] as List? ?? []).whereType<Map>().where(
        (i) => i['type'] == 'IMAGE',
      );
      final image =
          images.where((i) => i['role'] == 'MASTER').firstOrNull ??
          images.where((i) => i['role'] == 'GAMEHUB_COVER_ART').firstOrNull ??
          images.firstOrNull;
      final deal = GameDeal.fromJson({
        'id': id,
        'platform': 'psn',
        'title': title,
        'currentPrice': current,
        'originalPrice': original,
        'currency': region.country == 'AR' ? 'USD' : region.currency,
        'imageUrl': image?['url'],
        'storeUrl':
            'https://store.playstation.com/${region.lowerLocale}/product/$id',
        'source': 'PlayStation Store · ${region.label}',
      });
      if (!discountedOnly || deal.discount > 0) deals.add(deal);
    }
    final info = grid['pageInfo'] as Map? ?? {};
    final size = (info['size'] as num?)?.toInt() ?? 24;
    final total = (info['totalCount'] as num?)?.toInt();
    return DealPage(
      deals,
      total: total,
      nextCursor:
          info['isLast'] == true ||
              size <= 0 ||
              (grid['products'] as List).isEmpty ||
              (total != null && offset + size >= total)
          ? null
          : '${offset + size}',
    );
  }

  Future<DealPage> xbox({
    String? cursor,
    bool discountedOnly = true,
    String query = '',
  }) async {
    if (cursor != null && cursor.length > 16000)
      throw const FormatException('Página Xbox inválida');
    final filters = base64Encode(
      utf8.encode(
        jsonEncode({
          if (discountedOnly)
            'Price': {
              'id': 'Price',
              'choices': [
                {'id': '0'},
              ],
            },
          'orderby': {
            'id': 'orderby',
            'choices': [
              {
                'id': discountedOnly
                    ? 'DiscountPercentage desc'
                    : 'MostPopular desc',
              },
            ],
          },
        }),
      ),
    );
    final response = await request(
      Uri.https(
        'emerald.xboxservices.com',
        '/xboxcomfd/${query.isEmpty ? 'browse' : 'search/games'}',
        {'locale': region.locale},
      ),
      body: {
        'ReturnFilters': false,
        'ChannelKeyToBeUsedInResponse': 'ludivex',
        'Filters': filters,
        if (cursor != null) 'EncodedCT': cursor,
        if (query.isNotEmpty) 'Query': query,
        if (query.isNotEmpty) 'ChannelId': 'games',
      },
    );
    final channel = response['channels']?['ludivex'];
    if (channel is! Map ||
        response['productSummaries'] is! List ||
        response['availabilitySummaries'] is! List)
      throw FormatException(
        'Catálogo público Xbox indisponível em ${region.label}',
      );
    final products = {
      for (final row in (response['productSummaries'] as List).whereType<Map>())
        row['productId']: row,
    };
    final skus = {
      for (final row
          in (response['skuSummaries'] as List? ?? []).whereType<Map>())
        '${row['productId']}:${row['skuId']}': row,
    };
    final deals = <String, GameDeal>{};
    final compatibility = <String, XboxCompatibility>{};
    final productIds = products.keys.whereType<String>().toList();
    for (var start = 0; start < productIds.length; start += 100) {
      try {
        final detail = await request(
          Uri.https('displaycatalog.mp.microsoft.com', '/v7.0/products', {
            'bigIds': productIds.skip(start).take(100).join(','),
            'market': region.country,
            'languages': region.lowerLocale,
          }),
        );
        for (final product
            in (detail['Products'] as List? ?? []).whereType<Map>()) {
          if (product['ProductId'] is String)
            compatibility[product['ProductId'] as String] =
                XboxCompatibility.fromStore(product);
        }
      } on Object {
        // Keep available prices when optional compatibility metadata is unavailable.
      }
    }
    for (final availability
        in (response['availabilitySummaries'] as List).whereType<Map>()) {
      final id = availability['productId'];
      final row = products[id];
      final price = availability['price'];
      final sku = skus['$id:${availability['skuId']}'];
      if (row == null ||
          price is! Map ||
          sku?['isTrial'] == true ||
          sku?['isGamesWithGoldSku'] == true)
        continue;
      if (!(availability['actions'] as List? ?? []).contains('Purchase'))
        continue;
      final eligibility = price['eligibilityInfo']?['eligibility'];
      if (eligibility != null && eligibility != 'None') continue;
      if (!region.allowedCurrencies.contains(price['currency'])) continue;
      final current = price['listPrice'], original = price['msrp'];
      if (current is! num ||
          original is! num ||
          current < 0 ||
          original < current)
        continue;
      final expiry = _xboxDate(availability['endDateUtc'] as String?);
      if (expiry != null && !expiry.isAfter(DateTime.now().toUtc())) continue;
      final title = row['title']?.toString().trim() ?? '';
      if (title.isEmpty || id is! String) continue;
      final deal = GameDeal.fromJson({
        'id': id,
        'platform': 'xbox',
        'xboxCompatibility':
            (compatibility[id] ?? XboxCompatibility.fromStore(row)).name,
        'title': title,
        'currentPrice': current,
        'originalPrice': original,
        'currency': price['currency'],
        'imageUrl':
            row['images']?['poster']?['url'] ??
            row['images']?['boxArt']?['url'],
        'storeUrl': 'https://www.xbox.com/${region.locale}/games/store/-/$id',
        if (expiry != null) 'expiresAt': expiry.toIso8601String(),
        'source': 'Xbox Store · ${region.label}',
      });
      if (discountedOnly && deal.discount <= 0) continue;
      if (!deals.containsKey(id) || deals[id]!.currentPrice > deal.currentPrice)
        deals[id] = deal;
    }
    final next = channel['encodedCT']?.toString();
    return DealPage(
      deals.values.toList(),
      total: (channel['totalItems'] as num?)?.toInt(),
      nextCursor: next == null || next.isEmpty || next == cursor ? null : next,
    );
  }

  DateTime? _xboxDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateFormat(
        'MM/dd/yyyy HH:mm:ss',
        'en_US',
      ).parseStrict(value, true);
    } on FormatException {
      return DateTime.tryParse(value)?.toUtc();
    }
  }
}
