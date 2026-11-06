import 'game_scan_result.dart';

bool get supportsGameScan => false;

Future<GameScanResult> scanInstalledGames({String? steamFolder}) async =>
    throw UnsupportedError(
      'A busca de jogos requer o aplicativo para computador.',
    );
