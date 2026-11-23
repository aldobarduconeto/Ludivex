import CoreBluetooth
import Foundation
#if os(iOS)
import AVFAudio
import Flutter
#else
import FlutterMacOS
#endif

final class LudivexBluetoothLister: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  private let batteryService = CBUUID(string: "180F")
  private let batteryLevel = CBUUID(string: "2A19")
  #if os(iOS)
  private let blePrefix = "ios:ble:"
  #else
  private let blePrefix = "macos:ble:"
  #endif
  private var manager: CBCentralManager?
  private var pending: FlutterResult?
  private var found: [String: [String: Any]] = [:]
  private var stop: DispatchWorkItem?
  private var scanning = false
  private var reading: CBPeripheral?
  private var openedConnection = false
  private var pendingRead: FlutterResult?
  private var readTimeout: DispatchWorkItem?
  private var lastBattery: [UUID: Int] = [:]

  func scan(_ result: @escaping FlutterResult) {
    guard pending == nil && pendingRead == nil else { result(FlutterError(code: "BUSY", message: "Uma operação Bluetooth já está em andamento.", details: nil)); return }
    pending = result
    found.removeAll()
    scheduleScanEnd(after: 10)
    #if os(iOS)
    for output in AVAudioSession.sharedInstance().currentRoute.outputs {
      if [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType) {
        found["audio:" + output.uid] = ["id": "ios:audio:" + output.uid, "name": output.portName, "kind": "headset"]
      }
    }
    #endif
    if let manager = manager { handleState(manager) }
    else { manager = CBCentralManager(delegate: self, queue: .main) }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state != .poweredOn && pendingRead != nil { finishRead() }
    handleState(central)
  }

  func readDetails(_ arguments: Any?, result: @escaping FlutterResult) {
    guard pending == nil && pendingRead == nil,
          let id = (arguments as? [String: Any])?["id"] as? String,
          id.hasPrefix(blePrefix),
          let uuid = UUID(uuidString: String(id.dropFirst(blePrefix.count))),
          let manager = manager, manager.state == .poweredOn,
          let peripheral = manager.retrievePeripherals(withIdentifiers: [uuid]).first
    else {
      result(FlutterError(code: "BLE_UNAVAILABLE", message: "Busque novamente o periférico Bluetooth antes de ler a bateria.", details: nil))
      return
    }
    reading = peripheral
    pendingRead = result
    peripheral.delegate = self
    let task = DispatchWorkItem { [weak self] in self?.finishRead() }
    readTimeout = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: task)
    openedConnection = peripheral.state != .connected
    if openedConnection {
      manager.connect(peripheral, options: nil)
    } else {
      peripheral.discoverServices([batteryService])
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    if peripheral === reading { peripheral.discoverServices([batteryService]) }
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    if peripheral === reading { finishRead() }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if peripheral === reading { finishRead() }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard peripheral === reading else { return }
    guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == batteryService })
    else { finishRead(); return }
    peripheral.discoverCharacteristics([batteryLevel], for: service)
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard peripheral === reading else { return }
    guard error == nil, let characteristic = service.characteristics?.first(where: {
      $0.uuid == batteryLevel && $0.properties.contains(.read)
    }) else { finishRead(); return }
    peripheral.readValue(for: characteristic)
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard peripheral === reading, characteristic.uuid == batteryLevel else { return }
    guard error == nil, let level = characteristic.value?.first, level <= 100
    else { finishRead(); return }
    lastBattery[peripheral.identifier] = Int(level)
    finishRead(level: Int(level))
  }

  private func finishRead(level: Int? = nil) {
    readTimeout?.cancel()
    readTimeout = nil
    let result = pendingRead
    pendingRead = nil
    if let peripheral = reading {
      reading = nil
      peripheral.delegate = nil
      if openedConnection && manager?.state == .poweredOn {
        manager?.cancelPeripheralConnection(peripheral)
      }
    }
    openedConnection = false
    if let level = level { result?(["battery": level]) }
    else { result?(FlutterError(code: "BATTERY_UNAVAILABLE", message: "O periférico não publicou a carga pelo Bluetooth LE.", details: nil)) }
  }

  private func handleState(_ central: CBCentralManager) {
    guard pending != nil else { return }
    switch central.state {
    case .poweredOn:
      guard !scanning else { return }
      scanning = true
      for peripheral in central.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1812"), CBUUID(string: "180F"), CBUUID(string: "180A"), CBUUID(string: "184E"), CBUUID(string: "1850")]) {
        add(peripheral, name: peripheral.name)
      }
      central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
      scheduleScanEnd(after: 6)
    case .unauthorized:
      finish(error: "Autorize o Bluetooth nas configurações do iPhone.")
    case .poweredOff:
      finish(error: "Ligue o Bluetooth nas configurações do iPhone.")
    case .unsupported:
      finish(error: "Bluetooth não disponível neste dispositivo.")
    default: break // Wait for the system permission/state callback.
    }
  }

  private func scheduleScanEnd(after seconds: TimeInterval) {
    stop?.cancel()
    let task = DispatchWorkItem { [weak self] in self?.finish() }
    stop = task
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    guard pending != nil else { return }
    add(peripheral, name: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name)
  }

  private func add(_ peripheral: CBPeripheral, name: String?) {
    let label = name ?? "Dispositivo Bluetooth"
    let value = label.lowercased()
    let kind = value.range(of: "controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir|joy-con", options: .regularExpression) != nil ? "controller"
      : value.range(of: "headset|headphone|earbud|arctis|wh-?[0-9]|wf-?[0-9]|airpods|buds|fone|jabra|bose|beats", options: .regularExpression) != nil ? "headset" : "other"
    var row: [String: Any] = ["id": blePrefix + peripheral.identifier.uuidString, "name": label, "kind": kind, "gattReadable": true]
    if let level = lastBattery[peripheral.identifier] { row["battery"] = level }
    found[peripheral.identifier.uuidString] = row
  }

  private func finish(error: String? = nil) {
    stop?.cancel()
    stop = nil
    if scanning { manager?.stopScan() }
    scanning = false
    let result = pending
    pending = nil
    if let error = error, found.isEmpty { result?(FlutterError(code: "BLUETOOTH", message: error, details: nil)) }
    else { result?(found.values.sorted { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }) }
  }
}
