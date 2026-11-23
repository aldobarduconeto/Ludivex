class LibraryGame {
  const LibraryGame({
    required this.id,
    required this.title,
    required this.source,
    required this.target,
    this.local = false,
    this.favorite = false,
    this.lastLaunchedAt,
  });

  final String id, title, source, target;
  final bool local;
  static ({String store, String id})? storeTarget(String target) {
    final match = RegExp(
      r'^ludivex-(epic|gog|amazon|ea)://([A-Za-z0-9_][A-Za-z0-9_.-]*)$',
    ).firstMatch(target);
    if (match == null) return null;
    return (store: match[1]!, id: match[2]!);
  }

  final bool favorite;
  final DateTime? lastLaunchedAt;

  LibraryGame withLauncherActivity({
    bool? favorite,
    DateTime? lastLaunchedAt,
  }) => LibraryGame(
    id: id,
    title: title,
    source: source,
    target: target,
    local: local,
    favorite: favorite ?? this.favorite,
    lastLaunchedAt: lastLaunchedAt ?? this.lastLaunchedAt,
  );

  static String? androidPackage(String target) {
    final match = RegExp(
      r'^android-app://([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+)$',
    ).firstMatch(target);
    return match?[1];
  }

  static bool isWindowsAppTarget(String target) =>
      RegExp(r'^shell:AppsFolder\\[a-zA-Z0-9._-]+![a-zA-Z0-9._-]+$')
          .hasMatch(target);

  bool get requiresComputer => local || isWindowsAppTarget(target);

  static String? validateTarget(String value, {required bool local}) {
    if (value.trim().isEmpty) return 'Informe como iniciar o jogo.';
    if (value.trim().toLowerCase().startsWith('ludivex-')) {
      return !local && storeTarget(value.trim()) != null
          ? null
          : 'Informe um identificador de loja válido.';
    }
    if (value.trim().startsWith('android-app:')) {
      return !local && androidPackage(value.trim()) != null
          ? null
          : 'Informe um pacote Android válido.';
    }
    if (local) {
      if (!RegExp(r'^(?:[a-zA-Z]:[\\/]|/)').hasMatch(value.trim())) {
        return 'Informe o caminho absoluto do executável.';
      }
      return null;
    }
    if (isWindowsAppTarget(value.trim())) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*$').hasMatch(uri.scheme) ||
        [
          'file',
          'javascript',
          'data',
          'vbscript',
          'shell',
          'powershell',
          'cmd',
        ].contains(uri.scheme.toLowerCase()) ||
        value.contains(RegExp(r'[\r\n]')) ||
        value.trim().substring(value.trim().indexOf(':') + 1).isEmpty) {
      return 'Informe um link válido de inicialização do launcher.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source': source,
    'target': target,
    'local': local,
    if (favorite) 'favorite': true,
    if (lastLaunchedAt != null)
      'lastLaunchedAt': lastLaunchedAt!.toUtc().toIso8601String(),
  };

  factory LibraryGame.fromJson(Map<String, dynamic> json) {
    final game = LibraryGame(
      id: json['id'] as String,
      title: json['title'] as String,
      source: json['source'] as String,
      target: json['target'] as String,
      local: json['local'] as bool? ?? false,
      favorite: json['favorite'] == true,
      lastLaunchedAt: DateTime.tryParse(
        json['lastLaunchedAt']?.toString() ?? '',
      ),
    );
    if (game.id.isEmpty ||
        game.title.trim().isEmpty ||
        game.source.trim().isEmpty ||
        validateTarget(game.target, local: game.local) != null) {
      throw const FormatException('Jogo inválido');
    }
    return game;
  }
}
