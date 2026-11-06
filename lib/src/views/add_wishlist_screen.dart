import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_deal.dart';
import '../models/platform.dart';
import '../models/wishlist_item.dart';
import '../services/deals_api.dart';
import '../services/wishlist_service.dart';
import 'widgets/app_preferences.dart';
import 'widgets/page_components.dart';

double? parseTargetPrice(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d{1,7}([,.]\d{1,2})?$').hasMatch(value))
    throw const FormatException('Use um preço como 99,90');
  final parsed = double.parse(value.replaceAll(',', '.'));
  if (!parsed.isFinite || parsed < 0)
    throw const FormatException('Preço inválido');
  return parsed;
}

class AddWishlistScreen extends StatefulWidget {
  const AddWishlistScreen({
    super.key,
    required this.api,
    required this.wishlist,
    this.initialDeal,
    this.item,
  });
  final DealsApi api;
  final WishlistService wishlist;
  final GameDeal? initialDeal;
  final WishlistItem? item;
  @override
  State<AddWishlistScreen> createState() => _AddWishlistScreenState();
}

class _AddWishlistScreenState extends State<AddWishlistScreen> {
  final _form = GlobalKey<FormState>();
  final _query = TextEditingController(),
      _title = TextEditingController(),
      _url = TextEditingController(),
      _target = TextEditingController();
  Timer? _debounce;
  int _generation = 0, _mode = 0;
  bool _busy = false, _searching = false, _notify = true, _searched = false;
  String? _error;
  late GamePlatform _platform;
  GameDeal? _selected;
  List<GameDeal> _results = [];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDeal;
    _platform =
        widget.item?.platform ??
        widget.initialDeal?.platform ??
        AppPreferences.instance.platforms.firstOrNull ??
        GamePlatform.steam;
    _title.text = widget.item?.title ?? widget.initialDeal?.title ?? '';
    _url.text = widget.item?.storeUrl ?? widget.initialDeal?.storeUrl ?? '';
    _target.text =
        widget.item?.targetPrice?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
    _notify = widget.item?.notify ?? true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _title.dispose();
    _url.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    final generation = ++_generation;
    if (query.length < 3) {
      setState(() {
        _results = [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _searched = true;
    });
    try {
      final stores = AppPreferences.instance.platforms;
      final results = await widget.api.search(
        query,
        stores,
        extraXboxIds: widget.wishlist.xboxIds,
      );
      if (mounted && generation == _generation)
        setState(() => _results = results);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _results = [];
          _error =
              'Não foi possível buscar nas APIs selecionadas. Você pode adicionar pelo link.';
        });
    } finally {
      if (mounted && generation == _generation)
        setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final price = parseTargetPrice(_target.text);
      if (widget.item != null) {
        await widget.wishlist.update(
          widget.item!.id,
          targetCurrency:
              widget.item?.quote?.currency ??
              AppPreferences.instance.region.currency,
          targetPrice: price,
          notify: _notify,
        );
      } else if (_selected != null) {
        await widget.wishlist.addDeal(
          _selected!,
          targetPrice: price,
          notify: _notify,
        );
      } else {
        await widget.wishlist.addManual(
          platform: _platform,
          title: _title.text,
          storeUrl: _url.text,
          targetPrice: price,
          notify: _notify,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar. Confira os campos e tente novamente.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final detail = editing || _selected != null || _mode == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar acompanhamento' : 'Adicionar à lista'),
      ),
      bottomNavigationBar: !detail
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                child: FilledButton.icon(
                  key: const Key('save-wishlist-item'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.favorite_border),
                  label: Text(
                    _busy
                        ? 'Salvando…'
                        : editing
                        ? 'Salvar alterações'
                        : 'Adicionar à lista',
                  ),
                ),
              ),
            ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _form,
            child: ListView(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
              ),
              children: [
                PageIntro(
                  eyebrow: editing ? 'SEU ACOMPANHAMENTO' : 'EXPLORE AS LOJAS',
                  title: editing
                      ? 'Acompanhe do seu jeito.'
                      : 'Qual é o próximo jogo?',
                  description:
                      'Salve seus favoritos e defina o preço que você quer pagar. Tudo fica neste dispositivo.',
                  icon: Icons.favorite_outline_rounded,
                ),
                const SizedBox(height: 24),
                if (!editing && _selected == null) ...[
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.search),
                        label: Text('Buscar'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.link),
                        label: Text('Por link'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _busy
                        ? null
                        : (value) {
                            _debounce?.cancel();
                            _generation++;
                            setState(() {
                              _mode = value.first;
                              _searching = false;
                              _error = null;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                ],
                if (!detail) ...[
                  TextField(
                    key: const Key('wishlist-search'),
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Nome do jogo',
                      hintText: 'Digite pelo menos 3 letras',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _generation++;
                      _debounce = Timer(
                        const Duration(milliseconds: 700),
                        _search,
                      );
                    },
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      _search();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A busca usa as lojas e o país selecionados. A Epic inclui jogos gratuitos; PSN e Xbox consultam catálogos públicos.',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Você pode continuar digitando ou adicionar pelo link.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!),
                    ),
                  if (!_searching &&
                      _searched &&
                      _results.isEmpty &&
                      _error == null)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Nenhum resultado nesta consulta. Tente outro nome ou adicione pelo link.',
                      ),
                    ),
                  ..._results.take(50).map((deal) {
                    final saved = widget.wishlist.contains(deal);
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          deal.platform.icon,
                          color: deal.platform.tint,
                        ),
                        title: Text(deal.title),
                        subtitle: Text(
                          '${deal.platform.shortLabel} · ${deal.formattedPrice}',
                        ),
                        trailing: Icon(
                          saved ? Icons.check_circle : Icons.add_circle_outline,
                        ),
                        onTap: saved
                            ? null
                            : () => setState(() {
                                _selected = deal;
                                _platform = deal.platform;
                                _title.text = deal.title;
                              }),
                      ),
                    );
                  }),
                ],
                if (detail) ...[
                  if (_selected != null || editing)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selected?.title ?? widget.item!.title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_platform.label),
                            const SizedBox(height: 8),
                            Text(
                              _selected?.formattedPrice ??
                                  widget.item?.quote?.formattedPrice ??
                                  'Preço ainda não consultado',
                            ),
                            if (!editing && widget.initialDeal == null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selected = null),
                                child: const Text('Escolher outro jogo'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<GamePlatform>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: _platform,
                      decoration: const InputDecoration(labelText: 'Loja'),
                      items: [
                        for (final platform in GamePlatform.values)
                          DropdownMenuItem(
                            value: platform,
                            child: Text(platform.label),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _platform = value!),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('wishlist-title'),
                      controller: _title,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Nome do jogo',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Informe o nome do jogo.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('wishlist-url'),
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Link oficial do jogo',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (v) => validateStoreUrl(_platform, v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'O item pode ser salvo sem preço. O app tentará consultá-lo pela API; cobertura depende da loja.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('wishlist-target'),
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Preço desejado (opcional)',
                      prefixText:
                          '${_selected?.currency ?? widget.item?.quote?.currency ?? AppPreferences.instance.region.currency} ',
                      hintText: '99,90',
                      helperText:
                          'Vazio: acompanhar quedas. Preenchido: avisar ao atingir esse valor.',
                    ),
                    validator: (value) {
                      try {
                        parseTargetPrice(value ?? '');
                        return null;
                      } catch (_) {
                        return 'Use um valor como 99,90, sem separador de milhar.';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _notify,
                    title: const Text('Avisar sobre este jogo'),
                    subtitle: const Text(
                      'A verificação ocorre enquanto o app está aberto e ao retomá-lo.',
                    ),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _notify = v),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
