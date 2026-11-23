import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../models/gaming_device.dart';

final class _BatteryInformation extends Struct {
  @Uint8()
  external int type;

  @Uint8()
  external int level;
}

typedef _GetBatteryNative = Uint32 Function(
  Uint32,
  Uint8,
  Pointer<_BatteryInformation>,
);
typedef _GetBatteryDart = int Function(int, int, Pointer<_BatteryInformation>);
typedef _GetStateNative = Uint32 Function(Uint32, Pointer<Uint32>);
typedef _GetStateDart = int Function(int, Pointer<Uint32>);

const _gamepad = 0;
const _headset = 1;
const _alkaline = 2;
const _nickelMetalHydride = 3;
const _slotCount = 4;

List<GamingDevice> readWindowsControllerBatteries() {
  if (!Platform.isWindows) return const [];
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final DynamicLibrary library;
  try {
    library = DynamicLibrary.open('$systemRoot\\System32\\xinput1_4.dll');
  } on ArgumentError {
    return const [];
  }

  // XINPUT_STATE contains a DWORD followed by the 12-byte XINPUT_GAMEPAD.
  final state = calloc<Uint32>(4);
  final battery = calloc<_BatteryInformation>();
  try {
    final getState = library.lookupFunction<_GetStateNative, _GetStateDart>(
      'XInputGetState',
    );
    final getBattery = library
        .lookupFunction<_GetBatteryNative, _GetBatteryDart>(
          'XInputGetBatteryInformation',
        );
    final now = DateTime.now().toUtc();
    final devices = <GamingDevice>[];
    ({int type, DeviceBatteryLevel level})? read(int slot, int deviceType) {
      if (getBattery(slot, deviceType, battery) != 0) return null;
      final type = battery.ref.type;
      final level = battery.ref.level;
      if ((type != _alkaline && type != _nickelMetalHydride) ||
          level >= DeviceBatteryLevel.values.length) {
        return null;
      }
      return (type: type, level: DeviceBatteryLevel.values[level]);
    }

    for (var slot = 0; slot < _slotCount; slot++) {
      if (getState(slot, state) != 0) continue;
      final pad = read(slot, _gamepad);
      final headset = read(slot, _headset);
      if (pad != null) {
        devices.add(
          GamingDevice(
            id: 'xinput:$slot:gamepad',
            name: 'Controle sem fio ${slot + 1}',
            kind: GamingDeviceKind.controller,
            model: 'Controle compatível com XInput',
            batteryLevel: pad.level,
            seenAt: now,
          ),
        );
      }
      // Alguns controles repetem a própria leitura na consulta de fone.
      if (headset != null && headset != pad) {
        devices.add(
          GamingDevice(
            id: 'xinput:$slot:headset',
            name: 'Fone sem fio ${slot + 1}',
            kind: GamingDeviceKind.headset,
            model: 'Fone compatível com XInput',
            batteryLevel: headset.level,
            seenAt: now,
          ),
        );
      }
    }
    return devices;
  } on ArgumentError {
    return const [];
  } finally {
    calloc.free(battery);
    calloc.free(state);
    library.close();
  }
}
