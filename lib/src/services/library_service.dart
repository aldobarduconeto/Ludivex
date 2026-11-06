import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_game.dart';
import 'local_game_launcher.dart';
import 'mobile_game_launcher.dart';
import 'preferences_store.dart';

class LibraryService extends ChangeNotifier {
  static final instance = LibraryService();
  static const storageKey = 'library.v1';
  SharedPreferencesAsync? _storage;
  List<LibraryGame> _items = const [];
  String? _lastWritten;
  Future<void> _queue = Future.value();
  List<LibraryGame> get items => _items;

  Future<void> load({SharedPreferencesAsync? storage}) async {
    await _queue;
    _storage = storage ?? await PreferencesStore.open();
    final loaded = <LibraryGame>[];
    final raw = await _storage!.getString(storageKey);
    if (raw != null) {
      final List entries;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return;
        entries = decoded;
      } on FormatException {
        // A damaged snapshot must not prevent the app from starting.
        return;
      }
      for (final entry in entries) {
        try {
          loaded.add(
            LibraryGame.fromJson(Map<String, dynamic>.from(entry as Map)),
          );
        } on Object {
          /* Preserve other valid entries. */
        }
      }
    }
    _items = List.unmodifiable(loaded..sort(_compare));
    _lastWritten = raw;
    notifyListeners();
  }

  Future<void> _mutate(List<LibraryGame> Function() update) {
    final operation = _queue.then((_) async {
      final next = update()..sort(_compare);
      final encoded = jsonEncode(next.map((g) => g.toJson()).toList());
      if (encoded == _lastWritten) return;
      final storage = _storage ??= await PreferencesStore.open();
      await PreferencesStore.write(
        () => storage.setString(storageKey, encoded),
      );
      _lastWritten = encoded;
      _items = List.unmodifiable(next);
      notifyListeners();
    });
    _queue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return _queue.then((_) => operation);
  }

  static int _compare(LibraryGame a, LibraryGame b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  Future<void> save(LibraryGame game) {
    LibraryGame.fromJson(game.toJson());
    return _mutate(() => [..._items.where((g) => g.id != game.id), game]);
  }

  Future<void> remove(String id) =>
      _mutate(() => _items.where((g) => g.id != id).toList());

  Future<void> importGames(Iterable<LibraryGame> games) {
    final incoming = games.toList();
    for (final game in incoming) {
      LibraryGame.fromJson(game.toJson());
    }
    return _mutate(() {
      final next = [..._items];
      final ids = next.map((g) => g.id).toSet();
      final targets = next.map((g) => g.target).toSet();
      for (final game in incoming) {
        if (!ids.contains(game.id) && !targets.contains(game.target)) {
          next.add(game);
          ids.add(game.id);
          targets.add(game.target);
        }
      }
      return next;
    });
  }

  Future<void> launch(LibraryGame game) async {
    if (LibraryGame.validateTarget(game.target, local: game.local) != null) {
      throw const FormatException('Destino inválido.');
    }
    if (LibraryGame.androidPackage(game.target) != null) {
      await MobileGameLauncher.launch(game.target);
    } else if (game.local) {
      await launchLocalGame(game.target);
    } else if (LibraryGame.isWindowsAppTarget(game.target)) {
      await launchWindowsApp(game.target);
    } else if (!await launchUrl(
      Uri.parse(game.target),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('Launcher indisponível.');
    }
  }
}
