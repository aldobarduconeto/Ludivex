import 'views/widgets/deal_grid.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/game_deal.dart';
import 'models/platform.dart';
import 'models/wishlist_item.dart';
import 'models/sale_campaign.dart';
import 'services/deals_api.dart';
import 'services/notification.dart';
import 'services/preferences_store.dart';
import 'services/wishlist_service.dart';
import 'views/add_wishlist_screen.dart';
import 'views/settings_screen.dart';
import 'views/sale_screen.dart';
import 'views/sale_banner.dart';
import 'views/wishlist_screen.dart';
import 'views/library_screen.dart';
import 'views/news_screen.dart';
import 'views/devices_screen.dart';
import 'services/device_service.dart';
import 'views/widgets/app_navigation.dart';
import 'services/library_service.dart';
import 'views/widgets/app_preferences.dart';
import 'views/widgets/deal_card.dart';
import 'views/widgets/app_sidebar.dart';
import 'views/widgets/discovery_hero.dart';
import 'views/widgets/app_theme.dart';
import 'views/widgets/welcome_dialog.dart';

class App extends StatefulWidget {
  const App({super.key, this.api, this.wishlist, this.backgroundSync = true});
  final DealsApi? api;
  final WishlistService? wishlist;
  final bool backgroundSync;
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _prefs = AppPreferences.instance;
  final _search = TextEditingController();
  late final DealsApi _api;
  late final WishlistService _wishlist;
  List<GameDeal> _deals = [];
  bool _loading = false, _foreground = true;
  bool _overlayOpen = false;
  bool _loadingMore = false;
  late int _displayPageSize, _visibleLimit;
  List<GameDeal>? _filteredInput;
  List<GameDeal> _filteredDeals = [];
  String? _filteredKey;
  DateTime? _filteredUntil;
  String? _error;
  String _query = '';
  int _tab = 0, _requestId = 0;
  GamePlatform? _filter;
  XboxCompatibility? _xboxCompatibility;
  bool _onlyFreeHub = false;
  String? _activeSearchTag;

  static const _quickSearchTags = [
    (id: 'free', label: '🎁 100% Grátis', hint: 'Jogos 100% gratuitos e resgates'),
    (id: 'discount_80', label: '🔥 80%+ OFF', hint: 'Descontos massivos a partir de 80%'),
    (id: 'under_10', label: r'⚡ Menos de R$ 10', hint: 'Super ofertas até 10 reais'),
    (id: 'under_25', label: r'🏷️ Menos de R$ 25', hint: 'Jogos até 25 reais'),
    (id: 'under_50', label: r'💎 Menos de R$ 50', hint: 'Jogos até 50 reais'),
    (id: 'pc', label: '💻 Lojas de PC', hint: 'Steam, Epic, Nuuvem, EA, Ubisoft'),
    (id: 'consoles', label: '🎯 Consoles', hint: 'PlayStation e Xbox'),
  ];
  Timer? _debounce, _timer;
  Timer? _collectionTimer;
  String? _catalogSignature;
  int? _minutes;
  final _shellKey = GlobalKey<ScaffoldState>();
  final _navigator = GlobalKey<NavigatorState>();
  final _offersAnchor = GlobalKey();
  final _campaignPager = PageController();
  final _campaignPage = ValueNotifier<int>(0);
  late final _lightTheme = LudivexTheme.buildLight();
  late final _darkTheme = LudivexTheme.buildDark();
  late final _oledTheme = LudivexTheme.buildOled();

  ThemeData get _activeDarkTheme {
    if (_prefs.themePreference == AppThemePreference.oled) {
      return _oledTheme;
    }
    if (_prefs.themePreference == AppThemePreference.system &&
        _prefs.oledWhenDark) {
      return _oledTheme;
    }
    return _darkTheme;
  }

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? DealsApi.instance;
    _wishlist = widget.wishlist ?? WishlistService.instance;
    _displayPageSize = _visibleLimit = _prefs.individualOfferCount;
    _prefs.addListener(_preferencesChanged);
    _wishlist.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
    _schedule();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunchPermissions();
    });
  }

  Future<void> _checkFirstLaunchPermissions() async {
    if (_prefs.permissionsRequested) return;
    final dialogContext = _navigator.currentState?.overlay?.context;
    if (!mounted || dialogContext == null) return;

    final granted = await WelcomeDialog.show(dialogContext);
    if (granted == null) return;
    _prefs.notificationsEnabled = granted;
    await _prefs.save();
    await _prefs.markPermissionsRequested();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _preferencesChanged() {
    if (_displayPageSize != _prefs.individualOfferCount) {
      _displayPageSize = _visibleLimit = _prefs.individualOfferCount;
    }
    if (_filter != null && !_prefs.platforms.contains(_filter)) _filter = null;
    _schedule();
    _changed();
  }

  void _schedule() {
    _scheduleCollection();
    if (_timer?.isActive == true &&
        _foreground &&
        _prefs.autoRefresh &&
        _minutes == _prefs.refreshMinutes)
      return;
    _timer?.cancel();
    if (!widget.backgroundSync ||
        !_foreground ||
        _overlayOpen ||
        !_prefs.autoRefresh)
      return;
    _minutes = _prefs.refreshMinutes;
    _timer = Timer.periodic(
      Duration(minutes: _minutes!),
      (_) => unawaited(_refresh()),
    );
  }

  void _scheduleCollection() {
    _collectionTimer?.cancel();
    if (!mounted ||
        !widget.backgroundSync ||
        !_foreground ||
        _overlayOpen ||
        _loading ||
        _loadingMore ||
        _catalogSignature != _prefs.sourceSignature ||
        !_api.hasMore)
      return;
    _collectionTimer = Timer(
      _api.collectionDelay,
      () => unawaited(_collectCatalog()),
    );
  }

  Future<void> _collectCatalog() async {
    if (!mounted || _loading || _loadingMore || !_foreground || _overlayOpen)
      return;
    final signature = _prefs.sourceSignature;
    setState(() => _loadingMore = true);
    try {
      final deals = await _api.loadMore();
      if (mounted && signature == _prefs.sourceSignature) {
        setState(() => _deals = deals);
        await _checkNewPromotions(deals);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'A coleta foi pausada e será tentada novamente. As ofertas carregadas foram mantidas.',
        );
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        _scheduleCollection();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
      if (!_overlayOpen) unawaited(_refresh());
    } else {
      _timer?.cancel();
      _collectionTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_preferencesChanged);
    _wishlist.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _collectionTimer?.cancel();
    _debounce?.cancel();
    _search.dispose();
    _campaignPager.dispose();
    _campaignPage.dispose();
    super.dispose();
  }

  Future<void> _checkNewPromotions(List<GameDeal> freshDeals) async {
    if (!NotificationService.instance.supported) return;
    final region = _prefs.region.country;
    final completed = _prefs.platforms.where((platform) {
      final status = _api.sources[platform.key];
      return status?['ok'] == true && status?['complete'] == true;
    }).toList();
    if (completed.isEmpty) return;

    final storage = await PreferencesStore.open();
    final newPromos = <GameDeal>[];
    await PreferencesStore.write(() async {
      for (final platform in completed) {
        final key = 'deals.active_promotions.v1.$region.${platform.key}';
        final active = {
          for (final deal in freshDeals)
            if (deal.platform == platform && deal.discount > 0 && !deal.isExpired)
              deal.id: deal,
        };
        final previous = await storage.getStringList(key);
        final seen = previous?.toSet();
        if (seen != null &&
            seen.length == active.length &&
            seen.containsAll(active.keys)) {
          continue;
        }
        await storage.setStringList(key, active.keys.toList());
        if (seen != null) {
          newPromos.addAll(
            active.values.where(
              (deal) =>
                  !seen.contains(deal.id) &&
                  deal.discount >= _prefs.minimumDiscount,
            ),
          );
        }
      }
    });
    if (!_prefs.permissionsRequested || !_prefs.notificationsEnabled) return;
    await NotificationService.instance.showNewPromotions(
      newPromos,
      sound: _prefs.notificationSound,
    );
  }

  Future<void> _refresh({bool force = false}) async {
    if (_loading && !force) return;
    if (!force && _catalogSignature == _prefs.sourceSignature && _api.hasMore) {
      _scheduleCollection();
      return;
    }
    _collectionTimer?.cancel();
    final generation = ++_requestId;
    final signature = _prefs.sourceSignature;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final deals = await _api.fetchDeals(
        forceRefresh: force,
        extraXboxIds: _wishlist.xboxIds,
      );
      if (!mounted ||
          generation != _requestId ||
          signature != _prefs.sourceSignature)
        return;
      setState(() {
        _deals = deals;
        _catalogSignature = signature;
      });
      await _checkNewPromotions(deals);
      await _wishlist.refresh(
        _api,
        knownQuotes: _api.freshDeals,
        notifications: _prefs.permissionsRequested && _prefs.notificationsEnabled,
        minimumDiscount: _prefs.alertMinimumDiscount,
        onAlert: (deal) => NotificationService.instance.showWishlistDeal(
          deal,
          sound: _prefs.notificationSound,
        ),
      );
    } catch (_) {
      if (mounted && generation == _requestId)
        setState(
          () => _error =
              'Não foi possível atualizar. Seus jogos salvos foram preservados.',
        );
    } finally {
      if (mounted && generation == _requestId) {
        setState(() => _loading = false);
        _scheduleCollection();
      }
    }
  }

  Future<void> _add(
    BuildContext context, {
    GameDeal? deal,
    WishlistItem? item,
  }) async {
    final previousOverlay = _overlayOpen;
    _overlayOpen = true;
    _timer?.cancel();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => _routeFrame(
          routeContext,
          AddWishlistScreen(
            api: _api,
            wishlist: _wishlist,
            initialDeal: deal,
            item: item,
          ),
          selected: -2,
        ),
      ),
    );
    _overlayOpen = previousOverlay;
    if (mounted) _schedule();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lista de desejos atualizada.')),
      );
      unawaited(_refresh());
    }
  }

  Future<void> _settings(BuildContext context) async {
    _overlayOpen = true;
    _timer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => _routeFrame(
          routeContext,
          SettingsScreen(
            api: _api,
            wishlist: _wishlist,
            onSaved: () {
              _schedule();
              unawaited(_refresh());
            },
          ),
          selected: 2,
        ),
      ),
    );
    _overlayOpen = false;
    if (mounted) _schedule();
  }

  Future<void> _openCampaign(
    BuildContext context,
    SaleCampaign campaign,
  ) async {
    _overlayOpen = true;
    _timer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => _routeFrame(
          routeContext,
          SaleScreen(
            campaign: campaign,
            api: _api,
            wishlist: _wishlist,
            onToggle: _toggle,
          ),
        ),
      ),
    );
    _overlayOpen = false;
    if (mounted) _schedule();
  }

  Future<void> _showMore() async {
    if (_loadingMore || _loading) return;
    final available = _visible().length;
    if (_prefs.individualOfferCount != 0 && _visibleLimit < available) {
      setState(() => _visibleLimit += _prefs.individualOfferCount);
      return;
    }
    setState(() => _loadingMore = true);
    final signature = _prefs.sourceSignature;
    try {
      final deals = await _api.loadMore(platform: _filter);
      if (mounted && signature == _prefs.sourceSignature) {
        setState(() {
          _deals = deals;
          if (_prefs.individualOfferCount != 0)
            _visibleLimit += _prefs.individualOfferCount;
        });
        await _checkNewPromotions(deals);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        _scheduleCollection();
      }
    }
  }

  Future<void> _toggle(BuildContext context, GameDeal deal) async {
    final item = _wishlist.find(deal);
    if (item == null) {
      await _add(context, deal: deal);
      return;
    }
    try {
      await _wishlist.remove(item.id);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar a lista.')),
        );
    }
  }

  Widget _sidebar(BuildContext context, {bool route = false, int? selected}) =>
      AppSidebar(
        selectedIndex: selected ?? _tab,
        wishlistCount: _wishlist.items.length,
        offerCount: _deals.where((d) => !d.isExpired).length,
        stores: _prefs.orderedPlatforms,
        activeStore: _filter,
        onNavigate: (index) {
          if (route && index == selected) return;
          _shellKey.currentState?.closeDrawer();
          if (route) _navigator.currentState!.popUntil((r) => r.isFirst);
          setState(() {
            _tab = index;
            if (index == 0) _filter = null;
          });
        },
        onStore: (store) {
          _shellKey.currentState?.closeDrawer();
          if (route) _navigator.currentState!.popUntil((r) => r.isFirst);
          setState(() {
            _tab = 0;
            _filter = store;
          });
        },
        onAdd: () {
          _shellKey.currentState?.closeDrawer();
          if (!(route && selected == -2)) _add(context);
        },
      );

  Widget _routeFrame(BuildContext context, Widget child, {int selected = -1}) =>
      AnimatedBuilder(
        animation: Listenable.merge([_prefs, _wishlist]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 1100
              ? child
              : Scaffold(
                  body: Row(
                    children: [
                      _sidebar(context, route: true, selected: selected),
                      Expanded(child: child),
                    ],
                  ),
                ),
        ),
      );
  Widget _desktopHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEU ESPAÇO PARA JOGAR MAIS',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _tab == 0
                    ? 'Descobrir'
                    : _tab == 1
                    ? 'Lista de desejos'
                    : _tab == devicesTabIndex
                    ? 'Dispositivos'
                    : _tab == 3
                    ? 'Biblioteca'
                    : _tab == newsTabIndex
                    ? 'Notícias'
                    : 'Configurações',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        if (_tab == 0)
          IconButton(
            tooltip: 'Atualizar ofertas',
            onPressed: _loading ? null : () => _refresh(force: true),
            icon: const Icon(Icons.sync_rounded, size: 21),
          ),
        const SizedBox(width: 12),
        if (_tab == 0)
          FilledButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar à lista'),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ludivex',
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _activeDarkTheme,
    themeMode: _prefs.themeMode,
    home: Builder(
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          return Scaffold(
            key: _shellKey,
            drawer: wide ? null : Drawer(width: 280, child: _sidebar(context)),
            appBar: wide
                ? null
                : AppBar(
                    leading: IconButton(
                      tooltip: 'Abrir menu',
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => _shellKey.currentState?.openDrawer(),
                    ),
                    titleSpacing: 0,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            width: 29,
                            height: 29,
                            cacheWidth: 87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'ludivex',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      if (_tab == 0)
                        IconButton(
                          tooltip: 'Atualizar ofertas',
                          onPressed: _loading
                              ? null
                              : () => _refresh(force: true),
                          icon: const Icon(Icons.sync_rounded, size: 21),
                        ),
                      if (_tab == 0)
                        IconButton(
                          tooltip: 'Adicionar à lista',
                          onPressed: () => _add(context),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 23,
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
            body: SafeArea(
              top: wide,
              child: Row(
                children: [
                  if (wide) _sidebar(context),
                  Expanded(
                    child: Column(
                      children: [
                        if (wide) _desktopHeader(context),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1600),
                              child: IndexedStack(
                                index: _tab,
                                children: [
                                  _catalog(context),
                                  WishlistScreen(
                                    service: _wishlist,
                                    onAdd: () => _add(context),
                                    onEdit: (item) => _add(context, item: item),
                                    onRefresh: () => _refresh(force: true),
                                  ),
                                  SettingsScreen(
                                    api: _api,
                                    wishlist: _wishlist,
                                    embedded: true,
                                    onSaved: () {
                                      _schedule();
                                      unawaited(_refresh());
                                    },
                                  ),
                                  LibraryScreen(
                                    service: LibraryService.instance,
                                  ),
                                  DevicesScreen(
                                    service: DeviceService.instance,
                                    active: _tab == devicesTabIndex,
                                  ),
                                  NewsScreen(
                                    library: LibraryService.instance,
                                    transport: _api.transport,
                                    active: _tab == newsTabIndex,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(alpha: .5),
                        ),
                      ),
                    ),
                    child: NavigationBar(
                      selectedIndex: _tab,
                      onDestinationSelected: (tab) {
                        if (_tab != tab) {
                          setState(() => _tab = tab);
                        }
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.explore_outlined),
                          selectedIcon: Icon(Icons.explore_rounded),
                          label: 'Descobrir',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.favorite_outline_rounded),
                          selectedIcon: Icon(Icons.favorite_rounded),
                          label: 'Desejos',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune_rounded),
                          label: 'Ajustes',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.videogame_asset_outlined),
                          selectedIcon: Icon(Icons.videogame_asset),
                          label: 'Biblioteca',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.devices_other_outlined),
                          selectedIcon: Icon(Icons.devices_other_rounded),
                          label: 'Setup',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.newspaper_outlined),
                          label: 'Notícias',
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    ),
  );
  List<GameDeal> _visible() {
    final now = DateTime.now();
    final key =
        '${_prefs.sourceSignature}:${_prefs.minimumDiscount}:${_prefs.freeOnly}:${_prefs.sort}:${_prefs.preferredPlatform}:$_query:$_filter:$_xboxCompatibility:$_onlyFreeHub:$_activeSearchTag';
    if (identical(_filteredInput, _deals) &&
        key == _filteredKey &&
        _filteredUntil != null &&
        now.isBefore(_filteredUntil!))
      return _filteredDeals;
    final deals = _deals.where((d) {
      if (d.isExpired) return false;
      if (!_prefs.platforms.contains(d.platform)) return false;
      if (_filter != null && d.platform != _filter) return false;
      if (_onlyFreeHub && !(d.isFree || d.discount >= 100)) return false;
      if (_filter == GamePlatform.xbox &&
          _xboxCompatibility != null &&
          d.xboxCompatibility != _xboxCompatibility) {
        return false;
      }
      if (d.discount < _prefs.minimumDiscount) return false;
      if (_prefs.freeOnly && !d.isFree) return false;

      // Filter by quick search tags
      if (_activeSearchTag != null) {
        switch (_activeSearchTag) {
          case 'free':
            if (!(d.isFree || d.discount >= 100)) return false;
            break;
          case 'discount_80':
            if (d.discount < 80) return false;
            break;
          case 'under_10':
            if (d.isFree || d.currentPrice > 10.0 || d.currentPrice <= 0) return false;
            break;
          case 'under_25':
            if (d.isFree || d.currentPrice > 25.0 || d.currentPrice <= 0) return false;
            break;
          case 'under_50':
            if (d.isFree || d.currentPrice > 50.0 || d.currentPrice <= 0) return false;
            break;
          case 'pc':
            final isPc = d.platform == GamePlatform.steam ||
                d.platform == GamePlatform.epic ||
                d.platform == GamePlatform.nuuvem ||
                d.platform == GamePlatform.ubisoft ||
                d.platform == GamePlatform.ea;
            if (!isPc) return false;
            break;
          case 'consoles':
            final isConsole = d.platform == GamePlatform.playstation ||
                d.platform == GamePlatform.xbox ||
                d.platform == GamePlatform.nintendo;
            if (!isConsole) return false;
            break;
        }
      }

      return _matchesQuery(d, _query);
    }).toList();
    final Comparator<GameDeal> compare = switch (_prefs.sort) {
      DealSort.discount => (a, b) {
        final result = b.discount.compareTo(a.discount);
        return result == 0 ? a.title.compareTo(b.title) : result;
      },
      DealSort.lowestPrice => (a, b) => a.currentPrice.compareTo(
        b.currentPrice,
      ),
      DealSort.title => (a, b) => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
    };
    deals.sort((a, b) {
      final first = a.platform == _prefs.preferredPlatform ? 0 : 1;
      final second = b.platform == _prefs.preferredPlatform ? 0 : 1;
      return first == second ? compare(a, b) : first.compareTo(second);
    });
    _filteredInput = _deals;
    _filteredKey = key;
    _filteredUntil = now.add(const Duration(minutes: 1));
    for (final deal in deals) {
      if (deal.expiresAt != null && deal.expiresAt!.isBefore(_filteredUntil!))
        _filteredUntil = deal.expiresAt;
    }
    return _filteredDeals = deals;
  }

  bool _matchesQuery(GameDeal d, String query) {
    if (query.isEmpty) return true;
    final q = query.trim().toLowerCase();

    // 100% discount / free game query keywords
    if (q == 'gratis' ||
        q == 'grátis' ||
        q == 'jogos gratis' ||
        q == 'jogos grátis' ||
        q == 'free' ||
        q == '100%' ||
        q == '100' ||
        q == 'desconto 100%' ||
        q == 'desconto de 100%' ||
        q == '0800' ||
        q == 'de graça' ||
        q == 'de graca') {
      return d.isFree || d.discount >= 100;
    }

    if (q == 'desconto' ||
        q == 'descontos' ||
        q == 'promocao' ||
        q == 'promoção' ||
        q == 'sale' ||
        q == 'oferta' ||
        q == 'ofertas') {
      return d.discount >= 50;
    }

    if (d.title.toLowerCase().contains(q)) return true;
    if (d.platform.label.toLowerCase().contains(q) ||
        d.platform.shortLabel.toLowerCase().contains(q)) {
      return true;
    }
    return false;
  }

  Widget _highlights(
    BuildContext context,
    List<GameDeal> available,
    List<SaleCampaign> campaigns,
    double scale,
  ) {
    final hero = DiscoveryHero(
      offerCount: available.length,
      storeCount: _prefs.platforms.length,
      featured: available.firstOrNull,
      onExplore: () {
        final anchor = _offersAnchor.currentContext;
        if (anchor != null)
          Scrollable.ensureVisible(
            anchor,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600 && campaigns.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Em destaque',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_prefs.platforms.length} lojas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 164 * scale,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: campaigns.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: constraints.maxWidth - 16,
                    child: SaleBanner(
                      campaign: campaigns[index],
                      onTap: () => _openCampaign(context, campaigns[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (constraints.maxWidth >= 950 &&
            scale < 1.3 &&
            campaigns.isNotEmpty) {
          return SizedBox(
            height: 292,
            child: Row(
              children: [
                Expanded(child: hero),
                const SizedBox(width: 20),
                SizedBox(
                  width: 322,
                  child: Column(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _campaignPage,
                        builder: (context, page, _) => Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'EM DESTAQUE',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Campanha anterior',
                              visualDensity: VisualDensity.compact,
                              onPressed: page > 0
                                  ? () => _campaignPager.previousPage(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_left, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Próxima campanha',
                              visualDensity: VisualDensity.compact,
                              onPressed: page < campaigns.length - 1
                                  ? () => _campaignPager.nextPage(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    )
                                  : null,
                              icon: const Icon(Icons.chevron_right, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: PageView.builder(
                          controller: _campaignPager,
                          onPageChanged: (page) => _campaignPage.value = page,
                          itemCount: campaigns.length,
                          itemBuilder: (_, index) => SaleBanner(
                            campaign: campaigns[index],
                            onTap: () =>
                                _openCampaign(context, campaigns[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            if (campaigns.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Em destaque',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 172 * scale,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: campaigns.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: constraints.maxWidth < 500 ? 276 : 330,
                    child: SaleBanner(
                      campaign: campaigns[index],
                      onTap: () => _openCampaign(context, campaigns[index]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _catalog(BuildContext context) {
    final available = _visible();
    final deals = _prefs.individualOfferCount == 0
        ? available
        : available.take(_visibleLimit).toList();
    final campaigns = _api.campaigns;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return RefreshIndicator.noSpinner(
      onRefresh: () => _refresh(force: true),
      child: CustomScrollView(
        key: const PageStorageKey('offers'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _highlights(context, available, campaigns, scale),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar nas ofertas carregadas',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () {
                        if (mounted)
                          setState(() => _query = value.trim().toLowerCase());
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tag in _quickSearchTags)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _activeSearchTag == tag.id,
                              label: Text(
                                tag.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeSearchTag == tag.id
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              tooltip: tag.hint,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              selectedColor: tag.id == 'free'
                                  ? const Color(0xFF20B969).withValues(alpha: 0.22)
                                  : tag.id == 'discount_80'
                                      ? Colors.redAccent.withValues(alpha: 0.22)
                                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                              side: BorderSide(
                                color: _activeSearchTag == tag.id
                                    ? (tag.id == 'free'
                                        ? const Color(0xFF20B969)
                                        : tag.id == 'discount_80'
                                            ? Colors.redAccent
                                            : Theme.of(context).colorScheme.primary)
                                    : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
                                width: _activeSearchTag == tag.id ? 1.4 : 0.8,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _activeSearchTag = selected ? tag.id : null;
                                });
                              },
                            ),
                          ),
                        if (_activeSearchTag != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => setState(() => _activeSearchTag = null),
                            icon: const Icon(Icons.close_rounded, size: 14),
                            label: const Text(
                              'Limpar tag',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.apps_rounded, size: 16),
                        label: const Text('Todas as lojas'),
                        selected: _filter == null && !_onlyFreeHub,
                        onSelected: (_) => setState(() {
                          _filter = null;
                          _onlyFreeHub = false;
                        }),
                      ),
                      ChoiceChip(
                        avatar: const Icon(
                          Icons.card_giftcard_rounded,
                          size: 16,
                          color: Color(0xFF20B969),
                        ),
                        label: const Text('🎁 100% Grátis da Semana'),
                        selected: _onlyFreeHub,
                        onSelected: (val) => setState(() {
                          _onlyFreeHub = val;
                          if (val) _filter = null;
                        }),
                      ),
                      ..._prefs.orderedPlatforms.map(
                        (platform) => ChoiceChip(
                          label: Text(platform.shortLabel),
                          avatar: Icon(
                            platform.icon,
                            size: 16,
                            color: platform.tint,
                          ),
                          selected: _filter == platform && !_onlyFreeHub,
                          onSelected: (_) => setState(() {
                            _filter = platform;
                            _onlyFreeHub = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_filter == GamePlatform.xbox)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Xbox: todos'),
                            selected: _xboxCompatibility == null,
                            onSelected: (_) =>
                                setState(() => _xboxCompatibility = null),
                          ),
                          for (final compatibility in XboxCompatibility.values)
                            ChoiceChip(
                              label: Text(compatibility.label),
                              selected: _xboxCompatibility == compatibility,
                              onSelected: (_) => setState(
                                () => _xboxCompatibility = compatibility,
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_api.warning != null) _notice(context, _api.warning!),
                  if (_error != null) _notice(context, _error!),
                  Wrap(
                    key: _offersAnchor,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        '${deals.length} de ${available.length} ofertas carregadas',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      DropdownButton<DealSort>(
                        value: _prefs.sort,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: DealSort.discount,
                            child: Text('Maior desconto'),
                          ),
                          DropdownMenuItem(
                            value: DealSort.lowestPrice,
                            child: Text('Menor preço'),
                          ),
                          DropdownMenuItem(
                            value: DealSort.title,
                            child: Text('Nome do jogo'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _prefs.sort = value;
                            unawaited(_prefs.save());
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (deals.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.travel_explore,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _loading
                          ? 'Seu catálogo está sendo preparado.'
                          : _prefs.platforms.isEmpty
                          ? 'Escolha suas lojas para começar.'
                          : 'Nenhuma oferta nesta consulta.',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _loading
                          ? 'Você pode abrir sua lista ou ajustar as lojas enquanto as ofertas chegam.'
                          : 'Confira os filtros e a configuração das APIs. Sua lista de desejos continua disponível.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _settings(context),
                      child: const Text('Configurar lojas e APIs'),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: DealGrid.delegate(
                  constraints.crossAxisExtent,
                  scale,
                  compact: _prefs.compactCards,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final deal = deals[index];
                  return DealCard(
                    key: ValueKey(deal.id),
                    deal: deal,
                    saved: _wishlist.contains(deal),
                    compact: _prefs.compactCards,
                    onToggle: () => _toggle(context, deal),
                  );
                }, childCount: deals.length),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (deals.length < available.length ||
                      _api.hasMoreFor(_filter))
                    OutlinedButton.icon(
                      key: const Key('load-more-deals'),
                      onPressed: _loadingMore || _loading ? null : _showMore,
                      icon: const Icon(Icons.add),
                      label: Text(
                        _loadingMore
                            ? 'Consulta em andamento'
                            : 'Mostrar mais promoções',
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _api.hasMore
                        ? 'Coletando automaticamente as promoções de todas as lojas selecionadas. As ofertas aparecem conforme as páginas chegam; pausas das APIs são respeitadas.'
                        : 'Coleta das páginas disponíveis concluída. Use Mostrar mais para revelar as ofertas já carregadas e confira os avisos de fontes indisponíveis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _api.updatedAt == null
                        ? 'Preços em reais. Confirme as condições na loja.'
                        : 'Consulta às ${DateFormat('HH:mm').format(_api.updatedAt!)} · Confirme preço e edição na loja.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context, String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer
          .withValues(alpha: .4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}
