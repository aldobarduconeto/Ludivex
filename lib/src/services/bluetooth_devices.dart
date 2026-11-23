import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/gaming_device.dart';
import 'bluetooth_devices_stub.dart'
    if (dart.library.io) 'bluetooth_devices_io.dart'
    as desktop;

abstract final class BluetoothDevices {
  static const channel = MethodChannel('ludivex/devices');
  static bool get android => defaultTargetPlatform == TargetPlatform.android;
  static bool get apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  static bool get linux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  static bool canReadDetails(GamingDevice device) =>
      (android || apple) && device.gattReadable;
  static Future<bool> hasAndroidPermission() async {
    if (!android || kIsWeb) return false;
    try {
      return await channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static bool get supported => android || apple || desktop.supported;
  static bool get windows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static String get listingDescription {
    if (windows)
      return 'Consulta dispositivos Bluetooth e controles e fones compatíveis com XInput. A bateria é atualizada a cada minuto enquanto esta tela está aberta.';
    if (defaultTargetPlatform == TargetPlatform.iOS)
      return 'Lista dispositivos Bluetooth LE próximos e a saída de áudio Bluetooth em uso. Use Ler dados Bluetooth para consultar a bateria de um periférico BLE compatível.';
    if (defaultTargetPlatform == TargetPlatform.macOS)
      return 'Lista aparelhos pareados e periféricos Bluetooth LE próximos. Use Ler dados Bluetooth para consultar a bateria de um periférico BLE compatível.';
    if (linux)
      return 'Consulta a bateria Bluetooth pelo BlueZ e a de periféricos USB compatíveis pelo Linux.';
    return 'Consulta os dispositivos Bluetooth conhecidos pelo sistema. Bateria e firmware aparecem apenas quando disponíveis; a listagem não indica que o aparelho está conectado.';
  }

  static Future<bool> requestPermission() async {
    if (android) {
      try {
        return await channel.invokeMethod<bool>('requestPermission') ?? false;
      } catch (_) {
        return false;
      }
    }
    if (apple) {
      try {
        await channel.invokeListMethod<dynamic>('scan');
        return true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  static Future<List<GamingDevice>> scan() async {
    if (!android && !apple) return desktop.scan();
    final rows = await channel.invokeListMethod<dynamic>('scan') ?? [];
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final ble = await channel.invokeListMethod<dynamic>('scanBle') ?? [];
        return _decodeDevices([...rows, ...ble]);
      } on PlatformException {
        // A consulta de pareados continua disponível se o Bluetooth LE falhar.
      }
    }
    return _decodeDevices(rows);
  }

  static List<GamingDevice> _decodeDevices(List<dynamic> rows) {
    return rows
        .map(
          (row) => GamingDevice.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  static Future<GamingDevice> readDetails(GamingDevice device) async {
    if (!canReadDetails(device)) return device;
    final data = await channel.invokeMapMethod<String, dynamic>('readDetails', {
      'id': device.id,
    });
    if (data == null || data.isEmpty)
      throw StateError('O dispositivo não publicou os dados Bluetooth padrão.');
    return GamingDevice.fromJson({
      ...device.toJson(),
      ...data,
      'seenAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
