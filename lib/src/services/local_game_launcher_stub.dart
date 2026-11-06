bool get supportsLocalGames => false;
bool get supportsWindowsApps => false;

Future<void> launchWindowsApp(String target) async {
  throw UnsupportedError('Este jogo requer o aplicativo para Windows.');
}

Future<void> launchLocalGame(String path) async {
  throw UnsupportedError(
    'Executáveis locais não estão disponíveis no navegador.',
  );
}
