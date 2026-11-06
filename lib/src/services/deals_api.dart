import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_deal.dart';
import '../models/platform.dart';
import '../models/store_region.dart';
import '../models/sale_campaign.dart';
import '../data/store_providers.dart';
import '../views/widgets/app_preferences.dart';
import 'api_transport.dart';
import 'preferences_store.dart';

class _CachedDeals {
  _CachedDeals(
    this.deals,
    this.at, {
    this.nextCursor,
    this.total,
    this.campaigns = const [],
  });
  final List<GameDeal> deals;
  final DateTime at;
  final String? nextCursor;
  final int? total;
  final List<SaleCampaign> campaigns;
}

class DealsApi {
  DealsApi({
    http.Client? client,
    ApiTransport? transport,
    DateTime Function()? now,
  }) : _transport = transport ?? ApiTransport(client: client, now: now),
       _now = now ?? DateTime.now;
  static final instance = DealsApi();
  static const catalogAge = Duration(minutes: 15);
  static const quoteAge = Duration(minutes: 30);
  final ApiTransport _transport;
  final DateTime Function() _now;
  final _cache = <String, _CachedDeals>{};
  final _pending = <String, Future<List<GameDeal>>>{};
  final _lookups = <String, Future<GameDeal?>>{};
  final _quoteCache = <String, (GameDeal?, DateTime)>{};
  final _paginationRetry = <String, DateTime>{};
  final _seenCursors = <String, Set<String>>{};
  Future<void>? _loaded;
  Future<void> _writes = Future.value();
  Future<SharedPreferencesAsync> get _storage => PreferencesStore.open();
  int _cacheWriteId = 0;
  String? _lastCacheWritten;
  int _cacheGeneration = 0;
  Map<String, dynamic> sources = {};
  List<GameDeal> freshDeals = [];
  DateTime? updatedAt;
  String? warning;
  List<String> _extraXboxIds = [];
  Future<List<GameDeal>>? _more;
  ApiTransport get transport => _transport;

  StoreProviders _providers({
    List<String> extraXboxIds = const [],
    bool force = false,
    Duration maxAge = catalogAge,
  }) {
    final prefs = AppPreferences.instance;
    return StoreProviders(
      (uri, {token, body}) =>
          _transport.getJson(uri, force: force, maxAge: maxAge, body: body),
      region: prefs.region,
      apiUrls: Map.of(prefs.apiUrls),
      xboxProductIds: {
        ...prefs.xboxProductIds,
        ...extraXboxIds,
      }.take(100).toList()..sort(),
    );
  }

  String _sourceKey(GamePlatform platform, StoreProviders providers) =>
      jsonEncode([
        platform.key,
        'discount-catalog-v3',
        providers.region.country,
        if (platform == GamePlatform.epic) 'egdata-v1',
        if (platform == GamePlatform.xbox) 'compatibility-v1',
        if (platform == GamePlatform.nuuvem ||
            platform == GamePlatform.ubisoft ||
            platform == GamePlatform.ea)
          'public-store-v1',
        providers.apiUrls[platform] ?? '',
        if (platform == GamePlatform.xbox)
          (List.of(providers.xboxProductIds)..sort()),
      ]);

  Future<void> _loadCache() async {
    final generation = _cacheGeneration;
    try {
      final storage = await _storage;
      if (generation != _cacheGeneration) return;
      final text = await storage.getString('api.catalog.v2');
      if (generation != _cacheGeneration) return;
      if (text == null || text.length > 512 * 1024) return;
      for (final raw in (jsonDecode(text) as List).take(12)) {
        try {
          final at = DateTime.parse(raw['at'] as String);
          final age = _now().difference(at);
          if (age.isNegative || age > const Duration(hours: 24)) continue;
          final deals = (raw['deals'] as List)
              .map((d) => GameDeal.fromJson(d as Map<String, dynamic>))
              .toList();
          _cache.putIfAbsent(
            raw['key'] as String,
            () => _CachedDeals(
              deals,
              at,
              nextCursor: raw['nextCursor'] as String?,
              total: raw['total'] as int?,
              campaigns: [
                for (final c in raw['campaigns'] as List? ?? [])
                  SaleCampaign.fromJson(
                    c as Map<String, dynamic>,
                    GamePlatform.parse(
                      (jsonDecode(raw['key'] as String) as List).first
                          as String,
                    ),
                  ),
              ],
            ),
          );
        } catch (_) {
          /* Skip only the damaged snapshot. */
        }
      }
    } catch (_) {
      /* Persistent caching is optional; memory cache remains available. */
    }
  }

  Future<void> _saveCache(int generation) {
    if (generation != _cacheGeneration) return Future.value();
    final entries = _cache.entries.toList()
      ..sort((a, b) => b.value.at.compareTo(a.value.at));
    final chunks = <String>[];
    var bytes = 2;
    for (final entry in entries.where((e) => e.value.deals.length <= 500)) {
      if (chunks.length == 12) break;
      final chunk = jsonEncode({
        'key': entry.key,
        'at': entry.value.at.toIso8601String(),
        'nextCursor': entry.value.nextCursor,
        'total': entry.value.total,
        'campaigns': entry.value.campaigns.map((c) => c.toJson()).toList(),
        'deals': entry.value.deals.take(500).map((d) => d.toJson()).toList(),
      });
      final size = utf8.encode(chunk).length + (chunks.isEmpty ? 0 : 1);
      if (bytes + size > 512 * 1024) continue;
      chunks.add(chunk);
      bytes += size;
    }
    // Retain recent stores that fit instead of abandoning the entire cache.
    final encoded = '[${chunks.join(',')}]';
    final writeId = ++_cacheWriteId;
    return _writes = _writes.then((_) async {
      if (generation != _cacheGeneration ||
          writeId != _cacheWriteId ||
          encoded == _lastCacheWritten)
        return;
      try {
        final storage = await _storage;
        if (generation == _cacheGeneration && writeId == _cacheWriteId) {
          await PreferencesStore.write(
            () => storage.setString('api.catalog.v2', encoded),
          );
          _lastCacheWritten = encoded;
        }
      } catch (_) {
        /* Failure to cache must not discard valid prices. */
      }
    });
  }

  Future<List<GameDeal>> fetchDeals({
    bool forceRefresh = false,
    List<String> extraXboxIds = const [],
  }) {
    final prefs = AppPreferences.instance;
    _extraXboxIds = List.of(extraXboxIds);
    final signature =
        '${prefs.sourceSignature}:${(List.of(extraXboxIds)..sort()).join(',')}';
    final providers = _providers(
      extraXboxIds: extraXboxIds,
      force: forceRefresh,
    );
    final stores = {...prefs.platforms};
    return _pending.putIfAbsent(
      signature,
      () => _fetch(stores, providers, signature, forceRefresh).whenComplete(() {
        _pending.remove(signature);
      }),
    );
  }

  Future<List<GameDeal>> _fetch(
    Set<GamePlatform> stores,
    StoreProviders providers,
    String signature,
    bool force,
  ) async {
    await (_loaded ??= _loadCache());
    final generation = _cacheGeneration;
    final results = <GameDeal>[], usableQuotes = <GameDeal>[];
    final statuses = <String, dynamic>{};
    var changed = false;
    final checkedTimes = <DateTime>[];
    await Future.wait(
      stores.map((platform) async {
        final key = _sourceKey(platform, providers);
        final cached = _cache[key];
        final age = cached == null ? null : _now().difference(cached.at);
        final reuse =
            age != null &&
            !age.isNegative &&
            age < (force ? ApiTransport.minimumRefresh : catalogAge);
        if (reuse) {
          final deals = cached!.deals.where((d) => !d.isExpired).toList();
          results.addAll(deals);
          usableQuotes.addAll(deals);
          checkedTimes.add(cached.at);
          statuses[platform.key] = {
            'ok': true,
            'count': deals.where((d) => d.discount > 0).length,
            'cached': true,
            'checkedAt': cached.at.toIso8601String(),
            'total': cached.total,
            'complete': cached.nextCursor == null,
          };
          return;
        }
        try {
          final page = await providers.page(platform, discountedOnly: true);
          final all = page.deals;
          final checked = _now();
          if (generation == _cacheGeneration) {
            _paginationRetry.remove(key);
            _seenCursors.remove(key);
            _cache[key] = _CachedDeals(
              all,
              checked,
              nextCursor: page.nextCursor,
              total: page.total,
              campaigns: page.campaigns,
            );
            if (_cache.length > 12) _cache.remove(_cache.keys.first);
            changed = true;
          }
          results.addAll(all);
          usableQuotes.addAll(all);
          checkedTimes.add(checked);
          statuses[platform.key] = {
            'ok': true,
            'count': all.where((d) => d.discount > 0).length,
            'checkedAt': checked.toIso8601String(),
            'total': page.total,
            'complete': page.nextCursor == null,
          };
        } catch (error) {
          _paginationRetry[key] = error is ApiDeferred
              ? error.retryAt
              : _now().add(const Duration(minutes: 1));
          final usable =
              cached != null &&
              age != null &&
              !age.isNegative &&
              age < const Duration(hours: 24);
          if (usable) {
            results.addAll(cached.deals.where((d) => !d.isExpired));
            checkedTimes.add(cached.at);
          }
          final unconfigured =
              platform.requiresCatalogApi &&
              !(providers.apiUrls[platform]?.isNotEmpty ?? false);
          statuses[platform.key] = {
            'ok': false,
            'cached': usable,
            'error': unconfigured
                ? 'Configure a API ou os produtos desta loja'
                : error is FormatException
                ? error.message
                : error is ApiDeferred
                ? error.reason
                : 'API indisponível; nova tentativa será espaçada',
            if (error is ApiDeferred)
              'retryAt': error.retryAt.toIso8601String(),
          };
        }
      }),
    );
    if (changed) await _saveCache(generation);
    if (signature.startsWith('${AppPreferences.instance.sourceSignature}:')) {
      sources = statuses;
      freshDeals = List.unmodifiable(usableQuotes);
      warning = statuses.values.any((s) => s['ok'] != true)
          ? 'Algumas lojas estão em pausa ou indisponíveis. Os preços em cache podem estar desatualizados.'
          : null;
      checkedTimes.sort();
      updatedAt = checkedTimes.firstOrNull;
    }
    return {
      for (final deal in results.where((d) => d.discount > 0 && !d.isExpired))
        deal.id: deal,
    }.values.toList();
  }

  Future<List<GameDeal>> search(
    String query,
    Set<GamePlatform> stores, {
    List<String> extraXboxIds = const [],
  }) async {
    final term = query.trim().toLowerCase();
    if (term.length < 3 || stores.isEmpty) return [];
    final providers = _providers(
      extraXboxIds: extraXboxIds,
      maxAge: const Duration(minutes: 5),
    );
    final results = <GameDeal>[];
    var successes = 0;
    await Future.wait(
      stores.map((store) async {
        try {
          results.addAll(
            await providers.collect(store, query: term, discountedOnly: false),
          );
          successes++;
        } catch (_) {
          /* Unavailable sources must not hide valid results. */
        }
      }),
    );
    if (successes == 0)
      throw Exception(
        'As APIs estão em pausa ou indisponíveis. Tente mais tarde ou adicione pelo link.',
      );
    return {for (final deal in results) deal.id: deal}.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  List<GameDeal> get loadedDeals {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    return {
      for (final p in AppPreferences.instance.platforms)
        for (final d in _cache[_sourceKey(p, providers)]?.deals ?? <GameDeal>[])
          if (!d.isExpired && d.discount > 0) d.id: d,
    }.values.toList();
  }

  bool get hasMore => hasMoreFor(null);
  Duration get collectionDelay {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    final delays = <Duration>[];
    for (final platform in AppPreferences.instance.platforms) {
      final key = _sourceKey(platform, providers);
      if (_cache[key]?.nextCursor == null &&
          sources[platform.key]?['ok'] != false)
        continue;
      final retry = _paginationRetry[key];
      if (retry == null || !retry.isAfter(_now()))
        return const Duration(seconds: 6);
      delays.add(retry.difference(_now()));
    }
    if (delays.isEmpty) return const Duration(seconds: 6);
    delays.sort();
    return delays.first < const Duration(seconds: 6)
        ? const Duration(seconds: 6)
        : delays.first;
  }

  bool hasMoreFor(GamePlatform? filter) {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    return AppPreferences.instance.platforms
        .where((p) => filter == null || p == filter)
        .any(
          (p) =>
              _cache[_sourceKey(p, providers)]?.nextCursor != null ||
              sources[p.key]?['ok'] == false,
        );
  }

  List<SaleCampaign> get campaigns {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    final result = <SaleCampaign>[];
    for (final platform in AppPreferences.instance.orderedPlatforms) {
      final snapshot = _cache[_sourceKey(platform, providers)];
      if (snapshot == null) continue;
      result.addAll(snapshot.campaigns.where((c) => c.isActive));
      if (snapshot.deals.any((d) => d.discount > 0 && !d.isExpired) ||
          snapshot.nextCursor != null) {
        result.add(
          SaleCampaign(
            id: 'all-${platform.key}',
            title: switch (platform) {
              GamePlatform.steam => 'Promoções Steam',
              GamePlatform.epic => 'Ofertas Epic Games',
              GamePlatform.xbox => 'Promoções Xbox',
              GamePlatform.playstation => 'Ofertas PlayStation',
              GamePlatform.nuuvem => 'Ofertas Nuuvem',
              GamePlatform.ubisoft => 'Ofertas Ubisoft',
              GamePlatform.ea => 'Ofertas EA',
              GamePlatform.nintendo => 'Ofertas Nintendo eShop',
            },
            platform: platform,
            storewide: true,
            description: 'Explore todas as ofertas disponíveis nesta loja',
          ),
        );
      }
    }
    return result;
  }

  Future<List<GameDeal>> loadMore({GamePlatform? platform}) =>
      _more ??= _loadMore(platform).whenComplete(() {
        _more = null;
      });

  Future<List<GameDeal>> _loadMore(GamePlatform? filter) async {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    final generation = _cacheGeneration;
    var paused = false;
    await Future.wait(
      AppPreferences.instance.platforms
          .where((p) => filter == null || p == filter)
          .map((platform) async {
            final key = _sourceKey(platform, providers);
            final previous = _cache[key];
            if (previous?.nextCursor == null &&
                sources[platform.key]?['ok'] != false)
              return;
            if (_paginationRetry[key]?.isAfter(_now()) == true) {
              paused = true;
              return;
            }
            try {
              final page = await providers.page(
                platform,
                cursor: previous?.nextCursor,
                discountedOnly: true,
              );
              if (generation != _cacheGeneration ||
                  !identical(_cache[key], previous))
                return;
              final merged = {
                for (final deal in [...?previous?.deals, ...page.deals])
                  deal.id: deal,
              }.values.toList();
              final seen = _seenCursors.putIfAbsent(key, () => <String>{});
              if (previous?.nextCursor != null) seen.add(previous!.nextCursor!);
              final repeated =
                  page.nextCursor != null && seen.contains(page.nextCursor);
              _paginationRetry.remove(key);
              _cache[key] = _CachedDeals(
                merged,
                previous?.at ?? _now(),
                nextCursor: repeated ? null : page.nextCursor,
                total: page.total ?? previous?.total,
                campaigns: {
                  for (final c in [...?previous?.campaigns, ...page.campaigns])
                    c.id: c,
                }.values.toList(),
              );
              sources[platform.key] = {
                ...?sources[platform.key] as Map?,
                'ok': true,
                'paginationStopped': repeated,
                'error': null,
                'count': merged
                    .where((d) => !d.isExpired && d.discount > 0)
                    .length,
                'collecting': !repeated && page.nextCursor != null,
                'complete': !repeated && page.nextCursor == null,
              };
              if (repeated) warning = 'A loja repetiu uma página. A coleta dessa fonte foi interrompida para evitar consultas duplicadas.';
            } catch (error) {
              paused = true;
              if (generation != _cacheGeneration) return;
              _paginationRetry[key] = error is ApiDeferred
                  ? error.retryAt
                  : _now().add(const Duration(minutes: 1));
              warning = 'Não foi possível obter mais ofertas agora. Aguarde a pausa da API e tente novamente.';
            }
          }),
    );
    if (!paused &&
        !sources.values.any(
          (status) =>
              status['ok'] != true || status['paginationStopped'] == true,
        ))
      warning = null;
    await _saveCache(generation);
    freshDeals = List.unmodifiable(loadedDeals);
    return loadedDeals;
  }

  Future<DealPage> campaignPage(SaleCampaign campaign, {String? cursor}) async {
    final providers = _providers(extraXboxIds: _extraXboxIds);
    if (campaign.storewide && cursor == null) {
      final snapshot = _cache[_sourceKey(campaign.platform, providers)];
      if (snapshot != null)
        return DealPage(
          snapshot.deals.where((d) => d.discount > 0 && !d.isExpired).toList(),
          nextCursor: snapshot.nextCursor,
          total: snapshot.total,
        );
    }
    return providers.page(
      campaign.platform,
      cursor: cursor,
      campaignId: campaign.storewide ? null : campaign.id,
    );
  }

  String _quoteKey(GamePlatform platform, String id) => jsonEncode([
    platform.key,
    AppPreferences.instance.region.country,
    AppPreferences.instance.apiUrls[platform] ?? '',
    id,
  ]);

  bool hasCachedQuote(GamePlatform platform, String id) {
    final cached = _quoteCache[_quoteKey(platform, id)];
    return cached != null &&
        _now().difference(cached.$2) < quoteAge &&
        !(cached.$1?.isExpired ?? false);
  }

  Future<GameDeal?> lookup(
    GamePlatform platform,
    String productId, {
    bool force = false,
  }) {
    final key = _quoteKey(platform, productId);
    final cached = _quoteCache[key];
    if (cached != null &&
        !(cached.$1?.isExpired ?? false) &&
        _now().difference(cached.$2) <
            (force ? ApiTransport.minimumRefresh : quoteAge))
      return Future.value(cached.$1);
    return _lookups.putIfAbsent(key, () async {
      try {
        final quote = await _providers(
          force: force,
          maxAge: quoteAge,
        ).lookup(platform, productId);
        _quoteCache[key] = (quote, _now());
        if (_quoteCache.length > 500)
          _quoteCache.remove(_quoteCache.keys.first);
        return quote;
      } finally {
        _lookups.remove(key);
      }
    });
  }

  /// One request per batch instead of one request per Xbox title.
  Future<List<GameDeal>> xboxQuotes(List<String> ids) async {
    if (ids.isEmpty) return [];
    return StoreProviders(
      (uri, {token, body}) =>
          _transport.getJson(uri, maxAge: quoteAge, body: body),
      region: AppPreferences.instance.region,
      apiUrls: Map.of(AppPreferences.instance.apiUrls),
      xboxProductIds: (ids.toSet().toList()..sort()).take(100).toList(),
    ).xboxQuotes();
  }

  Future<int> testSource(
    GamePlatform platform, {
    String? url,
    List<String> xboxIds = const [],
    StoreRegion? region,
  }) async {
    final providers = StoreProviders(
      (uri, {token, body}) => _transport.getJson(uri, body: body),
      region: region ?? AppPreferences.instance.region,
      apiUrls: {if (url?.isNotEmpty ?? false) platform: url!},
      xboxProductIds: xboxIds,
    );
    return (await providers.collect(platform, discountedOnly: false)).length;
  }

  Future<void> clearCache() async {
    _cacheGeneration++;
    _cacheWriteId++;
    _lastCacheWritten = null;
    _cache.clear();
    _quoteCache.clear();
    _paginationRetry.clear();
    _seenCursors.clear();
    _transport.clearCache();
    await _writes;
    try {
      final storage = await _storage;
      await PreferencesStore.write(() async {
        await storage.remove('api.catalog.v1');
        await storage.remove('api.catalog.v2');
      });
    } catch (_) {}
  }

  void dispose() => _transport.dispose();
}
