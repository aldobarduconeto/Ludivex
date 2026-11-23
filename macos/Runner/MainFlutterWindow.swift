import Cocoa
import FlutterMacOS
import IOBluetooth

class MainFlutterWindow: NSWindow {
  private var deviceChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?
  private var dragEvent: NSEvent?

  override func sendEvent(_ event: NSEvent) {
    if event.type == .leftMouseDown { dragEvent = event }
    if event.type == .leftMouseUp { dragEvent = nil }
    super.sendEvent(event)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    styleMask.insert(.fullSizeContentView)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
    let controls = FlutterMethodChannel(name: "ludivex/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel = controls
    controls.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "minimize": self.miniaturize(nil)
      case "maximize": self.zoom(nil)
      case "close": self.performClose(nil)
      case "drag":
        if let event = self.dragEvent {
          self.dragEvent = nil
          self.performDrag(with: event)
        }
      default: result(FlutterMethodNotImplemented); return
      }
      result(nil)
    }
    let channel = FlutterMethodChannel(name: "ludivex/devices", binaryMessenger: flutterViewController.engine.binaryMessenger)
    let lister = LudivexBluetoothLister()
    deviceChannel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "readDetails" { lister.readDetails(call.arguments, result: result); return }
      if call.method == "scanBle" { lister.scan(result); return }
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
