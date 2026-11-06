import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/library_game.dart';
import 'game_scan_result.dart';

class MobileGameLauncher {
  static const channel = MethodChannel('ludivex/mobile_games');
  static bool get supported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<GameScanResult> scan({
    String? steamFolder,
    bool includeOtherApps = false,
  }) async {
    if (!supported)
      throw UnsupportedError('A listagem de aplicativos requer Android.');
    final apps = await channel.invokeListMethod<dynamic>('listGames') ?? [];
    final games = <LibraryGame>[];
    for (final raw in apps) {
      final entry = Map<String, dynamic>.from(raw as Map);
      if (!includeOtherApps && entry['isGame'] != true) continue;
      games.add(
        LibraryGame.fromJson({
          'id': 'android:${entry['package']}',
          'title': entry['title'],
          'source': entry['isGame'] == true
              ? 'Android · Jogos'
              : 'Android · Aplicativos',
          'target': 'android-app://${entry['package']}',
          'local': false,
        }),
      );
    }
    return GameScanResult(games);
  }

  static Future<void> launch(String target) async {
    if (!supported) throw UnsupportedError('Este jogo requer Android.');
    final package = LibraryGame.androidPackage(target);
    if (package == null)
      throw const FormatException('Pacote Android inválido.');
    await channel.invokeMethod<void>('launchGame', {'package': package});
  }
}
