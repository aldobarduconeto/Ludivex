import 'game_deal.dart';

String canonicalStoreUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || uri.host.isEmpty) return '';
  final host = uri.host.toLowerCase();
  final platform = switch (host) {
    'store.steampowered.com' => GamePlatform.steam,
    'www.xbox.com' || 'xbox.com' || 'www.microsoft.com' => GamePlatform.xbox,
    'store.playstation.com' => GamePlatform.playstation,
    'store.epicgames.com' => GamePlatform.epic,
    'www.nuuvem.com' || 'nuuvem.com' => GamePlatform.nuuvem,
    'store.ubisoft.com' => GamePlatform.ubisoft,
    'www.ea.com' || 'ea.com' => GamePlatform.ea,
    'www.nintendo.com' || 'nintendo.com' => GamePlatform.nintendo,
    _ => null,
  };
  if (platform != null) {
    final productId = productIdFromUrl(platform, value!);
    if (productId != null) return '${platform.key}:$productId';
    final marker = uri.pathSegments.indexOf(
      platform == GamePlatform.epic ? 'p' : 'concept',
    );
    if (marker >= 0 && marker + 1 < uri.pathSegments.length) {
      return '${platform.key}:${uri.pathSegments.skip(marker).join('/').toLowerCase()}';
    }
  }
  return '${uri.host.toLowerCase()}${uri.path.replaceFirst(RegExp(r'/$'), '').toLowerCase()}';
}

String? validateStoreUrl(GamePlatform platform, String value) {
  final uri = Uri.tryParse(value.trim());
  final hosts = switch (platform) {
    GamePlatform.playstation => ['store.playstation.com'],
    GamePlatform.xbox => ['www.xbox.com', 'xbox.com', 'www.microsoft.com'],
    GamePlatform.steam => ['store.steampowered.com'],
    GamePlatform.epic => ['store.epicgames.com'],
    GamePlatform.nuuvem => ['www.nuuvem.com', 'nuuvem.com'],
    GamePlatform.ubisoft => ['store.ubisoft.com'],
    GamePlatform.ea => ['www.ea.com', 'ea.com'],
    GamePlatform.nintendo => ['www.nintendo.com', 'nintendo.com'],
  };
  final product =
      uri != null &&
      (productIdFromUrl(platform, value) != null ||
          (platform == GamePlatform.epic &&
              RegExp(
                r'^/(?:[A-Za-z]{2}(?:-[A-Za-z]{2})?/)?p/[^/]+/?$',
              ).hasMatch(uri.path)) ||
          (platform == GamePlatform.playstation &&
              RegExp(
                r'^/[A-Za-z]{2}-[A-Za-z]{2}/concept/\d+/?$',
              ).hasMatch(uri.path)));
  return uri != null &&
          uri.scheme == 'https' &&
          hosts.contains(uri.host) &&
          uri.pathSegments.where((s) => s.isNotEmpty).isNotEmpty &&
          uri.userInfo.isEmpty &&
          value.length <= 2048 &&
          product
      ? null
      : 'Informe o link HTTPS de um jogo na loja selecionada.';
}

String? productIdFromUrl(GamePlatform platform, String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  if (platform == GamePlatform.steam) {
    final index = segments.indexOf('app');
    if (index >= 0 &&
        index + 1 < segments.length &&
        RegExp(r'^\d+$').hasMatch(segments[index + 1]))
      return segments[index + 1];
  }
  if (platform == GamePlatform.xbox) {
    return segments
        .where((s) => RegExp(r'^[A-Za-z0-9]{12}$').hasMatch(s))
        .lastOrNull
        ?.toUpperCase();
  }
  if (platform == GamePlatform.playstation) {
    final index = segments.indexOf('product');
    if (index >= 0 && index + 1 < segments.length) return segments[index + 1];
  }
  if (platform == GamePlatform.epic) {
    final index = segments.indexOf('p');
    if (index >= 0 &&
        index + 1 < segments.length &&
        segments[index + 1].isNotEmpty) {
      return segments[index + 1];
    }
  }
  if (platform == GamePlatform.nuuvem) {
    final index = segments.indexOf('item');
    if (index >= 0 &&
        index + 1 < segments.length &&
        segments[index + 1].isNotEmpty)
      return segments[index + 1];
  }
  if (platform == GamePlatform.ubisoft && segments.isNotEmpty) {
    return RegExp(
      r'^([A-Za-z0-9_-]+)\.html$',
    ).firstMatch(segments.last)?.group(1);
  }
  if (platform == GamePlatform.nintendo) {
    return RegExp(r'^/pt-br/store/products/([a-z0-9-]+)/?$')
        .firstMatch(uri.path)
        ?.group(1);
  }
  if (platform == GamePlatform.ea) {
    final index = segments.indexOf('games');
    if (index >= 0 &&
        index + 2 < segments.length &&
        segments[index + 1].isNotEmpty &&
        segments[index + 2].isNotEmpty)
      return segments.skip(index + 1).take(2).join('/');
  }
  return null;
}

class WishlistItem {
  const WishlistItem({
    required this.id,
    required this.title,
    required this.platform,
    required this.createdAt,
    this.storeUrl,
    this.productId,
    this.targetPrice,
    this.targetCurrency = 'BRL',
    this.notify = true,
    this.quote,
    this.lowestPrice,
    this.lastNotifiedPrice,
  });
  final String id, title;
  final GamePlatform platform;
  final DateTime createdAt;
  final String? storeUrl, productId;
  final double? targetPrice, lowestPrice, lastNotifiedPrice;
  final bool notify;
  final String targetCurrency;
  final GameDeal? quote;

  WishlistItem copyWith({
    String? title,
    double? targetPrice,
    String? targetCurrency,
    bool clearTarget = false,
    bool? notify,
    GameDeal? quote,
    double? lowestPrice,
    double? lastNotifiedPrice,
    bool resetNotification = false,
  }) => WishlistItem(
    id: id,
    title: title ?? this.title,
    platform: platform,
    createdAt: createdAt,
    storeUrl: quote?.storeUrl ?? storeUrl,
    productId: productId,
    targetPrice: clearTarget ? null : targetPrice ?? this.targetPrice,
    targetCurrency: targetCurrency ?? this.targetCurrency,
    notify: notify ?? this.notify,
    quote: quote ?? this.quote,
    lowestPrice: lowestPrice ?? this.lowestPrice,
    lastNotifiedPrice: resetNotification
        ? null
        : lastNotifiedPrice ?? this.lastNotifiedPrice,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'platform': platform.key,
    'createdAt': createdAt.toIso8601String(),
    'storeUrl': storeUrl,
    'productId': productId,
    'targetPrice': targetPrice,
    'targetCurrency': targetCurrency,
    'notify': notify,
    'quote': quote?.toJson(),
    'lowestPrice': lowestPrice,
    'lastNotifiedPrice': lastNotifiedPrice,
  };

  factory WishlistItem.fromJson(Map<String, dynamic> raw) {
    final id = raw['id'] as String;
    final title = raw['title'] as String;
    if (id.isEmpty || title.trim().isEmpty)
      throw const FormatException('Item inválido');
    double? price(Object? value) {
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0)
        throw const FormatException('Preço inválido');
      return value.toDouble();
    }

    final platform = GamePlatform.parse(raw['platform'] as String);
    final quote = raw['quote'] == null
        ? null
        : GameDeal.fromJson(raw['quote'] as Map<String, dynamic>);
    if (quote != null && quote.platform != platform)
      throw const FormatException('Cotação de outra loja');
    return WishlistItem(
      id: id,
      title: title,
      platform: platform,
      createdAt: DateTime.parse(raw['createdAt'] as String),
      storeUrl: raw['storeUrl'] as String?,
      productId: raw['productId'] as String?,
      targetPrice: price(raw['targetPrice']),
      targetCurrency:
          raw['targetCurrency'] as String? ?? quote?.currency ?? 'BRL',
      lowestPrice: price(raw['lowestPrice']),
      lastNotifiedPrice: price(raw['lastNotifiedPrice']),
      notify: raw['notify'] as bool? ?? true,
      quote: quote,
    );
  }
}
