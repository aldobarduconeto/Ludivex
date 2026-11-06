import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// All persistent app state uses the uncached asynchronous preferences API.
abstract final class PreferencesStore {
  static Future<void> _writes = Future.value();
  static Future<SharedPreferencesAsync>? _opening;

  /// Also serializes writes between different services sharing the same backend.
  static Future<T> write<T>(Future<T> Function() operation) {
    final task = _writes.then((_) => operation());
    _writes = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    // Await the recovered tail too, so the next caller never depends on a
    // detached completion callback.
    return _writes.then((_) => task);
  }

  static const migrationKey = 'gamehub.async.migrated.v1';
  static const keys = <String>{
    'settings.v3',
    'settings.v2',
    'platforms',
    'minimumDiscount',
    'notificationsEnabled',
    'wishlist.v3',
    'savedDeals',
    'wishlist',
    'library.v1',
    'devices.v1',
    'api.catalog.v1',
    'api.catalog.v2',
    'app.firstLaunchPermissionsDone',
    'deals.seen_ids.v1',
  };

  static Future<SharedPreferencesAsync> open() => _opening ??= _initialize();

  static Future<SharedPreferencesAsync> _initialize() async {
    try {
      return await _createAndMigrate();
    } catch (_) {
      // A transient platform failure must not poison storage for this session.
      _opening = null;
      rethrow;
    }
  }

  static Future<SharedPreferencesAsync> _createAndMigrate() async {
    final storage = SharedPreferencesAsync();
    final legacy = defaultTargetPlatform == TargetPlatform.android
        ? SharedPreferencesAsync(
            options: const SharedPreferencesAsyncAndroidOptions(
              backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
              originalSharedPreferencesOptions:
                  AndroidSharedPreferencesStoreOptions(
                    fileName: 'FlutterSharedPreferences',
                  ),
            ),
          )
        : storage;
    await migrate(storage, legacy);
    return storage;
  }

  /// Reads the old backend through Async too. Copies only app-owned keys and
  /// leaves originals intact. A failed copy is retried on the next launch;
  /// values already written by the new app always win.
  static Future<void> migrate(
    SharedPreferencesAsync storage,
    SharedPreferencesAsync legacy,
  ) => write(() async {
    if (await storage.getBool(migrationKey) == true) return;
    final existing = await storage.getKeys(allowList: keys);
    final old = await legacy.getAll(
      allowList: keys.map((k) => 'flutter.$k').toSet(),
    );
    for (final key in keys.difference(existing)) {
      final value = old['flutter.$key'];
      if (value == null) continue;
      if (key == 'platforms' || key == 'wishlist') {
        final list = await legacy.getStringList('flutter.$key');
        if (list != null) await storage.setStringList(key, list);
      } else if (value is String) {
        await storage.setString(key, value);
      } else if (value is bool) {
        await storage.setBool(key, value);
      } else if (value is int) {
        await storage.setInt(key, value);
      } else if (value is double) {
        await storage.setDouble(key, value);
      }
    }
    await storage.setBool(migrationKey, true);
  });
}
