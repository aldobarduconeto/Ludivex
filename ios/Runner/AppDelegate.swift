import Flutter
import UIKit
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
        else if call.method == "readDetails" { lister.readDetails(call.arguments, result: result) }
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
