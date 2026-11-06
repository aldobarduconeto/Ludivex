enum XboxCompatibility {
  unknown('Compatibilidade não informada'),
  console('Console Xbox'),
  playAnywhere('Xbox Play Anywhere'),
  windows('Somente Windows'),
  consoleAndWindows('Xbox e Windows · XPA não confirmado');

  const XboxCompatibility(this.label);
  final String label;

  static XboxCompatibility parse(Object? value) =>
      values.firstWhere((item) => item.name == value, orElse: () => unknown);

  /// Only structured platform metadata and an explicit XPA flag are evidence.
  /// Supporting Xbox and PC alone does not establish a cross-buy entitlement.
  static XboxCompatibility fromStore(Map data) {
    if (data['xboxCompatibility'] != null)
      return parse(data['xboxCompatibility']);
    final platforms = <String>{};
    var xpa = false;
    void collectPlatforms(Object? value) {
      if (value is String)
        platforms.add(value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));
      if (value is List) value.forEach(collectPlatforms);
      if (value is Map) {
        for (final key in [
          'name',
          'Name',
          'id',
          'Id',
          'PlatformName',
          'platformName',
        ]) {
          collectPlatforms(value[key]);
        }
      }
    }

    void visit(Object? value) {
      if (value is List) value.forEach(visit);
      if (value is! Map) return;
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if ([
              'xboxconsolegencompatible',
              'xboxconsolegenoptimized',
            ].contains(key) &&
            entry.value is List &&
            (entry.value as List).isNotEmpty)
          platforms.add('xbox');
        if ([
              'xboxxpa',
              'isxboxplayanywhere',
              'isplayanywhere',
              'xboxplayanywhere',
            ].contains(key) &&
            (entry.value == true ||
                entry.value.toString().toLowerCase() == 'true'))
          xpa = true;
        if ([
          'supportedplatforms',
          'platforms',
          'allowedplatforms',
          'availableon',
          'availableonplatforms',
          'platformname',
          'devicefamily',
          'devicename',
        ].contains(key))
          collectPlatforms(entry.value);
        if (['capabilities', 'attributes'].contains(key) &&
            entry.value is List) {
          for (final cap in entry.value as List) {
            final id = cap is Map
                ? cap['id'] ?? cap['Id'] ?? cap['name'] ?? cap['Name']
                : cap;
            if (id is String &&
                ['xpa', 'xboxplayanywhere', 'xboxxpa'].contains(
                  id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''),
                ))
              xpa = true;
          }
        }
        visit(entry.value);
      }
    }

    visit(data);
    if (xpa) return playAnywhere;
    final xbox = platforms.any(
      (p) => [
        'xbox',
        'xboxone',
        'xbox360',
        'xboxseriesxs',
        'xboxseriesx',
        'xboxseriess',
        'xboxscarlett',
        'xboxseries',
        'windowsxbox',
      ].contains(p),
    );
    final pc = platforms.any(
      (p) => [
        'pc',
        'windows',
        'windows10',
        'windows11',
        'windowsdesktop',
        'windowspc',
      ].contains(p),
    );
    if (xbox && pc) return consoleAndWindows;
    if (xbox) return console;
    if (pc) return windows;
    return unknown;
  }
}
