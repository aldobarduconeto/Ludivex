import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/library_game.dart';
import 'game_scan_result.dart';

// Read-only discovery, invoked only after the library screen obtains consent.
// Existing shortcuts preserve launcher arguments instead of guessing game IDs.
const windowsGameScanScript = r'''
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$games = [System.Collections.Generic.List[object]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$shell = New-Object -ComObject WScript.Shell
$folders = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'), [Environment]::GetFolderPath('StartMenu'), [Environment]::GetFolderPath('CommonStartMenu')) | Where-Object { $_ } | Select-Object -Unique
foreach ($folder in $folders) {
  try {
    $shortcuts = Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction Stop | Where-Object { $_.Extension -in '.lnk', '.url' }
    foreach ($file in $shortcuts) {
      try {
        $destination = ''
        $arguments = ''
        if ($file.Extension -eq '.url') {
          $line = Get-Content -LiteralPath $file.FullName | Where-Object { $_ -match '^URL=' } | Select-Object -First 1
          if ($line) { $destination = $line.Substring(4).Trim() }
        } else {
          $link = $shell.CreateShortcut($file.FullName)
          $destination = $link.TargetPath
          $arguments = $link.Arguments
        }
        $signature = "$destination $arguments"
        $source = $null
        if ($signature -match '(?i)(?:origin2?://|link2ea://|eadm://|[\\/]EA Games[\\/]|[\\/]Origin Games[\\/])') { $source = 'EA' }
        elseif ($signature -match '(?i)(?:uplay://|ubisoftconnect://|[\\/]Ubisoft[\\/].*[\\/]games[\\/])') { $source = 'Ubisoft Connect' }
        elseif ($signature -match '(?i)[\\/]XboxGames[\\/]') { $source = 'Xbox Store' }
        if (-not $source -or $file.BaseName -match '(?i)^(EA app|EA Desktop|Origin|Ubisoft Connect|Uplay|Xbox)$|uninstall|desinstalar|crash|support|repair') { continue }
        if ($file.Extension -eq '.lnk' -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) { continue }
        $target = if ($file.Extension -eq '.lnk') { $file.FullName } else { $destination }
        $games.Add(@{ title = $file.BaseName; source = $source; target = $target; local = ($file.Extension -eq '.lnk') })
      } catch { $warnings.Add('Não foi possível ler um dos atalhos de jogos do Windows.') }
    }
  } catch { $warnings.Add('Sem acesso a uma das pastas de atalhos do Windows.') }
}
try {
  $startApps = @(Get-StartApps)
  foreach ($package in Get-AppxPackage) {
    try {
      if (-not $package.InstallLocation -or $package.IsFramework -or $package.IsResourcePackage) { continue }
      if ($package.Name -match '^Microsoft\.(Xbox|GamingApp$|GamingServices$|WindowsStore$)') { continue }
      $manifest = Get-AppxPackageManifest -Package $package.PackageFullName
      $isGame = (Test-Path -LiteralPath (Join-Path $package.InstallLocation 'MicrosoftGame.config')) -or ($manifest.OuterXml -match '(?i)XboxLive|MicrosoftGame\.config')
      if (-not $isGame) { continue }
      foreach ($app in $startApps) {
        if ($app.AppID.StartsWith($package.PackageFamilyName + '!')) {
          $games.Add(@{ title = $app.Name; source = 'Xbox Store'; target = ('shell:AppsFolder\' + $app.AppID); local = $false })
        }
      }
    } catch { $warnings.Add('Não foi possível consultar um dos jogos registrados no Windows.') }
  }
} catch { $warnings.Add('Não foi possível consultar os jogos da Xbox Store registrados no Windows.') }
@{ games = @($games.ToArray()); warnings = @($warnings.ToArray() | Select-Object -Unique) } | ConvertTo-Json -Depth 4 -Compress
''';

GameScanResult parseWindowsGameScan(String output) {
  final data = jsonDecode(output.trim()) as Map<String, dynamic>;
  final games = <String, LibraryGame>{};
  final warnings = (data['warnings'] as List? ?? [])
      .whereType<String>()
      .toSet();
  for (final raw in data['games'] as List? ?? []) {
    try {
      final entry = Map<String, dynamic>.from(raw as Map);
      final target = entry['target'] as String;
      final source = entry['source'] as String;
      if (!['EA', 'Ubisoft Connect', 'Xbox Store'].contains(source)) continue;
      final game = LibraryGame.fromJson({
        ...entry,
        'id': 'scan:windows:${Uri.encodeComponent(target.toLowerCase())}',
      });
      final key = '${game.source}:${game.title.toLowerCase()}';
      // Prefer registered app activation over an equivalent desktop shortcut.
      if (!games.containsKey(key) || !game.local) games[key] = game;
    } on Object {
      warnings.add('Um registro inválido de jogo do Windows foi ignorado.');
    }
  }
  return GameScanResult(games.values.toList(), warnings: warnings.toList());
}

Future<GameScanResult> scanWindowsGames() async {
  if (!Platform.isWindows) return const GameScanResult([]);
  final encoded = base64Encode(
    windowsGameScanScript.codeUnits.expand((c) => [c & 255, c >> 8]).toList(),
  );
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final process = await Process.start(
    '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
  );
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 45),
    onTimeout: () {
      process.kill();
      throw TimeoutException('A busca do Windows demorou demais.');
    },
  );
  final text = await output;
  await errors;
  if (code != 0)
    throw const ProcessException(
      'powershell',
      [],
      'Falha ao consultar jogos instalados.',
    );
  return parseWindowsGameScan(text);
}
