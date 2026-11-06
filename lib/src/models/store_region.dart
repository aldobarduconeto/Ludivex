/// Storefront markets, not currency conversion targets.
class StoreRegion {
  const StoreRegion(
    this.country,
    this.label,
    this.locale,
    this.currency,
    this.steamLanguage, {
    this.nuuvemLocale,
  });
  final String country, label, locale, currency, steamLanguage;
  final String? nuuvemLocale;
  String get lowerLocale => locale.toLowerCase();
  String get underscoreLocale => locale.replaceAll('-', '_');
  static const brazil = StoreRegion(
    'BR',
    'Brasil',
    'pt-BR',
    'BRL',
    'brazilian',
    nuuvemLocale: 'br-pt',
  );
  static const values = [
    brazil,
    StoreRegion(
      'US',
      'Estados Unidos',
      'en-US',
      'USD',
      'english',
      nuuvemLocale: 'us-en',
    ),
    StoreRegion('PT', 'Portugal', 'pt-PT', 'EUR', 'portuguese'),
    StoreRegion('GB', 'Reino Unido', 'en-GB', 'GBP', 'english'),
    StoreRegion('DE', 'Alemanha', 'de-DE', 'EUR', 'german'),
    StoreRegion('FR', 'França', 'fr-FR', 'EUR', 'french'),
    StoreRegion('ES', 'Espanha', 'es-ES', 'EUR', 'spanish'),
    StoreRegion('CA', 'Canadá', 'en-CA', 'CAD', 'english'),
    StoreRegion('MX', 'México', 'es-MX', 'MXN', 'latam', nuuvemLocale: 'mx-es'),
    StoreRegion(
      'AR',
      'Argentina',
      'es-AR',
      'USD',
      'latam',
      nuuvemLocale: 'ar-es',
    ),
    StoreRegion('CL', 'Chile', 'es-CL', 'CLP', 'latam', nuuvemLocale: 'cl-es'),
    StoreRegion(
      'CO',
      'Colômbia',
      'es-CO',
      'COP',
      'latam',
      nuuvemLocale: 'co-es',
    ),
    StoreRegion('AU', 'Austrália', 'en-AU', 'AUD', 'english'),
    StoreRegion('JP', 'Japão', 'ja-JP', 'JPY', 'japanese'),
    StoreRegion('IN', 'Índia', 'en-IN', 'INR', 'english'),
  ];
  static StoreRegion parse(String? code) =>
      values.where((r) => r.country == code).firstOrNull ?? brazil;

  // Store currencies can vary by merchant (e.g. Steam LATAM uses USD).
  Set<String> get allowedCurrencies => switch (country) {
    'AR' => {'ARS', 'USD'},
    _ => {currency},
  };

  double? parsePrice(String? value) {
    if (value == null) return null;
    var text = value.replaceAll(RegExp(r'[^0-9,.]'), '');
    if (text.isEmpty) return null;
    final comma = text.lastIndexOf(',');
    final dot = text.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      text = comma > dot
          ? text.replaceAll('.', '').replaceAll(',', '.')
          : text.replaceAll(',', '');
    } else if (comma >= 0) {
      final decimalComma = !{
        'US',
        'GB',
        'CA',
        'AU',
        'JP',
        'IN',
        'MX',
      }.contains(country);
      text = decimalComma
          ? text.replaceAll(',', '.')
          : text.replaceAll(',', '');
    } else if (dot >= 0 &&
        {'CL', 'CO', 'DE', 'ES', 'PT'}.contains(country) &&
        text.length - dot - 1 == 3) {
      text = text.replaceAll('.', '');
    }
    return double.tryParse(text);
  }
}
