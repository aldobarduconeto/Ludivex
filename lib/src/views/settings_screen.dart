import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/platform.dart';
import '../models/store_region.dart';
import '../services/deals_api.dart';
import '../services/device_service.dart';
import '../services/game_scanner.dart';
import '../services/library_service.dart';
import '../services/mobile_game_launcher.dart';
import '../services/notification.dart';
import '../services/wishlist_service.dart';
import 'widgets/app_preferences.dart';
import 'widgets/page_components.dart';
import 'widgets/welcome_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.wishlist,
    required this.onSaved,
    this.embedded = false,
  });
  final DealsApi api;
  final WishlistService wishlist;
  final VoidCallback onSaved;
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = AppPreferences.instance;
  final _form = GlobalKey<FormState>();
  late final Map<GamePlatform, TextEditingController> _urls;
  late final TextEditingController _xbox;
  late Set<GamePlatform> _stores;
  late int _discount, _alertDiscount, _minutes;
  late int _offerCount;
  late GamePlatform _preferred;
  late StoreRegion _region;
  late bool _notify,
      _sound,
      _notifyPromotions,
      _free,
      _compact,
      _auto,
      _oledWhenDark,
      _bluetoothAuto,
      _libraryAuto;
  late AppThemePreference _themePreference;
  late DealSort _sort;
  bool _busy = false;
  bool _scanningDevices = false;
  bool _scanningLibrary = false;
  final _tests = <GamePlatform, String>{};

  @override
  void initState() {
    super.initState();
    _urls = {
      for (final p in GamePlatform.values)
        p: TextEditingController(text: _prefs.apiUrls[p] ?? ''),
    };
    _xbox = TextEditingController(text: _prefs.xboxProductIds.join(', '));
    _stores = {..._prefs.platforms};
    _region = _prefs.region;
    _discount = _prefs.minimumDiscount;
    _alertDiscount = _prefs.alertMinimumDiscount;
    _minutes = _prefs.refreshMinutes;
    _offerCount = _prefs.individualOfferCount;
    _preferred = _prefs.preferredPlatform;
    _notify = _prefs.notificationsEnabled;
    _sound = _prefs.notificationSound;
    _notifyPromotions = _prefs.notifyNewPromotions;
    _free = _prefs.freeOnly;
    _compact = _prefs.compactCards;
    _auto = _prefs.autoRefresh;
    _oledWhenDark = _prefs.oledWhenDark;
    _bluetoothAuto = _prefs.bluetoothAutoScan;
    _libraryAuto = _prefs.libraryAutoScan;
    _themePreference = _prefs.themePreference;
    _sort = _prefs.sort;
  }

  @override
  void dispose() {
    for (final controller in _urls.values) {
      controller.dispose();
    }
    _xbox.dispose();
    super.dispose();
  }

  void _message(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade900 : null,
      ),
    );
  }

  List<String> get _ids => _xbox.text
      .split(',')
      .map((s) => s.trim().toUpperCase())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  String? _urlError(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !uri.hasFragment
        ? null
        : 'Informe uma URL HTTPS válida (sem usuário, senha ou fragmento).';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      _prefs
        ..region = _region
        ..platforms = {..._stores}
        ..minimumDiscount = _discount
        ..alertMinimumDiscount = _alertDiscount
        ..refreshMinutes = _minutes
        ..individualOfferCount = _offerCount
        ..preferredPlatform = _preferred
        ..notificationsEnabled = _notify
        ..notificationSound = _sound
        ..notifyNewPromotions = _notifyPromotions
        ..freeOnly = _free
        ..compactCards = _compact
        ..autoRefresh = _auto
        ..oledWhenDark = _oledWhenDark
        ..bluetoothAutoScan = _bluetoothAuto
        ..libraryAutoScan = _libraryAuto
        ..themePreference = _themePreference
        ..sort = _sort
        ..apiUrls = {
          for (final entry in _urls.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim(),
        }
        ..xboxProductIds = _ids;
      await _prefs.save();
      widget.onSaved();
      _message('Configurações salvas com sucesso!');
    } catch (_) {
      _message('Não foi possível salvar as configurações.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test(GamePlatform platform) async {
    if (!_form.currentState!.validate()) return;
    if (platform == GamePlatform.nintendo &&
        _urls[platform]!.text.trim().isEmpty &&
        _region.country != 'BR') {
      setState(() => _tests[platform] =
          'A fonte integrada da Nintendo eShop está disponível na região Brasil.');
      return;
    }
    setState(() {
      _busy = true;
      _tests[platform] = 'Consultando a API…';
    });
    try {
      final count = await widget.api.testSource(
        platform,
        url: _urls[platform]!.text.trim(),
        region: _region,
        xboxIds: {..._ids, ...widget.wishlist.xboxIds}.take(100).toList(),
      );
      if (mounted) {
        setState(
          () =>
              _tests[platform] = 'Conexão bem-sucedida! ($count ofertas obtidas)',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _tests[platform] =
              'Falha na consulta. Verifique a URL, conexão e a região selecionada.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  Widget _section(String title, IconData icon, List<Widget> children) =>
      SectionPanel(title: title, icon: icon, children: children);

  Widget _switch(
    String title,
    String text,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(text),
    value: value,
    onChanged: onChanged,
  );

  Widget _buildThemeSelector() {
    final c = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final cards = AppThemePreference.values.map((pref) {
          final selected = _themePreference == pref;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _busy
                  ? null
                  : () {
                      setState(() {
                        _themePreference = pref;
                        _prefs.themePreference = pref;
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? c.primary.withValues(alpha: 0.12)
                      : c.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? c.primary
                        : c.outlineVariant.withValues(alpha: 0.5),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.primary
                                : c.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            pref.icon,
                            size: 20,
                            color: selected ? c.onPrimary : c.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (pref == AppThemePreference.oled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: c.primary.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '100% PRETO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: c.primary,
                              ),
                            ),
                          ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: c.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pref.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pref.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();

        if (isWide) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: cards,
          );
        }
        return Column(
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _exportWishlist() async {
    final jsonStr = widget.wishlist.exportJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    _message(
      'Lista exportada! ${widget.wishlist.items.length} jogos copiados para a área de transferência em formato JSON.',
    );
  }

  Future<void> _importWishlist() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Lista de Desejos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole abaixo o conteúdo JSON exportado anteriormente do Ludivex:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '[{"id": "...", "title": "..."}, ...]',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        final count = await widget.wishlist.importJson(controller.text.trim());
        _message('$count jogo(s) importado(s) com sucesso na lista de desejos!');
      } catch (e) {
        _message(
          'Erro ao importar lista: certifique-se de colar um JSON válido.',
          isError: true,
        );
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Configurações'),
              actions: [
                TextButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar'),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(color: c.outlineVariant.withValues(alpha: .5)),
          ),
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alterações são mantidas localmente neste dispositivo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('save-settings'),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(_busy ? 'Salvando…' : 'Salvar configurações'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Form(
            key: _form,
            child: ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
              ),
              children: [
                PageIntro(
                  eyebrow: 'PREFERÊNCIAS E SISTEMA',
                  title: 'Configurações',
                  description:
                      'Gerencie tema (claro, escuro ou OLED preto puro), lojas ativas, notificações, dispositivos e armazenamento. Tudo sob seu controle, sem envio de dados a terceiros.',
                  icon: Icons.tune_rounded,
                  metrics: [
                    MetricPill(
                      icon: Icons.palette_outlined,
                      label: _themePreference.label,
                    ),
                    MetricPill(
                      icon: Icons.storefront_outlined,
                      label: '${_stores.length} lojas ativas',
                    ),
                    MetricPill(
                      icon: Icons.notifications_none_rounded,
                      label: _notify ? 'Avisos ativos' : 'Avisos desligados',
                    ),
                    MetricPill(
                      icon: Icons.public_rounded,
                      label: '${_region.label} (${_region.currency})',
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ==================== TEMA E APARÊNCIA ====================
                _section('Tema e Experiência Visual', Icons.palette_outlined, [
                  const Text(
                    'Escolha a aparência ideal para o seu dispositivo. O tema OLED utiliza preto absoluto (#000000) com pixels desligados para máxima economia em telas OLED e AMOLED.',
                  ),
                  const SizedBox(height: 16),
                  _buildThemeSelector(),
                  if (_themePreference == AppThemePreference.system) ...[
                    const SizedBox(height: 8),
                    _switch(
                      'Preto Puro (OLED) no modo escuro do sistema',
                      'Quando o sistema operacional estiver no modo escuro, utiliza o tema preto absoluto #000000 em vez do cinza escuro.',
                      _oledWhenDark,
                      _busy
                          ? null
                          : (v) {
                              setState(() {
                                _oledWhenDark = v;
                                _prefs.oledWhenDark = v;
                              });
                            },
                    ),
                  ],
                  const Divider(height: 28),
                  _switch(
                    'Cartões compactos de ofertas',
                    'Reduz o espaçamento dos cards para exibir mais jogos simultaneamente na grade.',
                    _compact,
                    _busy ? null : (v) => setState(() => _compact = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GamePlatform>(
                    isExpanded: true,
                    itemHeight: null,
                    key: ValueKey('preferred-${_preferred.key}'),
                    initialValue: _preferred,
                    decoration: const InputDecoration(
                      labelText: 'Plataforma prioritária em destaque',
                      helperText:
                          'Aparece em primeiro lugar na listagem e na barra lateral.',
                    ),
                    items: [
                      for (final store in GamePlatform.values)
                        DropdownMenuItem(
                          value: store,
                          child: Row(
                            children: [
                              Icon(store.icon, size: 18, color: store.tint),
                              const SizedBox(width: 10),
                              Text(store.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _preferred = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    itemHeight: null,
                    key: ValueKey('offer-count-$_offerCount'),
                    initialValue: _offerCount,
                    decoration: const InputDecoration(
                      labelText: 'Promoções individuais por carregamento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 12,
                        child: Text('12 promoções (Mais rápido)'),
                      ),
                      DropdownMenuItem(
                        value: 24,
                        child: Text('24 promoções (Padrão balanceado)'),
                      ),
                      DropdownMenuItem(
                        value: 48,
                        child: Text('48 promoções'),
                      ),
                      DropdownMenuItem(
                        value: 96,
                        child: Text('96 promoções'),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Todas as ofertas carregadas de uma vez'),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _offerCount = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<DealSort>(
                    isExpanded: true,
                    itemHeight: null,
                    key: ValueKey(_sort),
                    initialValue: _sort,
                    decoration: const InputDecoration(
                      labelText: 'Ordenação padrão do catálogo',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DealSort.discount,
                        child: Text('Maior desconto percentual (%)'),
                      ),
                      DropdownMenuItem(
                        value: DealSort.lowestPrice,
                        child: Text('Menor preço atual'),
                      ),
                      DropdownMenuItem(
                        value: DealSort.title,
                        child: Text('Ordem alfabética (Nome do jogo)'),
                      ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _sort = v!),
                  ),
                ]),

                // ==================== LOJAS E APIS ====================
                _section('Lojas e Catálogo de Ofertas', Icons.hub_outlined, [
                  const Text(
                    'Selecione as lojas que deseja acompanhar. Suas promoções serão consolidadas na tela inicial.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _stores = GamePlatform.values.toSet(),
                              ),
                        icon: const Icon(Icons.select_all_rounded, size: 16),
                        label: const Text('Selecionar todas'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _stores = {
                                  GamePlatform.steam,
                                  GamePlatform.epic,
                                  GamePlatform.nuuvem,
                                  GamePlatform.ubisoft,
                                  GamePlatform.ea,
                                },
                              ),
                        icon: const Icon(Icons.computer_rounded, size: 16),
                        label: const Text('Apenas PC'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _stores = {
                                  GamePlatform.xbox,
                                  GamePlatform.playstation,
                                  GamePlatform.nintendo,
                                },
                              ),
                        icon: const Icon(Icons.sports_esports_outlined, size: 16),
                        label: const Text('Apenas consoles'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _stores.clear()),
                        child: const Text('Desmarcar todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...GamePlatform.values.map(
                    (platform) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: c.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _stores.contains(platform)
                              ? platform.tint.withValues(alpha: 0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            value: _stores.contains(platform),
                            title: Text(
                              platform.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            secondary: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: platform.tint.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                platform.icon,
                                color: platform.tint,
                                size: 18,
                              ),
                            ),
                            subtitle: Text(switch (platform) {
                              GamePlatform.steam =>
                                'Catálogo Steam, busca e consulta por App ID',
                              GamePlatform.epic =>
                                'Promoções com desconto e jogos grátis da semana',
                              GamePlatform.xbox =>
                                'Catálogo público regional e compatibilidade Play Anywhere',
                              GamePlatform.nuuvem =>
                                'Chaves digitais autorizadas nas regiões atendidas',
                              GamePlatform.ubisoft =>
                                'Ubisoft Store e descontos sazonais de PC',
                              GamePlatform.ea =>
                                'Catálogo da EA com cotações em moeda local',
                              GamePlatform.nintendo =>
                                'Ofertas digitais de Switch e Switch 2 no Brasil',
                              GamePlatform.playstation =>
                                'PlayStation Store oficial sem necessidade de login',
                            }, style: const TextStyle(fontSize: 12)),
                            onChanged: _busy
                                ? null
                                : (value) => setState(
                                    () => value == true
                                        ? _stores.add(platform)
                                        : _stores.remove(platform),
                                  ),
                          ),
                          ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              14,
                              0,
                              14,
                              12,
                            ),
                            maintainState: true,
                            title: const Text(
                              'Configuração avançada de API',
                              style: TextStyle(fontSize: 12.5),
                            ),
                            children: [
                              TextFormField(
                                key: ValueKey('api-${platform.key}'),
                                controller: _urls[platform],
                                enabled: !_busy,
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                                validator: _urlError,
                                decoration: InputDecoration(
                                  labelText: platform.requiresCatalogApi
                                      ? 'URL da API de preços ${platform.shortLabel}'
                                      : 'Endpoint alternativo da API (opcional)',
                                  hintText: 'https://api.exemplo.com/ofertas',
                                  helperText: platform.requiresCatalogApi
                                      ? 'Informe um endpoint compatível com o formato do Ludivex.'
                                      : 'Vazio: utiliza a consulta pública nativa integrada.',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _test(platform),
                                    icon: const Icon(
                                      Icons.network_check_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Testar conexão ${platform.shortLabel}',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _tests[platform] ??
                                          (widget.api.sources[platform.key] !=
                                                  null
                                              ? (widget.api.sources[platform
                                                          .key]['ok'] ==
                                                      true
                                                  ? '${widget.api.sources[platform.key]['count']} ofertas registradas'
                                                  : '${widget.api.sources[platform.key]['error']}')
                                              : 'Pronta para uso'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: c.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('xbox-product-ids'),
                    controller: _xbox,
                    enabled: !_busy,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'IDs de produtos Xbox (opcional)',
                      hintText: 'IDs de 12 caracteres separados por vírgula',
                      helperText:
                          'Jogos da Xbox adicionados à lista de desejos já são monitorados automaticamente.',
                    ),
                    validator: (_) =>
                        _ids.length > 100 ||
                            _ids.any(
                              (id) => !RegExp(r'^[A-Z0-9]{12}$').hasMatch(id),
                            )
                        ? 'Use até 100 IDs alfanuméricos de 12 dígitos.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<StoreRegion>(
                    isExpanded: true,
                    itemHeight: null,
                    key: ValueKey('region-${_region.country}'),
                    initialValue: _region,
                    decoration: const InputDecoration(
                      labelText: 'País e moeda regional das lojas',
                      helperText:
                          'Apresenta os preços nativos locais sem necessidade de conversão de câmbio.',
                    ),
                    items: [
                      for (final region in StoreRegion.values)
                        DropdownMenuItem(
                          value: region,
                          child: Text('${region.label} · ${region.currency}'),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _region = value!;
                            _tests.clear();
                          }),
                  ),
                ]),

                // ==================== NOTIFICAÇÕES E ALERTAS ====================
                _section(
                  'Notificações e Alertas de Preço',
                  Icons.notifications_active_outlined,
                  [
                    _switch(
                      'Notificações ativadas',
                      'Emite avisos no sistema ao encontrar preços atingidos na sua lista de desejos.',
                      _notify,
                      _busy ? null : (v) => setState(() => _notify = v),
                    ),
                    _switch(
                      'Som dos avisos',
                      'Toca um alerta sonoro discreto respeitando o modo silencioso do sistema operacional.',
                      _sound,
                      _busy || !_notify
                          ? null
                          : (v) => setState(() => _sound = v),
                    ),
                    _switch(
                      'Avisar sobre novas promoções em destaque',
                      'Envia aviso quando grandes campanhas sazonais ou jogos gratuitos de peso forem adicionados.',
                      _notifyPromotions,
                      _busy || !_notify
                          ? null
                          : (v) => setState(() => _notifyPromotions = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Desconto mínimo para disparar alerta:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$_alertDiscount%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _alertDiscount.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$_alertDiscount%',
                      onChanged: _busy || !_notify
                          ? null
                          : (v) => setState(() => _alertDiscount = v.round()),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  try {
                                    await NotificationService.instance
                                        .showNotification(
                                          id: 99999,
                                          title:
                                              '🎮 Notificação de Teste - Ludivex',
                                          body:
                                              'As notificações estão configuradas e funcionando corretamente!',
                                          sound: _sound,
                                        );
                                    _message('Notificação de teste disparada!');
                                  } catch (_) {
                                    _message(
                                      'Não foi possível disparar a notificação de teste.',
                                      isError: true,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Testar notificação agora'),
                        ),
                        if (NotificationService.instance.supported)
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    try {
                                      final allowed = await NotificationService
                                          .instance
                                          .requestPermission();
                                      if (!mounted) return;
                                      if (allowed) {
                                        setState(() => _notify = true);
                                      }
                                      _message(
                                        allowed
                                            ? 'Permissão de notificação concedida!'
                                            : 'Verifique a permissão de notificações nas configurações do dispositivo.',
                                      );
                                    } catch (_) {
                                      _message(
                                        'Falha ao solicitar permissão.',
                                        isError: true,
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.security_rounded,
                              size: 16,
                            ),
                            label: const Text('Solicitar permissão do sistema'),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await widget.wishlist.clearAlerts();
                                  _message('Histórico de avisos limpo.');
                                },
                          child: const Text('Limpar histórico de avisos'),
                        ),
                      ],
                    ),
                  ],
                ),

                // ==================== SINCRONIZAÇÃO E FILTROS ====================
                _section(
                  'Sincronização em Primeiro Plano e Filtros',
                  Icons.sync_rounded,
                  [
                    _switch(
                      'Atualização automática em primeiro plano',
                      'Atualiza periodicamente o catálogo enquanto você utiliza o aplicativo.',
                      _auto,
                      _busy ? null : (v) => setState(() => _auto = v),
                    ),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      itemHeight: null,
                      key: ValueKey(_minutes),
                      initialValue: _minutes,
                      decoration: const InputDecoration(
                        labelText: 'Intervalo de atualização das ofertas',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('1 minuto (Tempo real)'),
                        ),
                        DropdownMenuItem(
                          value: 5,
                          child: Text('5 minutos (Recomendado)'),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text('15 minutos'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 minutos'),
                        ),
                      ],
                      onChanged: _busy || !_auto
                          ? null
                          : (v) => setState(() => _minutes = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Desconto mínimo exibido no catálogo:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$_discount%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: c.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _discount.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$_discount%',
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _discount = v.round()),
                    ),
                    _switch(
                      'Somente jogos gratuitos (100% OFF)',
                      'Filtra o catálogo para exibir apenas ofertas com preço atual zerado.',
                      _free,
                      _busy ? null : (v) => setState(() => _free = v),
                    ),
                  ],
                ),
                // ==================== DISPOSITIVOS E HARDWARE ====================
                _section(
                  'Dispositivos e Bluetooth',
                  Icons.sports_esports_outlined,
                  [
                    const Text(
                      'Monitore o nível de bateria, modelo e status de conexão de controles Bluetooth (Xbox Wireless, DualSense, fones de ouvido).',
                    ),
                    const SizedBox(height: 12),
                    _switch(
                      'Buscar controles e fones ao abrir o app',
                      'Efetua uma checagem rápida no início da sessão para exibir baterias atualizadas.',
                      _bluetoothAuto,
                      _busy ? null : (v) => setState(() => _bluetoothAuto = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy || _scanningDevices
                              ? null
                              : () async {
                                  setState(() => _scanningDevices = true);
                                  try {
                                    await DeviceService.instance.refresh();
                                    _message(
                                      'Varredura concluída: ${DeviceService.instance.devices.length} dispositivo(s) encontrado(s).',
                                    );
                                  } catch (_) {
                                    _message(
                                      'Não foi possível concluir a busca de dispositivos.',
                                      isError: true,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _scanningDevices = false);
                                    }
                                  }
                                },
                          icon: _scanningDevices
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.bluetooth_searching_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _scanningDevices
                                ? 'Buscando dispositivos…'
                                : 'Buscar dispositivos agora',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ==================== BIBLIOTECA E JOGOS INSTALADOS ====================
                _section(
                  'Biblioteca e Jogos Instalados',
                  Icons.folder_special_outlined,
                  [
                    const Text(
                      'O Ludivex detecta automaticamente jogos instalados no seu PC (Steam, Epic Games, Xbox App) para acesso rápido.',
                    ),
                    const SizedBox(height: 12),
                    _switch(
                      'Escanear biblioteca ao iniciar o app',
                      'Verifica novos jogos baixados e atualiza a lista de jogos locais.',
                      _libraryAuto,
                      _busy ? null : (v) => setState(() => _libraryAuto = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy || _scanningLibrary
                              ? null
                              : () async {
                                  setState(() => _scanningLibrary = true);
                                  try {
                                    final scanResult = await (MobileGameLauncher.supported
                                        ? MobileGameLauncher.scan()
                                        : scanInstalledGames());
                                    await LibraryService.instance.importGames(scanResult.games);
                                    _message(
                                      'Biblioteca atualizada! ${LibraryService.instance.items.length} jogo(s) detectado(s).',
                                    );
                                  } catch (_) {
                                    _message(
                                      'Não foi possível escanear a biblioteca de jogos.',
                                      isError: true,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _scanningLibrary = false);
                                    }
                                  }
                                },
                          icon: _scanningLibrary
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(
                            _scanningLibrary
                                ? 'Escaneando jogos…'
                                : 'Escanear biblioteca agora',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // ==================== ARMAZENAMENTO E BACKUP ====================
                _section(
                  'Armazenamento, Backup e Cache',
                  Icons.save_outlined,
                  [
                    const Text(
                      'Exporte sua lista de desejos para backup ou transfira para outro computador. Limpe caches se desejar forçar novas consultas.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _exportWishlist,
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 16,
                          ),
                          label: const Text('Exportar Lista (JSON)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _importWishlist,
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 16,
                          ),
                          label: const Text('Importar Lista (JSON)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await widget.api.clearCache();
                                  _message('Cache de consultas limpo.');
                                },
                          icon: const Icon(Icons.cached_rounded, size: 16),
                          label: const Text('Limpar cache de ofertas'),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    const Text(
                      'Ações destrutivas:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (!await _confirm(
                                    'Excluir lista de desejos e histórico?',
                                    'Esta ação apagará permanentemente todos os jogos salvos, preços alvo e alertas locais. Não pode ser desfeita.',
                                  )) {
                                    return;
                                  }
                                  try {
                                    await widget.wishlist.clear();
                                    await widget.api.clearCache();
                                    _message('Lista e avisos excluídos.');
                                  } catch (_) {
                                    _message(
                                      'Não foi possível excluir os dados.',
                                      isError: true,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.delete_forever_rounded, size: 16),
                          label: const Text('Excluir lista de desejos'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (!await _confirm(
                                    'Restaurar padrões de fábrica?',
                                    'Restaura todas as opções de tema, lojas, intervalos e alertas para os valores padrão. Sua lista de desejos não será excluída.',
                                  )) {
                                    return;
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _stores = GamePlatform.values.toSet();
                                      _discount = 10;
                                      _offerCount = 24;
                                      _preferred = GamePlatform.steam;
                                      _region = StoreRegion.brazil;
                                      _alertDiscount = 0;
                                      _minutes = 5;
                                      _notify = true;
                                      _sound = true;
                                      _notifyPromotions = true;
                                      _free = false;
                                      _compact = false;
                                      _auto = true;
                                      _oledWhenDark = false;
                                      _bluetoothAuto = true;
                                      _libraryAuto = true;
                                      _themePreference =
                                          AppThemePreference.dark;
                                      _sort = DealSort.discount;
                                    });
                                    _message('Preferências restauradas!');
                                  }
                                },
                          child: const Text('Restaurar preferências padrão'),
                        ),
                      ],
                    ),
                  ],
                ),

                // ==================== SOBRE O LUDIVEX ====================
                _section('Sobre o Ludivex', Icons.info_outline_rounded, [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            cacheWidth: 144,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ludivex',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Versão 1.1.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'All your games. One place. Desenvolvido para centralizar ofertas, bibliotecas e periféricos com total respeito à sua privacidade.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => WelcomeDialog.show(context),
                        icon: const Icon(
                          Icons.slideshow_rounded,
                          size: 16,
                        ),
                        label: const Text('Ver apresentação inicial'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'ludivex',
                          applicationVersion: '1.0.1',
                        ),
                        icon: const Icon(Icons.code_rounded, size: 16),
                        label: const Text('Licenças de código aberto'),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
