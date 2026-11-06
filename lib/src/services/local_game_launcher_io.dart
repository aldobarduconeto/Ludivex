import 'dart:io';

bool get supportsLocalGames =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> launchLocalGame(String path) async {
  if (!supportsLocalGames)
    throw UnsupportedError('Use um computador para iniciar executáveis.');
  final file = File(path);
  if (!await file.exists())
    throw const FileSystemException('Executável não encontrado.');
  if (Platform.isWindows && path.toLowerCase().endsWith('.lnk')) {
    await _windowsExplorer(file.absolute.path);
    return;
  }
  await Process.start(
    file.absolute.path,
    const [],
    workingDirectory: file.absolute.parent.path,
    mode: ProcessStartMode.detached,
  );
}

Future<void> _windowsExplorer(String target) async {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  await Process.start('$root\\explorer.exe', [
    target,
  ], mode: ProcessStartMode.detached);
}

bool get supportsWindowsApps => Platform.isWindows;

Future<void> launchWindowsApp(String target) async {
  if (!Platform.isWindows) throw UnsupportedError('Este jogo requer Windows.');
  await _windowsExplorer(target);
}
