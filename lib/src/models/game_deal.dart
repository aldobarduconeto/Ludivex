import 'package:intl/intl.dart';
import 'xbox_compatibility.dart';
export 'xbox_compatibility.dart';

// Price data validated at the boundary of each store API.
enum GamePlatform {
  playstation('psn'),
  xbox('xbox'),
  steam('steam'),
  epic('epic'),
  nuuvem('nuuvem'),
  ubisoft('ubisoft'),
  ea('ea'),
  nintendo('nintendo');

  const GamePlatform(this.key);
  final String key;

  static GamePlatform parse(String value) => GamePlatform.values.firstWhere(
    (p) => p.key == value || p.name == value,
    orElse: () => throw FormatException('Plataforma desconhecida: $value'),
  );
}

class GameDeal {
  const GameDeal({
    required this.id,
    required this.title,
    required this.platform,
    required this.currentPrice,
    required this.originalPrice,
    required this.discount,
    this.imageUrl,
    this.storeUrl,
    this.currency = 'BRL',
    this.sourceLabel = 'Preço consultado por API',
    this.imageEmoji = '🎮',
    this.expiresAt,
    this.campaignIds = const [],
    this.xboxCompatibility = XboxCompatibility.unknown,
  });
  final String id;
  final String title;
  final GamePlatform platform;
  final double currentPrice;
  final double originalPrice;
  final int discount;
  final String? imageUrl;
  final String? storeUrl;
  final String currency;
  final String sourceLabel;
  final String imageEmoji;
  final DateTime? expiresAt;
  final List<String> campaignIds;
  final XboxCompatibility xboxCompatibility;
  bool get isFree => currentPrice == 0;
  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  factory GameDeal.fromJson(Map<String, dynamic> json) {
    final platform = GamePlatform.parse(json['platform'] as String);
    final id = (json['id'] as String).trim();
    final title = (json['title'] as String).trim();
    final current = (json['currentPrice'] as num).toDouble();
    final original = (json['originalPrice'] as num).toDouble();
    if (id.isEmpty ||
        title.isEmpty ||
        id.length > 200 ||
        title.length > 500 ||
        !current.isFinite ||
        !original.isFinite ||
        current < 0 ||
        original < 0 ||
        current > original ||
        !RegExp(
          r'^[A-Z]{3}$',
        ).hasMatch((json['currency'] ?? 'BRL').toString())) {
      throw const FormatException('Oferta ou preço inválido');
    }
    String? url(Object? value) {
      if (value == null) return null;
      final uri = Uri.tryParse(value.toString());
      return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
          ? uri.toString()
          : null;
    }

    return GameDeal(
      id: id.startsWith('${platform.key}_') ? id : '${platform.key}_$id',
      title: title,
      platform: platform,
      currency: (json['currency'] ?? 'BRL') as String,
      currentPrice: current,
      originalPrice: original,
      discount: original == 0
          ? 0
          : ((1 - current / original) * 100).round().clamp(0, 100),
      imageUrl: url(json['imageUrl']),
      storeUrl: url(json['storeUrl']),
      sourceLabel: json['source'] as String? ?? '${platform.key.toUpperCase()}',
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String).toUtc(),
      campaignIds: List.unmodifiable(
        (json['campaignIds'] as List? ?? []).whereType<String>(),
      ),
      xboxCompatibility: platform == GamePlatform.xbox
          ? XboxCompatibility.fromStore(json)
          : XboxCompatibility.unknown,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'platform': platform.key,
    'currentPrice': currentPrice,
    'originalPrice': originalPrice,
    'discount': discount,
    'currency': currency,
    'imageUrl': imageUrl,
    'storeUrl': storeUrl,
    'source': sourceLabel,
    if (platform == GamePlatform.xbox)
      'xboxCompatibility': xboxCompatibility.name,
    if (campaignIds.isNotEmpty) 'campaignIds': campaignIds,
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
  };

  String get formattedPrice => isFree ? 'Grátis' : _money(currentPrice);
  String get formattedOriginalPrice => _money(originalPrice);
  String formattedHistoricalLow(double price) => _money(price);
  String get formattedSavings {
    final diff = originalPrice - currentPrice;
    return diff > 0 ? _money(diff) : '';
  }

  String _money(double value) => NumberFormat.simpleCurrency(
    locale: 'pt_BR',
    name: currency,
  ).format(value);
}
