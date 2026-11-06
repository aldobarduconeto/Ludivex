import 'package:flutter/material.dart';
import 'game_deal.dart';
export 'game_deal.dart' show GamePlatform;

extension PlatformDetails on GamePlatform {
  bool get requiresCatalogApi => false;
  String get label => switch (this) {
    GamePlatform.playstation => 'PlayStation Store',
    GamePlatform.xbox => 'Xbox Store',
    GamePlatform.steam => 'Steam',
    GamePlatform.epic => 'Epic Games Store',
    GamePlatform.nuuvem => 'Nuuvem',
    GamePlatform.ubisoft => 'Ubisoft Store',
    GamePlatform.ea => 'EA Store',
    GamePlatform.nintendo => 'Nintendo eShop',
  };
  String get shortLabel => switch (this) {
    GamePlatform.playstation => 'PSN',
    GamePlatform.xbox => 'Xbox',
    GamePlatform.steam => 'Steam',
    GamePlatform.epic => 'Epic',
    GamePlatform.nuuvem => 'Nuuvem',
    GamePlatform.ubisoft => 'Ubisoft',
    GamePlatform.ea => 'EA',
    GamePlatform.nintendo => 'Nintendo',
  };
  IconData get icon => switch (this) {
    GamePlatform.playstation => Icons.sports_esports,
    GamePlatform.xbox => Icons.gamepad,
    GamePlatform.steam => Icons.desktop_windows,
    GamePlatform.epic => Icons.bolt_rounded,
    GamePlatform.nuuvem => Icons.cloud_outlined,
    GamePlatform.ubisoft => Icons.blur_circular,
    GamePlatform.ea => Icons.sports_esports_outlined,
    GamePlatform.nintendo => Icons.videogame_asset_outlined,
  };
  Color get tint => switch (this) {
    GamePlatform.playstation => const Color(0xFF3988FF),
    GamePlatform.xbox => const Color(0xFF45C96B),
    GamePlatform.steam => const Color(0xFF8FA7FF),
    GamePlatform.epic => const Color(0xFFF5B85A),
    GamePlatform.nuuvem => const Color(0xFF36B9E8),
    GamePlatform.ubisoft => const Color(0xFFAD94FF),
    GamePlatform.ea => const Color(0xFFFF6969),
    GamePlatform.nintendo => const Color(0xFFFF525A),
  };
}
