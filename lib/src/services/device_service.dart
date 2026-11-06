import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gaming_device.dart';
import 'bluetooth_devices.dart';
import 'preferences_store.dart';

/// Serviço otimizado para gestão, descoberta e monitoramento de controles e fones Bluetooth.
class DeviceService extends ChangeNotifier {
  DeviceService({
    Future<List<GamingDevice>> Function()? scan,
    Future<GamingDevice> Function(GamingDevice)? read,
  }) : _scan = scan ?? BluetoothDevices.scan,
       _read = read ?? BluetoothDevices.readDetails;

  static final instance = DeviceService();

  final Future<List<GamingDevice>> Function() _scan;
  final Future<GamingDevice> Function(GamingDevice) _read;

  SharedPreferencesAsync? _storage;
  String? _lastWritten;
  Future<void> _writes = Future.value();
  Future<void> _reads = Future.value();
  Future<void>? _refreshing;

  List<GamingDevice> _devices = const [];
  final Set<String> found = <String>{};
  bool scanning = false;
  String? error;

  List<GamingDevice> get devices => _devices;

  Future<void> load({SharedPreferencesAsync? storage}) async {
    await _writes;
    _storage = storage ?? await PreferencesStore.open();
    try {
      final raw = await _storage!.getString('devices.v1');
      if (raw == null) return;
      final values = <GamingDevice>[];
      for (final item in jsonDecode(raw) as List) {
        try {
          values.add(
            GamingDevice.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        } on Object {
          // Preserva os outros dispositivos válidos em caso de corrupção parcial
        }
      }
      _devices = List.unmodifiable(values);
      _lastWritten = raw;
      notifyListeners();
    } on Object {
      // Falhas parciais de leitura não impedem a inicialização do app
    }
  }

  Future<void> _save(List<GamingDevice> Function() update) {
    final task = _writes.then((_) async {
      final next = update()..sort((a, b) => a.name.compareTo(b.name));
      final encoded = jsonEncode(next.map((d) => d.toJson()).toList());
      if (encoded == _lastWritten) return;
      final storage = _storage ??= await PreferencesStore.open();
      await PreferencesStore.write(
        () => storage.setString('devices.v1', encoded),
      );
      _lastWritten = encoded;
      _devices = List.unmodifiable(next);
      notifyListeners();
    });
    _writes = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return _writes.then((_) => task);
  }

  Future<void> save(GamingDevice device) =>
      _save(() => [..._devices.where((d) => d.id != device.id), device]);

  Future<void> remove(String id) async {
    await _save(() => _devices.where((d) => d.id != id).toList());
    found.remove(id);
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final scanned = await _scan().timeout(const Duration(seconds: 20));
      await _save(
        () => [
          ..._devices.where((d) => !scanned.any((s) => s.id == d.id)),
          ...scanned,
        ],
      );
      found
        ..clear()
        ..addAll(scanned.map((d) => d.id));
    } on Object {
      error =
          'Não foi possível consultar o Bluetooth. Confira se ele está ativado e com permissão.';
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  Future<void> readDetails(GamingDevice device) {
    final task = _reads.then((_) async {
      if (!_devices.any((d) => d.id == device.id)) return;
      final updated = await _read(device);
      await _save(
        () => _devices
            .map((current) => current.id == device.id ? updated : current)
            .toList(),
      );
    });
    _reads = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return _reads.then((_) => task);
  }
}
