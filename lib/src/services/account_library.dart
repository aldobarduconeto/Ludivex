import 'package:flutter/foundation.dart';

import 'desktop_store.dart';

typedef AccountGame = ({StoreProvider store, StoreGame game});

class AccountLibrary extends ChangeNotifier {
  AccountLibrary._();
  static final instance = AccountLibrary._();

  final _games = <StoreProvider, List<StoreGame>>{};
  final _revisions = <StoreProvider, int>{};
  bool _loading = false;

  bool get loading => _loading;
  Iterable<AccountGame> get games sync* {
    for (final entry in _games.entries) {
      for (final game in entry.value) {
        yield (store: entry.key, game: game);
      }
    }
  }

  void replace(StoreProvider provider, List<StoreGame> games) {
    _revisions[provider] = (_revisions[provider] ?? 0) + 1;
    _games[provider] = List.unmodifiable(games);
    notifyListeners();
  }

  Future<List<StoreProvider>> refresh() async {
    if (_loading || !supportsStoreAccounts) return [];
    _loading = true;
    notifyListeners();
    try {
      final settings = await LauncherSettings.load();
      final results = await Future.wait(
        StoreProvider.values.map((provider) async {
          final revision = _revisions[provider] ?? 0;
          try {
            final games = await provider
                .open(settings)
                .games()
                .timeout(const Duration(seconds: 60));
            if ((_revisions[provider] ?? 0) == revision) {
              replace(provider, games);
            }
            return null;
          } catch (_) {
            return provider;
          }
        }),
      );
      return results.whereType<StoreProvider>().toList();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
