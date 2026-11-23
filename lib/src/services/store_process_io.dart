import 'dart:io';

import 'package:flutter/foundation.dart';

bool get supportsStoreAccounts =>
    !kIsWeb &&
    const [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);

bool get supportsCompatibility =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

Future<Process> startStoreProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
  bool detached = false,
}) => Process.start(
  executable,
  arguments,
  environment: environment,
  workingDirectory: workingDirectory,
  mode: detached ? ProcessStartMode.detached : ProcessStartMode.normal,
);

Future<bool> storeFileExists(String path) => File(path).exists();
Future<String> storeDataDirectory(String name) async {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'];
  final base = Platform.isWindows
      ? env['LOCALAPPDATA']
      : Platform.isMacOS
      ? (home == null ? null : '$home/Library/Application Support')
      : env['XDG_DATA_HOME'] ?? (home == null ? null : '$home/.local/share');
  if (base == null) throw StateError('Pasta de dados indisponível.');
  return (await Directory('$base/Ludivex/$name').create(recursive: true)).path;
}

Future<String?> readStoreFile(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsString() : null;
}

Future<void> deleteStoreFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<void> writeStoreFile(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

Future<List<String>> storeSubdirectories(String path) async {
  final directory = Directory(path);
  if (!await directory.exists()) return [];
  return [
    await for (final entry in directory.list(followLinks: false))
      if (entry is Directory) entry.path,
  ];
}

String get gogPlatform => Platform.isMacOS ? 'osx' : 'windows';
