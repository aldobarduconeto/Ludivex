import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/gaming_device.dart';
import 'bluetooth_devices_stub.dart'
    if (dart.library.io) 'bluetooth_devices_io.dart'
    as desktop;

abstract final class BluetoothDevices {
  static const channel = MethodChannel('ludivex/devices');
  static bool get android =>
      defaultTargetPlatform == TargetPlatform.android;
  static bool get apple => defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;
  static bool get supported => android || apple || desktop.supported;
  static String get listingDescription {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'Lista dispositivos BLE próximos e acessíveis ao iOS e a saída de áudio Bluetooth em uso. O iOS não expõe a lista completa de aparelhos pareados.';
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
    return rows
        .map(
          (row) => GamingDevice.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  static Future<GamingDevice> readDetails(GamingDevice device) async {
    if (!android || !device.gattReadable) return device;
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
