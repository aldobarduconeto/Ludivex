import 'api_transport.dart';

typedef GameNews = ({String title, Uri url, DateTime date});

class GameNewsService {
  const GameNewsService(this.transport);

  final ApiTransport transport;

  Future<List<GameNews>?> load(String title, {String? target}) async {
    final appId =
        (target == null ? null : _steamAppId(target)) ??
        await _findAppId(title);
    if (appId == null) return null;

    final data = await transport.getJson(
      Uri.https('api.steampowered.com', '/ISteamNews/GetNewsForApp/v2/', {
        'appid': appId,
        'count': '15',
        'maxlength': '1',
      }),
    );
    final appNews = data['appnews'];
    final items = appNews is Map ? appNews['newsitems'] : null;
    if (items is! List) {
      throw const FormatException('Resposta de notícias inválida');
    }

    final news = <GameNews>[];
    final seen = <Uri>{};
    for (final item in items.whereType<Map>()) {
      final title = item['title'];
      final date = item['date'];
      final link = item['url'];
      final url = link is String ? Uri.tryParse(link) : null;
      if (title is! String ||
          title.trim().isEmpty ||
          date is! int ||
          date < 0 ||
          date > 8640000000000 ||
          url == null ||
          !const {'https', 'http'}.contains(url.scheme) ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          !seen.add(url)) {
        continue;
      }
      news.add((
        title: title.trim(),
        url: url,
        date: DateTime.fromMillisecondsSinceEpoch(date * 1000),
      ));
    }
    return news..sort((a, b) => b.date.compareTo(a.date));
  }

  static String? _steamAppId(String target) {
    final uri = Uri.tryParse(target);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (uri.scheme == 'steam' &&
        const {'run', 'rungameid', 'launch', 'install'}.contains(uri.host) &&
        segments.isNotEmpty) {
      return _validId(segments.first);
    }
    if (const {'https', 'http'}.contains(uri.scheme) &&
        const {
          'store.steampowered.com',
          'steamcommunity.com',
        }.contains(uri.host) &&
        segments.length >= 2 &&
        segments.first == 'app') {
      return _validId(segments[1]);
    }
    return null;
  }

  Future<String?> _findAppId(String title) async {
    final data = await transport.getJson(
      Uri.https('store.steampowered.com', '/api/storesearch/', {
        'term': title,
        'l': 'brazilian',
        'cc': 'br',
      }),
    );
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('Resposta da busca Steam inválida');
    }
    final normalized = title.trim().toLowerCase();
    final ids = {
      for (final item in items.whereType<Map>())
        if (item['name'] is String &&
            (item['name'] as String).trim().toLowerCase() == normalized)
          _validId('${item['id']}'),
    }.whereType<String>().toSet();
    return ids.length == 1 ? ids.single : null;
  }

  static String? _validId(String value) {
    final id = int.tryParse(value);
    return id != null && id > 0 && id <= 0xffffffff ? id.toString() : null;
  }
}
