import 'game_deal.dart';

class SaleCampaign {
  const SaleCampaign({
    required this.id,
    required this.title,
    required this.platform,
    this.description = '',
    this.imageUrl,
    this.storeUrl,
    this.startsAt,
    this.endsAt,
    this.storewide = false,
  });
  final String id, title, description;
  final GamePlatform platform;
  final String? imageUrl, storeUrl;
  final DateTime? startsAt, endsAt;
  final bool storewide;
  bool get isActive {
    final now = DateTime.now().toUtc();
    return (startsAt == null || !startsAt!.isAfter(now)) &&
        (endsAt == null || endsAt!.isAfter(now));
  }

  factory SaleCampaign.fromJson(
    Map<String, dynamic> raw,
    GamePlatform platform,
  ) {
    final id = raw['id'] as String, title = raw['title'] as String;
    final start = DateTime.parse(raw['startsAt'] as String).toUtc();
    final end = DateTime.parse(raw['endsAt'] as String).toUtc();
    if (id.isEmpty ||
        title.trim().isEmpty ||
        id.length > 200 ||
        !end.isAfter(start))
      throw const FormatException('Campanha inválida');
    String? https(Object? value) {
      final uri = Uri.tryParse(value?.toString() ?? '');
      return uri != null &&
              uri.scheme == 'https' &&
              uri.host.isNotEmpty &&
              uri.userInfo.isEmpty
          ? uri.toString()
          : null;
    }

    return SaleCampaign(
      id: id,
      title: title,
      platform: platform,
      description: raw['description'] as String? ?? '',
      imageUrl: https(raw['imageUrl']),
      storeUrl: https(raw['storeUrl']),
      startsAt: start,
      endsAt: end,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'imageUrl': imageUrl,
    'storeUrl': storeUrl,
    'startsAt': startsAt?.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
  };
}

class DealPage {
  const DealPage(
    this.deals, {
    this.nextCursor,
    this.total,
    this.campaigns = const [],
  });
  final List<GameDeal> deals;
  final String? nextCursor;
  final int? total;
  final List<SaleCampaign> campaigns;
}
