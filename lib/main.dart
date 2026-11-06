import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/services/notification.dart';
import 'src/services/wishlist_service.dart';
import 'src/services/library_service.dart';
import 'src/services/preferences_store.dart';
import 'src/services/device_service.dart';
import 'src/views/widgets/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Roboto',
    ], await rootBundle.loadString('assets/fonts/roboto_license.txt'));
  });
  final storage = await PreferencesStore.open();
  await Future.wait([
    AppPreferences.instance.load(storage: storage),
    WishlistService.instance.load(storage: storage),
    LibraryService.instance.load(storage: storage),
    DeviceService.instance.load(storage: storage),
  ]);
  await NotificationService.instance.initialize();
  runApp(const App());
}
