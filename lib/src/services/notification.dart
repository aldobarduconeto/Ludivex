import 'dart:convert';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/game_deal.dart';
import '../models/platform.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ].contains(defaultTargetPlatform);

  Future<void> initialize() async {
    if (!supported) return;
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _initialized = true;
      return;
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      _initialized =
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: darwin,
              macOS: darwin,
            ),
          ) ??
          false;
    } on PlatformException {
      _initialized = false;
    } on MissingPluginException {
      _initialized = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) return true;
    if (!_initialized) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  int _stableId(String key) => key.codeUnits.fold<int>(
    0,
    (hash, unit) => (hash * 31 + unit) & 0x7fffffff,
  );

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool sound = true,
  }) async {
    if (!supported || !_initialized) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await _showWindowsToast(title, body);
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        sound ? 'price_alerts_sound' : 'price_alerts_silent',
        sound ? 'Quedas de preço e promoções' : 'Promoções silenciosas',
        channelDescription: 'Alertas dos jogos que você acompanha e novas promoções',
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound,
      ),
      iOS: DarwinNotificationDetails(presentSound: sound),
      macOS: DarwinNotificationDetails(presentSound: sound),
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (_) {}
  }

  Future<void> showWishlistDeal(GameDeal deal, {bool sound = true}) async {
    final title = '🎯 Desejo em promoção: ${deal.title}';
    final body = '${deal.formattedPrice} (${deal.discount}% off) na ${deal.platform.label}';
    await showNotification(
      id: _stableId(deal.id),
      title: title,
      body: body,
      payload: deal.storeUrl,
      sound: sound,
    );
  }

  Future<void> showNewPromotion(GameDeal deal, {bool sound = true}) async {
    final title = '🔥 Nova promoção: ${deal.title}';
    final body = '${deal.discount}% OFF! De ${deal.formattedOriginalPrice} por ${deal.formattedPrice} na ${deal.platform.label}';
    await showNotification(
      id: _stableId('promo_${deal.id}'),
      title: title,
      body: body,
      payload: deal.storeUrl,
      sound: sound,
    );
  }

  Future<void> showNewPromotions(
    List<GameDeal> deals, {
    bool sound = true,
  }) async {
    if (deals.length > 3) {
      await showNotification(
        id: _stableId('new_promotions_summary'),
        title: '${deals.length} novas promoções',
        body: deals.take(3).map((deal) => deal.title).join(' · '),
        sound: sound,
      );
      return;
    }
    for (final deal in deals) {
      await showNewPromotion(deal, sound: sound);
    }
  }

  Future<void> showDeal(GameDeal deal, {bool sound = true}) =>
      showWishlistDeal(deal, sound: sound);

  static Future<void> _showWindowsToast(String title, String body) async {
    try {
      final psScript = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
\$escapedTitle = [System.Security.SecurityElement]::Escape(@'$title'@)
\$escapedBody = [System.Security.SecurityElement]::Escape(@'$body'@)
\$template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>\$escapedTitle</text>
      <text>\$escapedBody</text>
    </binding>
  </visual>
</toast>
"@
\$xml.LoadXml(\$template)
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
\$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$appId).Show(\$toast)
''';
      final code = base64Encode(
        psScript.codeUnits.expand((c) => [c & 255, c >> 8]).toList(),
      );
      final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      await Process.start(
        '$root\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
        ['-NoProfile', '-NonInteractive', '-EncodedCommand', code],
      );
    } catch (_) {}
  }
}
