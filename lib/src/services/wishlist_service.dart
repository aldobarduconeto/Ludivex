import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_deal.dart';
import '../views/widgets/app_preferences.dart';
import '../models/wishlist_item.dart';
import 'deals_api.dart';
import 'preferences_store.dart';

class WishlistService extends ChangeNotifier {
  WishlistService();
  static final instance = WishlistService();
  late SharedPreferencesAsync _storage;
  final _items = <String, WishlistItem>{};
  final _canonical = <String, WishlistItem>{};
  final _alerts = <Map<String, dynamic>>[];
  Future<void> _queue = Future.value();
  Future<void>? _refresh;
  String? _lastWritten;
  int _quoteCursor = 0, _xboxCursor = 0;
  List<WishlistItem>? _cachedItems;
  List<String>? _cachedXboxIds;
  List<Map<String, dynamic>> _cachedAlerts = const [];

  List<WishlistItem> get items =>
      _cachedItems ??= List.unmodifiable(_items.values);
  List<Map<String, dynamic>> get alerts => _cachedAlerts;
  List<String> get xboxIds => _cachedXboxIds ??= items
      .where((i) => i.platform == GamePlatform.xbox && i.productId != null)
      .map((i) => i.productId!)
      .toList();

  void _rebuildIndex() {
    _canonical.clear();
    for (final item in _items.values) {
      final canon = canonicalStoreUrl(item.storeUrl);
      if (canon.isNotEmpty) _canonical[canon] = item;
    }
    final sorted = _items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cachedItems = List.unmodifiable(sorted);
    _cachedXboxIds = null;
    _cachedAlerts = List.unmodifiable(
      _alerts.map((e) => Map<String, dynamic>.unmodifiable(e)),
    );
  }

  Future<void> load({SharedPreferencesAsync? storage}) async {
    await _queue;
    _lastWritten = null;
    _storage = storage ?? await PreferencesStore.open();
    final snapshot = await _storage.getAll(
      allowList: {'wishlist.v3', 'savedDeals', 'wishlist'},
    );
    _items.clear();
    _alerts.clear();
    try {
      final saved = jsonDecode(snapshot['wishlist.v3'] as String? ?? '{}');
      final entries = saved is List ? saved : (saved['items'] as List? ?? []);
      for (final raw in entries) {
        try {
          final item = WishlistItem.fromJson(raw as Map<String, dynamic>);
          _items[item.id] = item;
        } catch (_) {
          /* Skip damaged entries. */
        }
      }
      if (saved is Map && saved['alerts'] is List) {
        for (final event in saved['alerts'] as List) {
          try {
            final entry = Map<String, dynamic>.from(event as Map);
            GameDeal.fromJson(entry['deal'] as Map<String, dynamic>);
            _alerts.add(entry);
          } catch (_) {
            /* Skip invalid optional history entries. */
          }
        }
      }
    } catch (_) {
      /* Recover independently from settings. */
    }
    if (snapshot['wishlist.v3'] == null) {
      try {
        for (final raw
            in jsonDecode(snapshot['savedDeals'] as String? ?? '[]') as List) {
          try {
            final deal = GameDeal.fromJson(raw as Map<String, dynamic>);
            final unknown =
                deal.sourceLabel == 'Aguardando atualização do preço';
            _items[deal.id] = WishlistItem(
              id: deal.id,
              title: deal.title,
              platform: deal.platform,
              storeUrl: deal.storeUrl,
              productId: deal.id.substring(deal.platform.key.length + 1),
              createdAt: DateTime.now(),
              quote: unknown ? null : deal,
              lowestPrice: unknown ? null : deal.currentPrice,
            );
          } catch (_) {
            /* Preserve all valid legacy items. */
          }
        }
      } catch (_) {
        /* No usable legacy snapshot. */
      }
      for (final id
          in (snapshot['wishlist'] as List? ?? []).whereType<String>()) {
        final store = GamePlatform.values
            .where((p) => id.startsWith('${p.key}_'))
            .firstOrNull;
        if (store != null && !_items.containsKey(id))
          _items[id] = WishlistItem(
            id: id,
            title: 'Jogo salvo',
            platform: store,
            productId: id.substring(store.key.length + 1),
            createdAt: DateTime.now(),
          );
      }
      await _persist();
      await PreferencesStore.write(() async {
        await _storage.remove('savedDeals');
        await _storage.remove('wishlist');
      });
    }
    _rebuildIndex();
  }

  WishlistItem? find(GameDeal deal) {
    final direct = _items[deal.id];
    if (direct != null) return direct;
    if (deal.storeUrl == null) return null;
    final canon = canonicalStoreUrl(deal.storeUrl);
    return canon.isEmpty ? null : _canonical[canon];
  }

  bool contains(GameDeal deal) {
    if (_items.containsKey(deal.id)) return true;
    if (deal.storeUrl == null) return false;
    final canon = canonicalStoreUrl(deal.storeUrl);
    return canon.isNotEmpty && _canonical.containsKey(canon);
  }

  Future<T> _mutate<T>(T Function() action) {
    final task = _queue.then((_) async {
      final before = Map<String, WishlistItem>.of(_items);
      final alertsBefore = List<Map<String, dynamic>>.of(_alerts);
      try {
        final value = action();
        _rebuildIndex();
        if (await _persist()) notifyListeners();
        return value;
      } catch (_) {
        _items
          ..clear()
          ..addAll(before);
        _alerts
          ..clear()
          ..addAll(alertsBefore);
        _rebuildIndex();
        rethrow;
      }
    });
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return _queue.then((_) => task);
  }

  Future<bool> _persist() async {
    final encoded = jsonEncode({
      'items': _items.values.map((i) => i.toJson()).toList(),
      'alerts': _alerts,
    });
    if (encoded == _lastWritten) return false;
    await PreferencesStore.write(
      () => _storage.setString('wishlist.v3', encoded),
    );
    _lastWritten = encoded;
    return true;
  }

  void _validateTarget(double? target) {
    if (target != null && (!target.isFinite || target < 0))
      throw const FormatException('Preço desejado inválido');
  }

  Future<WishlistItem> addDeal(
    GameDeal deal, {
    double? targetPrice,
    bool notify = true,
  }) => _mutate(() {
    _validateTarget(targetPrice);
    final existing = find(deal);
    if (existing != null) return existing;
    if (_items.length >= 500) throw StateError('Sua lista atingiu 500 jogos');
    final item = WishlistItem(
      id: deal.id,
      title: deal.title,
      platform: deal.platform,
      storeUrl: deal.storeUrl,
      productId: deal.id.substring(deal.platform.key.length + 1),
      createdAt: DateTime.now(),
      targetPrice: targetPrice,
      targetCurrency: deal.currency,
      notify: notify,
      quote: deal,
      lowestPrice: deal.currentPrice,
    );
    _items[item.id] = item;
    return item;
  });

  Future<WishlistItem> addManual({
    required GamePlatform platform,
    required String title,
    required String storeUrl,
    double? targetPrice,
    bool notify = true,
  }) => _mutate(() {
    _validateTarget(targetPrice);
    if (title.trim().isEmpty || title.trim().length > 200)
      throw const FormatException('Informe o nome do jogo');
    final error = validateStoreUrl(platform, storeUrl);
    if (error != null) throw FormatException(error);
    final canonical = canonicalStoreUrl(storeUrl);
    final duplicate = _items.values
        .where(
          (i) =>
              i.platform == platform &&
              canonicalStoreUrl(i.storeUrl) == canonical,
        )
        .firstOrNull;
    if (duplicate != null) return duplicate;
    if (_items.length >= 500) throw StateError('Sua lista atingiu 500 jogos');
    final productId = productIdFromUrl(platform, storeUrl);
    final id = productId == null
        ? '${platform.key}_link_${Uri.encodeComponent(canonical)}'
        : '${platform.key}_$productId';
    if (_items.containsKey(id)) return _items[id]!;
    final item = WishlistItem(
      id: id,
      title: title.trim(),
      platform: platform,
      storeUrl: storeUrl.trim(),
      productId: productId,
      createdAt: DateTime.now(),
      targetPrice: targetPrice,
      targetCurrency: AppPreferences.instance.region.currency,
      notify: notify,
    );
    _items[id] = item;
    return item;
  });

  Future<void> update(
    String id, {
    double? targetPrice,
    String? targetCurrency,
    required bool notify,
  }) => _mutate(() {
    _validateTarget(targetPrice);
    final item = _items[id];
    if (item == null) return;
    _items[id] = item.copyWith(
      targetPrice: targetPrice,
      clearTarget: targetPrice == null,
      targetCurrency: targetCurrency,
      notify: notify,
      resetNotification: item.targetPrice != targetPrice,
    );
  });
  Future<void> restore(WishlistItem item) => _mutate(() {
    if (_items.length >= 500) throw StateError('Limite da lista');
    _items.putIfAbsent(item.id, () => item);
  });
  Future<void> remove(String id) => _mutate(() {
    _items.remove(id);
  });
  Future<void> clearAlerts() => _mutate(() {
    _alerts.clear();
  });
  Future<void> clear() => _mutate(() {
    _items.clear();
    _alerts.clear();
  });

  String exportJson() =>
      jsonEncode(items.map((item) => item.toJson()).toList());

  Future<int> importJson(String rawJson) async {
    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException(
        'O arquivo de importação deve ser uma lista de jogos.',
      );
    }
    final imported = <WishlistItem>[];
    for (final element in decoded) {
      if (element is Map) {
        try {
          final item = WishlistItem.fromJson(
            Map<String, dynamic>.from(element),
          );
          imported.add(item);
        } catch (_) {}
      }
    }
    if (imported.isEmpty) return 0;
    await _mutate(() {
      for (final item in imported) {
        _items[item.id] = item;
      }
      return imported.length;
    });
    return imported.length;
  }

  Future<void> refresh(
    DealsApi api, {
    List<GameDeal> knownQuotes = const [],
    bool notifications = true,
    int minimumDiscount = 0,
    Future<void> Function(GameDeal)? onAlert,
  }) => _refresh ??= _refreshQuotes(
    api,
    knownQuotes,
    notifications,
    minimumDiscount,
    onAlert,
  ).whenComplete(() => _refresh = null);

  Future<void> _refreshQuotes(
    DealsApi api,
    List<GameDeal> known,
    bool notifications,
    int minimum,
    Future<void> Function(GameDeal)? onAlert,
  ) async {
    final quotes = {for (final quote in known) quote.id: quote};
    final knownUrls = known
        .map((q) => canonicalStoreUrl(q.storeUrl))
        .where((u) => u.isNotEmpty)
        .toSet();
    final pending = items
        .where(
          (i) =>
              !quotes.containsKey(i.id) &&
              !knownUrls.contains(canonicalStoreUrl(i.storeUrl)),
        )
        .toList();
    // Full-price Xbox quotes are obtained in a batch, including followed games
    // outside the first 100 catalog IDs. Rotate large wishlists across cycles.
    final xbox = pending
        .where((i) => i.platform == GamePlatform.xbox && i.productId != null)
        .toList();
    final batched = <String>{};
    if (xbox.isNotEmpty) {
      final offset = _xboxCursor % xbox.length;
      final batch = List.generate(
        min(100, xbox.length),
        (i) => xbox[(offset + i) % xbox.length],
      );
      _xboxCursor = (offset + batch.length) % xbox.length;
      batched.addAll(xbox.map((i) => i.id));
      try {
        for (final quote in await api.xboxQuotes(
          batch.map((i) => i.productId!).toList(),
        )) {
          if (!quote.isExpired) quotes[quote.id] = quote;
        }
      } catch (_) {
        /* Backoff and cached prices are handled by the API client. */
      }
    }
    final individual = pending
        .where((i) => !batched.contains(i.id) && i.productId != null)
        .toList();
    final scheduled = <WishlistItem>[];
    if (individual.isNotEmpty) {
      final offset = _quoteCursor % individual.length;
      var uncached = 0;
      for (var n = 0; n < individual.length; n++) {
        final item = individual[(offset + n) % individual.length];
        if (api.hasCachedQuote(item.platform, item.productId!))
          scheduled.add(item);
        else if (uncached < 8) {
          scheduled.add(item);
          uncached++;
        }
      }
      _quoteCursor =
          (offset + min(8, individual.length).toInt()) % individual.length;
    }
    var index = 0;
    await Future.wait(
      List.generate(min(2, scheduled.length), (_) async {
        while (index < scheduled.length) {
          final item = scheduled[index++];
          if (item.productId == null) continue;
          try {
            final quote = await api.lookup(item.platform, item.productId!);
            if (quote != null && !quote.isExpired) quotes[quote.id] = quote;
          } catch (_) {
            /* An unavailable quote never clears the saved game. */
          }
        }
      }),
    );
    if (quotes.isEmpty) return;
    final notify = <GameDeal>[];
    await _mutate(() {
      for (final quote in quotes.values) {
        final item = find(quote);
        if (item == null || quote.isExpired) continue;
        final price = (quote.currentPrice * 100).round();
        final currencyChanged =
            item.quote != null && item.quote!.currency != quote.currency;
        final old = currencyChanged || item.lowestPrice == null
            ? null
            : (item.lowestPrice! * 100).round();
        final dropped = old != null && price < old;
        final targetHit =
            item.targetPrice != null &&
            item.targetCurrency == quote.currency &&
            price <= (item.targetPrice! * 100).round();
        final lowerThanAlert =
            currencyChanged ||
            item.lastNotifiedPrice == null ||
            price < (item.lastNotifiedPrice! * 100).round();

        final hasDiscount = quote.discount > 0 && quote.discount >= minimum;
        final isPromoOrDrop = item.targetPrice != null
            ? targetHit
            : (dropped || (hasDiscount && lowerThanAlert));

        final alert =
            notifications &&
            item.notify &&
            isPromoOrDrop &&
            lowerThanAlert;
        _items[item.id] = item.copyWith(
          title: item.title == 'Jogo salvo' ? quote.title : null,
          quote: quote,
          lowestPrice: old == null || price < old
              ? quote.currentPrice
              : item.lowestPrice,
          resetNotification: currencyChanged && !alert,
          lastNotifiedPrice: alert
              ? quote.currentPrice
              : item.lastNotifiedPrice,
        );
        if (alert) {
          _alerts.insert(0, {
            'id': '${DateTime.now().microsecondsSinceEpoch}:${item.id}',
            'deal': quote.toJson(),
            'createdAt': DateTime.now().toIso8601String(),
          });
          notify.add(quote);
        }
      }
      if (_alerts.length > 100) _alerts.removeRange(100, _alerts.length);
    });
    for (final deal in notify) {
      try {
        await onAlert?.call(deal);
      } catch (_) {
        /* Local history is already persisted. */
      }
    }
  }
}
