import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/game_deal.dart';
import '../../models/store_region.dart';
import '../../services/preferences_store.dart';

enum DealSort { discount, lowestPrice, title }

enum AppThemePreference {
  system,
  light,
  dark,
  oled;

  String get label => switch (this) {
    AppThemePreference.system => 'Acompanhar o sistema',
    AppThemePreference.light => 'Claro',
    AppThemePreference.dark => 'Escuro',
    AppThemePreference.oled => 'Escuro OLED (Preto Puro)',
  };

  String get description => switch (this) {
    AppThemePreference.system =>
      'Segue automaticamente o modo do sistema operacional.',
    AppThemePreference.light =>
      'Tema claro com visual limpo e excelente legibilidade.',
    AppThemePreference.dark =>
      'Tons grafite confortáveis para os olhos.',
    AppThemePreference.oled =>
      'Preto absoluto (#000000) otimizado para economia de energia em telas OLED.',
  };

  IconData get icon => switch (this) {
    AppThemePreference.system => Icons.brightness_auto_rounded,
    AppThemePreference.light => Icons.light_mode_rounded,
    AppThemePreference.dark => Icons.dark_mode_rounded,
    AppThemePreference.oled => Icons.contrast_rounded,
  };
}

class AppPreferences extends ChangeNotifier {
  AppPreferences();
  static final instance = AppPreferences();
  late SharedPreferencesAsync _storage;
  Future<void> _writes = Future.value();
  String? _lastWritten;
  int _saveVersion = 0;
  StoreRegion region = StoreRegion.brazil;
  Set<GamePlatform> platforms = GamePlatform.values.toSet();
  int minimumDiscount = 10, alertMinimumDiscount = 0, refreshMinutes = 5;
  bool notificationsEnabled = true,
      notificationSound = true,
      notifyNewPromotions = true,
      freeOnly = false,
      compactCards = false,
      autoRefresh = true,
      permissionsRequested = false,
      oledWhenDark = false,
      bluetoothAutoScan = true,
      libraryAutoScan = true;
  AppThemePreference themePreference = AppThemePreference.dark;

  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark || AppThemePreference.oled => ThemeMode.dark,
  };

  set themeMode(ThemeMode mode) {
    themePreference = switch (mode) {
      ThemeMode.system => AppThemePreference.system,
      ThemeMode.light => AppThemePreference.light,
      ThemeMode.dark =>
        themePreference == AppThemePreference.oled
            ? AppThemePreference.oled
            : AppThemePreference.dark,
    };
  }

  bool get isOled => themePreference == AppThemePreference.oled;

  DealSort sort = DealSort.discount;
  Map<GamePlatform, String> apiUrls = {};
  List<String> xboxProductIds = [];
  int individualOfferCount = 24;
  GamePlatform preferredPlatform = GamePlatform.steam;
  List<GamePlatform> get orderedPlatforms => [
    if (platforms.contains(preferredPlatform)) preferredPlatform,
    ...GamePlatform.values.where(
      (p) => platforms.contains(p) && p != preferredPlatform,
    ),
  ];

  String get sourceSignature => jsonEncode({
    'region': region.country,
    'stores': (platforms.map((p) => p.key).toList()..sort()),
    'urls': {for (final p in GamePlatform.values) p.key: apiUrls[p] ?? ''},
    'xbox': (List<String>.of(xboxProductIds)..sort()),
  });

  Future<void> load({SharedPreferencesAsync? storage}) async {
    await _writes;
    _storage = storage ?? await PreferencesStore.open();
    final saved = await _storage.getAll(
      allowList: {
        'settings.v3',
        'settings.v2',
        'platforms',
        'minimumDiscount',
        'notificationsEnabled',
        'app.firstLaunchPermissionsDone',
      },
    );
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(
        saved['settings.v3'] as String? ??
            saved['settings.v2'] as String? ??
            '{}',
      ) as Map<String, dynamic>;
    } catch (_) {
      /* Recover with defaults. */
    }
    _apply(data, saved);
    permissionsRequested =
        saved['app.firstLaunchPermissionsDone'] as bool? ?? false;
    _lastWritten = saved['settings.v3'] as String?;
    await save();
    if (saved.containsKey('settings.v2'))
      await PreferencesStore.write(() => _storage.remove('settings.v2'));
  }

  Future<void> markPermissionsRequested() async {
    permissionsRequested = true;
    await PreferencesStore.write(
      () => _storage.setBool('app.firstLaunchPermissionsDone', true),
    );
    notifyListeners();
  }

  void _apply(
    Map<String, dynamic> data, [
    Map<String, Object?> saved = const {},
  ]) {
    region = StoreRegion.parse(
      data['region'] is String ? data['region'] as String : null,
    );
    final stores = data['platforms'] is List
        ? data['platforms'] as List
        : saved['platforms'] is List
        ? saved['platforms'] as List
        : null;
    platforms = stores == null
        ? GamePlatform.values.toSet()
        : GamePlatform.values
              .where((p) => stores.contains(p.name) || stores.contains(p.key))
              .toSet();
    int integer(String key, int fallback) =>
        data[key] is int ? (data[key] as int).clamp(0, 100) : fallback;
    minimumDiscount = integer(
      'minimumDiscount',
      (saved['minimumDiscount'] as int? ?? 10).clamp(0, 100),
    );
    alertMinimumDiscount = integer('alertMinimumDiscount', 0);
    bool flag(String key, bool fallback) =>
        data[key] is bool ? data[key] as bool : fallback;
    notificationsEnabled = flag(
      'notificationsEnabled',
      saved['notificationsEnabled'] as bool? ?? true,
    );
    notificationSound = flag('notificationSound', true);
    notifyNewPromotions = flag('notifyNewPromotions', true);
    freeOnly = flag('freeOnly', false);
    compactCards = flag('compactCards', false);
    autoRefresh = flag('autoRefresh', true);
    oledWhenDark = flag('oledWhenDark', false);
    bluetoothAutoScan = flag('bluetoothAutoScan', true);
    libraryAutoScan = flag('libraryAutoScan', true);
    refreshMinutes = [1, 5, 15, 30].contains(data['refreshMinutes'])
        ? data['refreshMinutes'] as int
        : 5;

    final prefName = data['themePreference'];
    if (prefName is String) {
      themePreference =
          AppThemePreference.values
              .where((m) => m.name == prefName)
              .firstOrNull ??
          AppThemePreference.dark;
    } else {
      final legacyTheme = data['theme'];
      themePreference = switch (legacyTheme) {
        'light' => AppThemePreference.light,
        'system' => AppThemePreference.system,
        'oled' => AppThemePreference.oled,
        _ => AppThemePreference.dark,
      };
    }

    sort =
        DealSort.values.where((s) => s.name == data['sort']).firstOrNull ??
        DealSort.discount;
    individualOfferCount =
        [0, 12, 24, 48, 96].contains(data['individualOfferCount'])
        ? data['individualOfferCount'] as int
        : 24;
    preferredPlatform =
        GamePlatform.values
            .where((p) => p.key == data['preferredPlatform'])
            .firstOrNull ??
        GamePlatform.steam;
    final urls = data['apiUrls'];
    apiUrls = {
      if (urls is Map)
        for (final p in GamePlatform.values)
          if (urls[p.key] is String) p: urls[p.key] as String,
    };
    xboxProductIds =
        (data['xboxProductIds'] is List
                ? data['xboxProductIds'] as List
                : const [])
            .whereType<String>()
            .toList();
  }

  Future<void> save() {
    final version = ++_saveVersion;
    final encoded = jsonEncode({
      'region': region.country,
      'platforms': platforms.map((p) => p.name).toList(),
      'minimumDiscount': minimumDiscount,
      'alertMinimumDiscount': alertMinimumDiscount,
      'notificationsEnabled': notificationsEnabled,
      'notificationSound': notificationSound,
      'notifyNewPromotions': notifyNewPromotions,
      'freeOnly': freeOnly,
      'compactCards': compactCards,
      'autoRefresh': autoRefresh,
      'refreshMinutes': refreshMinutes,
      'theme': themeMode.name,
      'themePreference': themePreference.name,
      'oledWhenDark': oledWhenDark,
      'bluetoothAutoScan': bluetoothAutoScan,
      'libraryAutoScan': libraryAutoScan,
      'sort': sort.name,
      'individualOfferCount': individualOfferCount,
      'preferredPlatform': preferredPlatform.key,
      'apiUrls': {
        for (final entry in apiUrls.entries) entry.key.key: entry.value,
      },
      'xboxProductIds': xboxProductIds,
    });
    final operation = _writes.then((_) async {
      if (encoded == _lastWritten) return;
      try {
        await PreferencesStore.write(
          () => _storage.setString('settings.v3', encoded),
        );
      } catch (_) {
        if (version == _saveVersion && _lastWritten != null) {
          _apply(jsonDecode(_lastWritten!) as Map<String, dynamic>);
          notifyListeners();
        }
        rethrow;
      }
      _lastWritten = encoded;
      notifyListeners();
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return _writes.then((_) => operation);
  }
}
