import Cocoa
import FlutterMacOS
import IOBluetooth

class MainFlutterWindow: NSWindow {
  private var deviceChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(name: "ludivex/devices", binaryMessenger: flutterViewController.engine.binaryMessenger)
    deviceChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "scan" else { result(FlutterMethodNotImplemented); return }
      DispatchQueue.global(qos: .userInitiated).async {
        var devices: [[String: Any]] = []
        for case let device as IOBluetoothDevice in IOBluetoothDevice.pairedDevices() ?? [] {
          guard let address = device.addressString else { continue }
          let name = device.name ?? "Dispositivo Bluetooth"
          let value = name.lowercased()
          let kind = value.range(of: "controller|gamepad|dualsense|dualshock|xbox|8bitdo|gamesir|joy-con", options: .regularExpression) != nil ? "controller"
            : value.range(of: "headset|headphone|earbud|arctis|wh-?[0-9]|wf-?[0-9]|airpods|buds|fone|jabra|bose|beats", options: .regularExpression) != nil ? "headset" : "other"
          devices.append(["id": "macos:" + address, "name": name, "kind": kind])
        }
        let rows = devices.sorted { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
        DispatchQueue.main.async { result(rows) }
      }
    }

    super.awakeFromNib()
  }
}
