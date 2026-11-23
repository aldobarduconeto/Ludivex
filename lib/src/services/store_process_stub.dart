import 'dart:io';

const supportsStoreAccounts = false;
const supportsCompatibility = false;

Future<Process> startStoreProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
  bool detached = false,
}) async => throw UnsupportedError('Requer um computador.');

Future<bool> storeFileExists(String path) async => false;
Future<String> storeDataDirectory(String name) async =>
    throw UnsupportedError('Requer um computador.');
Future<String?> readStoreFile(String path) async => null;
Future<void> writeStoreFile(String path, String content) async {}
Future<void> deleteStoreFile(String path) async {}
Future<List<String>> storeSubdirectories(String path) async => [];
const gogPlatform = 'windows';
