import '../models/library_game.dart';

class GameScanResult {
  const GameScanResult(this.games, {this.warnings = const []});
  final List<LibraryGame> games;
  final List<String> warnings;
}
