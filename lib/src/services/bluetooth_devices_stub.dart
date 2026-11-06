import '../models/gaming_device.dart';

bool get supported => false;
Future<List<GamingDevice>> scan() async => throw UnsupportedError(
  'Use o aplicativo Android ou Windows para consultar o Bluetooth.',
);
