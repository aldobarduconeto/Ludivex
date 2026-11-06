import Flutter
import UIKit
import CoreBluetooth
import AVFAudio
import UserNotifications
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceLister: LudivexBluetoothLister?
  private var deviceChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    engineBridge.pluginRegistry.registrar(forPlugin: "LudivexDiscovery")?
      .register(DiscoveryHeroFactory(), withId: "ludivex/discovery_hero")
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LudivexBluetoothDevices") {
      let lister = LudivexBluetoothLister()
      deviceLister = lister
      let channel = FlutterMethodChannel(name: "ludivex/devices", binaryMessenger: registrar.messenger())
      deviceChannel = channel
      channel.setMethodCallHandler { call, result in
        if call.method == "scan" { lister.scan(result) }
        else { result(FlutterMethodNotImplemented) }
      }
    }
  }
}

private final class DiscoveryHeroFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let data = args as? [String: Int] ?? [:]
    return DiscoveryHeroPlatformView(
      offers: data["offers"] ?? 0,
      stores: data["stores"] ?? 0
    )
  }
}

private final class DiscoveryHeroPlatformView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<DiscoveryHeroContent>

  init(offers: Int, stores: Int) {
    host = UIHostingController(rootView: DiscoveryHeroContent(offers: offers, stores: stores))
    super.init()
    host.view.backgroundColor = .clear
  }

  func view() -> UIView { host.view }
}

private struct DiscoveryHeroContent: View {
  let offers: Int
  let stores: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("DESCOBRIR", systemImage: "sparkle.magnifyingglass")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0.80, green: 0.85, blue: 1))

      Text("Seu próximo jogo começa aqui.")
        .font(.system(.largeTitle, design: .rounded).weight(.bold))
        .accessibilityAddTraits(.isHeader)

      Text("Ofertas de PC e consoles em um só lugar.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.86))

      HStack(spacing: 8) {
        metric("\(offers) ofertas", icon: "tag")
        metric("\(stores) lojas", icon: "bag")
      }
      .font(.footnote.weight(.semibold))
    }
    .foregroundStyle(.white)
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(LinearGradient(
          colors: [Color(red: 0.12, green: 0.16, blue: 0.36), Color(red: 0.29, green: 0.19, blue: 0.48)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ))
    }
  }
  private func metric(_ title: String, icon: String) -> some View {
    Label(title, systemImage: icon)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.white.opacity(0.14), in: Capsule())
  }
}

private final class LudivexBluetoothLister: NSObject, CBCentralManagerDelegate {
  private var manager: CBCentralManager?
  private var pending: FlutterResult?
  private var found: [String: [String: Any]] = [:]
  private var stop: DispatchWorkItem?
  private var scanning = false

  func scan(_ result: @escaping FlutterResult) {
    guard pending == nil else { result(FlutterError(code: "BUSY", message: "Uma busca Bluetooth já está em andamento.", details: nil)); return }
    pending = result
    found.removeAll()
    for output in AVAudioSession.sharedInstance().currentRoute.outputs {
      if [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType) {
        found["audio:" + output.uid] = ["id": "ios:audio:" + output.uid, "name": output.portName, "kind": "headset"]
      }
    }
    if let manager = manager { handleState(manager) }
    else { manager = CBCentralManager(delegate: self, queue: .main) }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) { handleState(central) }

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
      let task = DispatchWorkItem { [weak self] in self?.finish() }
      stop = task
      DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: task)
    case .unauthorized:
      finish(error: "Autorize o Bluetooth nas configurações do iPhone.")
    case .poweredOff:
      finish(error: "Ligue o Bluetooth nas configurações do iPhone.")
    case .unsupported:
      finish(error: "Bluetooth não disponível neste dispositivo.")
    default: break // Wait for the system permission/state callback.
    }
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
    found[peripheral.identifier.uuidString] = ["id": "ios:ble:" + peripheral.identifier.uuidString, "name": label, "kind": kind]
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
