import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../models/gaming_device.dart';
import 'bluetooth_device_kind.dart';
import 'windows_controller_battery.dart';

bool get supported => Platform.isWindows || Platform.isLinux;

const windowsBluetoothScript = r'''
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$items = [System.Collections.Generic.List[object]]::new()
$seenMacs = [System.Collections.Generic.HashSet[string]]::new()

function Get-ModelAndMfg {
  param($vendorId, $productId, $devName, $devKind)
  $mfg = ''
  $model = ''
  if ($vendorId -eq 1118 -or $devName -match '(?i)Xbox') {
    $mfg = 'Microsoft'
    if ($productId -eq 2835) { $model = 'Xbox Wireless Controller (Model 1914 - Series X|S)' }
    elseif ($productId -eq 765) { $model = 'Xbox Wireless Controller (Model 1708 - Xbox One S)' }
    else { $model = 'Xbox Wireless Controller (Model 1914/1708)' }
  } elseif ($vendorId -eq 1356 -or $devName -match '(?i)DualSense|DualShock|PlayStation') {
    $mfg = 'Sony Interactive Entertainment'
    if ($productId -eq 3302 -or $devName -match '(?i)DualSense') { $model = 'Sony DualSense Wireless Controller (CFI-ZCT1W)' }
    elseif ($productId -eq 1476 -or $productId -eq 2508 -or $devName -match '(?i)DualShock') { $model = 'Sony DualShock 4 Wireless Controller (CUH-ZCT2)' }
    else { $model = 'PlayStation Wireless Controller' }
  } elseif ($vendorId -eq 117 -or $devName -match '(?i)Buds|Galaxy') {
    $mfg = 'Samsung Electronics'
    if ($productId -eq 40979 -or $devName -match '(?i)Buds Core') { $model = 'Samsung Galaxy Buds Core (SM-R400N)' }
    else { $model = 'Samsung Galaxy Buds Series' }
  } elseif ($vendorId -eq 1452 -or $devName -match '(?i)AirPods|Beats') {
    $mfg = 'Apple'
    $model = 'Apple AirPods Audio'
  } elseif ($vendorId -eq 11720 -or $devName -match '(?i)8BitDo') {
    $mfg = '8BitDo'
    $model = '8BitDo Wireless Gaming Controller'
  } elseif ($devName -match '(?i)Arctis') {
    $mfg = 'SteelSeries'
    $model = 'SteelSeries Arctis Gaming Headset'
  } elseif ($devName -match '(?i)WH-1000|WF-1000') {
    $mfg = 'Sony'
    $model = 'Sony 1000X Noise Cancelling Series'
  }
  return @{ Mfg = $mfg; Model = $model }
}

$devices = @(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue)

foreach ($device in $devices) {
  $name = $device.FriendlyName
  if (-not $name -or $device.InstanceId -notmatch '^(BTHENUM|BTHLE)\\DEV_') { continue }
  $kind = $null
  if ($name -match '(?i)controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir') { $kind = 'controller' }
  elseif ($name -match '(?i)headset|headphone|earbud|arctis|WH-\d|WF-\d|airpods|buds|fone|fones|jabra|bose|beats') { $kind = 'headset' }
  if (-not $kind) { continue }

  $devMac = ''
  if ($device.InstanceId -match 'DEV_([0-9A-Fa-f]{12})') {
    $devMac = $matches[1].ToLower()
    $seenMacs.Add($devMac) | Out-Null
  }

  $battery = $null
  $firmware = $null
  $manufacturer = ''
  $model = ''

  $properties = @(Get-PnpDeviceProperty -InstanceId $device.InstanceId -ErrorAction SilentlyContinue)
  if ($devMac) {
    $related = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match "DEV_$devMac" })
    foreach ($rel in $related) {
      if ($rel.InstanceId -ne $device.InstanceId) {
        $properties += @(Get-PnpDeviceProperty -InstanceId $rel.InstanceId -ErrorAction SilentlyContinue)
      }
    }
  }

  foreach ($property in $properties) {
    if (($property.KeyName -match '(?i)Battery' -or $property.KeyName -eq '{104ea319-6ee2-4701-bd47-8ddbf425bbe5} 2') -and $property.Type -match 'Byte|UInt|Int' -and $property.Data -ge 0 -and $property.Data -le 100) {
      if ($null -eq $battery -or $property.Data -gt 0) {
        $battery = [int]$property.Data
      }
    }
    if ($property.KeyName -match '(?i)Firmware' -and $property.Data -is [string]) {
      $firmware = [string]$property.Data
    }
    if ($property.KeyName -match 'DEVPKEY_Device_Manufacturer' -and -not $manufacturer) {
      $manufacturer = [string]$property.Data
    }
    if (($property.KeyName -match 'DEVPKEY_Device_Model' -or $property.KeyName -match 'DEVPKEY_Device_BusReportedDeviceDesc') -and -not $model) {
      $model = [string]$property.Data
    }
  }

  $vendorId = 0
  $productId = 0
  if ($devMac) {
    try {
      $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices\$devMac"
      if (Test-Path $regPath) {
        $regProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($regProps.BatteryPercent -is [int]) { $battery = [int]$regProps.BatteryPercent }
        elseif ($regProps.BatteryLevel -is [int]) { $battery = [int]$regProps.BatteryLevel }
        if ($regProps.VID -is [int]) { $vendorId = [int]$regProps.VID }
        if ($regProps.PID -is [int]) { $productId = [int]$regProps.PID }
      }
    } catch {}
  }

  $resolved = Get-ModelAndMfg -vendorId $vendorId -productId $productId -devName $name -devKind $kind
  if (-not $manufacturer -and $resolved.Mfg) { $manufacturer = $resolved.Mfg }
  if (-not $model -and $resolved.Model) { $model = $resolved.Model }

  $items.Add(@{
    id = $device.InstanceId
    name = $name
    kind = $kind
    manufacturer = $manufacturer
    model = $model
    battery = $battery
    firmware = $firmware
    gattReadable = $false
  })
}

$regDevices = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices" -ErrorAction SilentlyContinue
foreach ($rdev in $regDevices) {
  $mac = $rdev.PSChildName.ToLower()
  if ($seenMacs.Contains($mac)) { continue }
  $rprops = Get-ItemProperty $rdev.PSPath -ErrorAction SilentlyContinue
  $rname = ''
  if ($rprops.Name -is [byte[]]) {
    $rname = [System.Text.Encoding]::UTF8.GetString($rprops.Name).Trim([char]0)
  }
  if (-not $rname) { continue }

  $kind = $null
  if ($rname -match '(?i)controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir') { $kind = 'controller' }
  elseif ($rname -match '(?i)headset|headphone|earbud|arctis|WH-\d|WF-\d|airpods|buds|fone|fones|jabra|bose|beats') { $kind = 'headset' }
  if (-not $kind) { continue }

  $vendorId = 0
  $productId = 0
  if ($rprops.VID -is [int]) { $vendorId = [int]$rprops.VID }
  if ($rprops.PID -is [int]) { $productId = [int]$rprops.PID }
  $battery = $null
  if ($rprops.BatteryPercent -is [int]) { $battery = [int]$rprops.BatteryPercent }
  elseif ($rprops.BatteryLevel -is [int]) { $battery = [int]$rprops.BatteryLevel }

  $resolved = Get-ModelAndMfg -vendorId $vendorId -productId $productId -devName $rname -devKind $kind

  $items.Add(@{
    id = "BTHENUM\DEV_$mac"
    name = $rname
    kind = $kind
    manufacturer = $resolved.Mfg
    model = $resolved.Model
    battery = $battery
    firmware = $null
    gattReadable = $false
  })
}

ConvertTo-Json -InputObject @($items.ToArray()) -Depth 4 -Compress
''';

final _encodedWindowsBluetoothScript = base64Encode(
  windowsBluetoothScript.codeUnits.expand((c) => [c & 255, c >> 8]).toList(),
);

final _batteryRegex = RegExp(
  r'^[\t ]*Battery Percentage:[\t ]*(?:0x[0-9a-fA-F]+[\t ]*\((\d+)\)|\(0x[0-9a-fA-F]+\)[\t ]*(\d+)|(\d+))[\t \r]*$',
  multiLine: true,
);
final _mfgRegex = RegExp(r'Manufacturer: (.+)');

Future<List<GamingDevice>> scan() async {
  if (Platform.isLinux) return _linuxDevices();
  if (!supported) {
    throw UnsupportedError('Detecção disponível no Android e Windows.');
  }
  final controllers = Isolate.run(readWindowsControllerBatteries);
  try {
    final bluetooth = await _windowsBluetoothDevices();
    return [...bluetooth, ...await controllers];
  } on Object {
    final xinput = await controllers;
    if (xinput.isEmpty) rethrow;
    return xinput;
  }
}

Future<List<GamingDevice>> _windowsBluetoothDevices() async {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final process = await Process.start(
    '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      _encodedWindowsBluetoothScript,
    ],
  );
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  final exit = await process.exitCode.timeout(
    const Duration(seconds: 17),
    onTimeout: () {
      process.kill();
      throw TimeoutException('A consulta Bluetooth demorou demais.');
    },
  );
  final raw = await output;
  await errors;
  if (exit != 0) {
    throw StateError(
      'Não foi possível consultar os dispositivos Bluetooth do Windows.',
    );
  }
  return (jsonDecode(raw) as List)
      .whereType<Map>()
      .map((item) => GamingDevice.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

Future<ProcessResult> _bluez(List<String> arguments) async {
  final process = await Process.start(
    'bluetoothctl',
    arguments,
    environment: {'LC_ALL': 'C'},
    includeParentEnvironment: true,
  );
  final stdout = process.stdout.transform(utf8.decoder).join();
  final stderr = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode.timeout(
    const Duration(seconds: 4),
    onTimeout: () {
      process.kill();
      throw TimeoutException('Tempo esgotado ao executar bluetoothctl.');
    },
  );
  return ProcessResult(process.pid, code, await stdout, await stderr);
}

Future<List<GamingDevice>> _linuxDevices() async {
  final hid = _linuxHidBatteries();
  final devices = <String, GamingDevice>{};
  try {
    final res = await _bluez(const ['devices']);
    if (res.exitCode == 0) {
      final rows = RegExp(
        r'^Device ([0-9a-fA-F:]{17}) (.+)$',
        multiLine: true,
      ).allMatches(res.stdout as String);
      final bluetooth = await Future.wait(
        rows.map((row) async {
          final mac = row.group(1)!;
          final name = row.group(2)!.trim();
          var manufacturer = '';
          int? battery;
          try {
            final info = await _bluez(['info', mac]);
            if (info.exitCode == 0) {
              final output = info.stdout as String;
              final match = _batteryRegex.firstMatch(output);
              final raw = match?.group(1) ?? match?.group(2) ?? match?.group(3);
              battery = _validPercent(raw);
              manufacturer =
                  _mfgRegex.firstMatch(output)?.group(1)?.trim() ?? '';
            }
          } on Exception {
            // Ainda lista o periférico quando o nível não pôde ser consultado.
          }
          return GamingDevice(
            id: mac,
            name: name,
            kind: _linuxKind(name),
            seenAt: DateTime.now(),
            manufacturer: manufacturer,
            battery: battery,
          );
        }),
      );
      devices.addEntries(bluetooth.map((d) => MapEntry(d.id.toUpperCase(), d)));
    }
  } on Exception {
    // A bateria HID continua disponível em sistemas sem BlueZ.
  }
  for (final device in await hid) {
    final key = device.id.toUpperCase();
    final bluetooth = devices[key];
    if (bluetooth == null) {
      devices[key] = device;
    } else if (bluetooth.battery == null) {
      devices[key] = GamingDevice.fromJson({
        ...bluetooth.toJson(),
        'battery': device.battery,
      });
    }
  }
  return devices.values.toList();
}

GamingDeviceKind _linuxKind(String name) => switch (bluetoothDeviceKind(name)) {
  'controller' => GamingDeviceKind.controller,
  'headset' => GamingDeviceKind.headset,
  _ => GamingDeviceKind.other,
};

int? _validPercent(String? raw) {
  final value = int.tryParse(raw ?? '');
  return value != null && value >= 0 && value <= 100 ? value : null;
}

Future<List<GamingDevice>> _linuxHidBatteries() async {
  final devices = <GamingDevice>[];
  final supplies = Directory('/sys/class/power_supply');
  try {
    await for (final entry in supplies.list(followLinks: false)) {
      try {
        final path = entry.path;
        final properties = await File('$path/device/uevent').readAsString();
        final bus = RegExp(
          r'^HID_ID=(0003|0005):',
          multiLine: true,
        ).firstMatch(properties)?.group(1);
        final name = RegExp(
          r'^HID_NAME=(.+)$',
          multiLine: true,
        ).firstMatch(properties)?.group(1)?.trim();
        if (bus == null || name == null || name.isEmpty) continue;
        final String id;
        if (bus == '0005') {
          final address = RegExp(
            r'^HID_UNIQ=([0-9a-fA-F:]{17})$',
            multiLine: true,
          ).firstMatch(properties)?.group(1);
          if (address == null) continue;
          id = address.toUpperCase();
        } else {
          id = 'linux:hid:${entry.uri.pathSegments.last}';
        }
        final capacity = await File('$path/capacity').readAsString();
        final battery = _validPercent(capacity.trim());
        if (battery == null) continue;
        devices.add(
          GamingDevice(
            id: id,
            name: name,
            kind: _linuxKind(name),
            seenAt: DateTime.now(),
            battery: battery,
            manufacturer: bus == '0003' ? 'Linux HID' : '',
            model: bus == '0003' ? name : null,
          ),
        );
      } on FileSystemException {
        // O dispositivo pode ter sido desconectado entre a listagem e a leitura.
      }
    }
  } on FileSystemException {
    // Alguns kernels não publicam baterias de periféricos no sysfs.
  }
  return devices;
}
