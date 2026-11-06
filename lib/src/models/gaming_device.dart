enum GamingDeviceKind { controller, headset, other }

extension GamingDeviceKindLabel on GamingDeviceKind {
  String get label => switch (this) {
    GamingDeviceKind.controller => 'Controle',
    GamingDeviceKind.headset => 'Fone Bluetooth',
    GamingDeviceKind.other => 'Dispositivo Bluetooth',
  };
}

class GamingDevice {
  const GamingDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.seenAt,
    this.manufacturer = '',
    this.model,
    this.firmware,
    this.battery,
    this.gattReadable = false,
    this.manual = false,
  });
  final String id, name, manufacturer;
  final String? model;
  final GamingDeviceKind kind;
  final DateTime seenAt;
  final String? firmware;
  final int? battery;
  final bool gattReadable, manual;

  String get displayModel {
    if (model != null && model!.trim().isNotEmpty) return model!.trim();
    final lower = name.toLowerCase();
    if (lower.contains('xbox') && lower.contains('controller')) {
      return 'Xbox Wireless Controller (Model 1914/1708)';
    }
    if (lower.contains('dualsense')) {
      return 'Sony DualSense Wireless (CFI-ZCT1W)';
    }
    if (lower.contains('dualshock')) {
      return 'Sony DualShock 4 Wireless (CUH-ZCT2)';
    }
    if (lower.contains('8bitdo')) {
      return '8BitDo Ultimate / Pro Wireless';
    }
    if (lower.contains('buds') || lower.contains('galaxy buds')) {
      return 'Samsung Galaxy Buds Series (TWS Bluetooth)';
    }
    if (lower.contains('airpods')) {
      return 'Apple AirPods Wireless Audio';
    }
    if (lower.contains('wh-1000') || lower.contains('wf-1000')) {
      return 'Sony 1000X Noise Cancelling Series';
    }
    if (lower.contains('arctis')) {
      return 'SteelSeries Arctis Gaming Headset';
    }
    if (manufacturer.isNotEmpty && manufacturer != 'Desconhecido') {
      return '$manufacturer ${kind.label}';
    }
    return '${kind.label} Bluetooth';
  }

  String get displayManufacturer {
    if (manufacturer.isNotEmpty && manufacturer != 'Desconhecido') {
      return manufacturer;
    }
    final lower = name.toLowerCase();
    if (lower.contains('xbox')) return 'Microsoft';
    if (lower.contains('dualsense') ||
        lower.contains('dualshock') ||
        lower.contains('playstation') ||
        lower.contains('sony') ||
        lower.contains('wh-') ||
        lower.contains('wf-')) {
      return 'Sony';
    }
    if (lower.contains('buds') || lower.contains('galaxy')) return 'Samsung';
    if (lower.contains('airpods') || lower.contains('apple')) return 'Apple';
    if (lower.contains('8bitdo')) return '8BitDo';
    if (lower.contains('gamesir')) return 'GameSir';
    if (lower.contains('razer')) return 'Razer';
    if (lower.contains('logitech')) return 'Logitech G';
    if (lower.contains('jbl')) return 'JBL';
    return 'Bluetooth PnP';
  }

  factory GamingDevice.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (id.isEmpty || name.trim().isEmpty) {
      throw const FormatException('Dispositivo inválido');
    }
    final battery = json['battery'];
    final rawModel = json['model'] as String?;
    return GamingDevice(
      id: id,
      name: name,
      kind: GamingDeviceKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => GamingDeviceKind.other,
      ),
      manufacturer: json['manufacturer'] as String? ?? '',
      model: rawModel != null && rawModel.trim().isNotEmpty ? rawModel.trim() : null,
      firmware: (json['firmware'] as String?)?.trim().isEmpty == false
          ? json['firmware'] as String
          : null,
      battery: battery is num && battery >= 0 && battery <= 100
          ? battery.toInt()
          : null,
      seenAt:
          DateTime.tryParse(json['seenAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      gattReadable: json['gattReadable'] == true,
      manual: json['manual'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'manufacturer': manufacturer,
    'model': model,
    'firmware': firmware,
    'battery': battery,
    'seenAt': seenAt.toIso8601String(),
    'gattReadable': gattReadable,
    'manual': manual,
  };
}
