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
import 'views/widgets/page_components.dart';
import 'views/widgets/app_theme.dart';
import 'views/widgets/welcome_dialog.dart';
import 'views/widgets/desktop_top_bar.dart';
import 'views/widgets/game_roulette_dialog.dart';
import 'views/store_screen.dart';

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
  bool _desktopRouteOpen = false;
  bool _loadingMore = false;
  late int _displayPageSize, _visibleLimit;
  List<GameDeal>? _filteredInput;
  List<GameDeal> _filteredDeals = [];
  String? _filteredKey;
  DateTime? _filteredUntil;
  String? _error;
  String _query = '';
  late int _tab;
  int _appearanceRequest = 0;
  int _requestId = 0;
  GamePlatform? _filter;
  XboxCompatibility? _xboxCompatibility;
  bool _onlyFreeHub = false;
  String? _activeSearchTag;

  static const _quickSearchTags = [
    (id: 'free', label: 'Grátis', hint: 'Jogos 100% gratuitos e resgates'),
    (
      id: 'discount_80',
      label: '80% ou mais de desconto',
      hint: 'Descontos massivos a partir de 80%',
    ),
    (
      id: 'under_10',
      label: r'Menos de R$ 10',
      hint: 'Super ofertas até 10 reais',
    ),
    (id: 'under_25', label: r'Menos de R$ 25', hint: 'Jogos até 25 reais'),
    (id: 'under_50', label: r'Menos de R$ 50', hint: 'Jogos até 50 reais'),
    (id: 'pc', label: 'Lojas de PC', hint: 'Steam, Epic, Nuuvem, EA, Ubisoft'),
    (id: 'consoles', label: 'Consoles', hint: 'PlayStation e Xbox'),
  ];
  Timer? _debounce, _timer;
  String? _catalogSignature;
  int? _minutes;
  final _shellKey = GlobalKey<ScaffoldState>();
  final _navigator = GlobalKey<NavigatorState>();
  final _offersAnchor = GlobalKey();
  final _campaignScroll = ScrollController();
  late ThemeData _lightTheme, _darkTheme, _oledTheme;
  Color? _themeAccent;

  void _updateThemes() {
    _themeAccent = _prefs.accentColor;
    _lightTheme = LudivexTheme.build(
      Brightness.light,
      accentColor: _themeAccent,
    );
    _darkTheme = LudivexTheme.build(Brightness.dark, accentColor: _themeAccent);
    _oledTheme = LudivexTheme.build(
      Brightness.dark,
      oled: true,
      accentColor: _themeAccent,
    );
  }

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
    _tab = _prefs.startPage.tabIndex;
    _updateThemes();
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
    if (_themeAccent != _prefs.accentColor) _updateThemes();
    if (_displayPageSize != _prefs.individualOfferCount) {
      _displayPageSize = _visibleLimit = _prefs.individualOfferCount;
    }
    if (_filter != null && !_prefs.platforms.contains(_filter)) _filter = null;
    _schedule();
    _changed();
  }

  void _schedule() {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
      if (!_overlayOpen) unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_preferencesChanged);
    _wishlist.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _debounce?.cancel();
    _search.dispose();
    _campaignScroll.dispose();
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
            if (deal.platform == platform &&
                deal.discount > 0 &&
                !deal.isExpired)
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
    if (!force &&
        _catalogSignature == _prefs.sourceSignature &&
        _deals.isNotEmpty) {
      return;
    }
    final generation = ++_requestId;
    final signature = _prefs.sourceSignature;
    if (force) {
      _filteredKey = null;
      _filteredInput = null;
    }
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
        notifications:
            _prefs.permissionsRequested && _prefs.notificationsEnabled,
        minimumDiscount: _prefs.alertMinimumDiscount,
        onAlert: (deal) => NotificationService.instance.showWishlistDeal(
          deal,
          sound: _prefs.notificationSound,
        ),
      );
    } catch (_) {
      if (mounted && generation == _requestId)
        setState(
          () => _error = 'Não foi possível atualizar. Seus jogos salvos foram preservados.',
        );
    } finally {
      if (mounted && generation == _requestId) {
        setState(() => _loading = false);
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
          builder: (context, constraints) =>
              constraints.maxWidth < appSidebarBreakpoint
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
  String get _sectionTitle => switch (_tab) {
    0 => 'Descobrir',
    1 => 'Lista de desejos',
    3 => 'Biblioteca',
    devicesTabIndex => 'Dispositivos',
    newsTabIndex => 'Notícias',
    _ => 'Configurações',
  };

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ludivex',
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _activeDarkTheme,
    themeMode: _prefs.themeMode,
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: _prefs.textSize == 0
            ? media
            : media.copyWith(
                textScaler: TextScaler.linear(_prefs.textSize / 100),
              ),
        child: Builder(builder: (context) => _buildAppFrame(context, child)),
      );
    },
    home: Builder(
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= appSidebarBreakpoint;
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
                    centerTitle: true,
                    title: Text(_sectionTitle, overflow: TextOverflow.ellipsis),
                  ),
            body: SafeArea(
              top: wide,
              child: Row(
                children: [
                  if (wide) _sidebar(context),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _LazySections(
                            index: _tab,
                            pages: [
                              () => _catalog(context),
                              () => WishlistScreen(
                                service: _wishlist,
                                onAdd: () => _add(context),
                                onEdit: (item) => _add(context, item: item),
                                onRefresh: () => _refresh(force: true),
                              ),
                              () => SettingsScreen(
                                api: _api,
                                wishlist: _wishlist,
                                embedded: true,
                                showTitle: wide,
                                appearanceRequest: _appearanceRequest,
                                onSaved: () {
                                  _schedule();
                                  unawaited(_refresh());
                                },
                              ),
                              () => LibraryScreen(
                                service: LibraryService.instance,
                                active: _tab == 3,
                              ),
                              () => DevicesScreen(
                                service: DeviceService.instance,
                                active: _tab == devicesTabIndex,
                                showTitle: wide,
                                onAppearance: () => setState(() {
                                  _appearanceRequest++;
                                  _tab = 2;
                                }),
                              ),
                              () => NewsScreen(
                                library: LibraryService.instance,
                                transport: _api.transport,
                                active: _tab == newsTabIndex,
                              ),
                            ],
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
                      labelBehavior: constraints.maxWidth < 420
                          ? NavigationDestinationLabelBehavior.onlyShowSelected
                          : NavigationDestinationLabelBehavior.alwaysShow,
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
                          label: 'Dispositivos',
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

  Widget _buildAppFrame(BuildContext context, Widget? child) {
    if (!hasDesktopTopBar || child == null) return child ?? const SizedBox();
    final library = LibraryService.instance;
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        final routeOpen = _navigator.currentState?.canPop() ?? false;
        if (_desktopRouteOpen != routeOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _desktopRouteOpen = routeOpen);
          });
        }
        return false;
      },
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) => DesktopTopBar(
          onStores: _desktopRouteOpen
              ? null
              : () {
                  final navigator = _navigator.currentState;
                  if (navigator == null || navigator.canPop()) return;
                  navigator.push<void>(
                    MaterialPageRoute(
                      builder: (_) => StoreScreen(library: library),
                    ),
                  );
                },
          onRandomGame: _desktopRouteOpen || library.items.isEmpty
              ? null
              : () {
                  final navigator = _navigator.currentState;
                  if (navigator == null || navigator.canPop()) return;
                  GameRouletteDialog.show(
                    navigator.overlay!.context,
                    library.items,
                  );
                },
          onRefresh: _loading ? null : () => _refresh(force: true),
          child: child,
        ),
      ),
    );
  }

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
            if (d.isFree || d.currentPrice > 10.0 || d.currentPrice <= 0)
              return false;
            break;
          case 'under_25':
            if (d.isFree || d.currentPrice > 25.0 || d.currentPrice <= 0)
              return false;
            break;
          case 'under_50':
            if (d.isFree || d.currentPrice > 50.0 || d.currentPrice <= 0)
              return false;
            break;
          case 'pc':
            final isPc =
                d.platform == GamePlatform.steam ||
                d.platform == GamePlatform.epic ||
                d.platform == GamePlatform.nuuvem ||
                d.platform == GamePlatform.ubisoft ||
                d.platform == GamePlatform.ea;
            if (!isPc) return false;
            break;
          case 'consoles':
            final isConsole =
                d.platform == GamePlatform.playstation ||
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
    if (key == _filteredKey && _filteredDeals.isNotEmpty) {
      final existingIds = {for (final d in _filteredDeals) d.id};
      final dealsMap = {for (final d in deals) d.id: d};
      final preserved = <GameDeal>[];
      for (final d in _filteredDeals) {
        final current = dealsMap[d.id];
        if (current != null) {
          preserved.add(current);
        }
      }
      final fresh = deals.where((d) => !existingIds.contains(d.id)).toList();
      fresh.sort((a, b) {
        final first = a.platform == _prefs.preferredPlatform ? 0 : 1;
        final second = b.platform == _prefs.preferredPlatform ? 0 : 1;
        return first == second ? compare(a, b) : first.compareTo(second);
      });
      deals
        ..clear()
        ..addAll(preserved)
        ..addAll(fresh);
    } else {
      deals.sort((a, b) {
        final first = a.platform == _prefs.preferredPlatform ? 0 : 1;
        final second = b.platform == _prefs.preferredPlatform ? 0 : 1;
        return first == second ? compare(a, b) : first.compareTo(second);
      });
    }
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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12).clamp(0.0, 320.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DiscoveryHero(
              offerCount: available.length,
              featured: available.firstOrNull,
              onExplore: () {
                final anchor = _offersAnchor.currentContext;
                if (anchor != null) {
                  Scrollable.ensureVisible(
                    anchor,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                  );
                }
              },
              onRefresh: _loading ? null : () => _refresh(force: true),
              onAdd: () => _add(context),
            ),
            if (campaigns.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Campanhas',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (campaigns.length * (cardWidth + 12) - 12 >
                      constraints.maxWidth) ...[
                    for (final direction in [-1, 1])
                      IconButton(
                        tooltip: direction < 0
                            ? 'Campanha anterior'
                            : 'Próxima campanha',
                        onPressed: () {
                          if (!_campaignScroll.hasClients) return;
                          final target =
                              (_campaignScroll.offset +
                                      direction * (cardWidth + 12))
                                  .clamp(
                                    0.0,
                                    _campaignScroll.position.maxScrollExtent,
                                  );
                          if (MediaQuery.disableAnimationsOf(context)) {
                            _campaignScroll.jumpTo(target);
                          } else {
                            _campaignScroll.animateTo(
                              target,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        icon: Icon(
                          direction < 0
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96 + (scale - 1) * 86,
                child: ListView.separated(
                  controller: _campaignScroll,
                  scrollDirection: Axis.horizontal,
                  itemCount: campaigns.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: cardWidth,
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
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 4.0);
    final gutter = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return RefreshIndicator.noSpinner(
      onRefresh: () => _refresh(force: true),
      child: CustomScrollView(
        key: const PageStorageKey('offers'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _highlights(context, available, campaigns, scale),
                  const SizedBox(height: 12),
                  CollectionSearchField(
                    controller: _search,
                    hint: 'Buscar ofertas',
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 250), () {
                        if (mounted) {
                          setState(() => _query = value.trim().toLowerCase());
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PopupMenuButton<int>(
                        tooltip: 'Filtrar por loja',
                        onSelected: (index) => setState(() {
                          _filter = index < 0
                              ? null
                              : GamePlatform.values[index];
                          _onlyFreeHub = false;
                        }),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: -1,
                            child: Text('Todas as lojas'),
                          ),
                          for (final store in _prefs.orderedPlatforms)
                            PopupMenuItem(
                              value: store.index,
                              child: Text(store.label),
                            ),
                        ],
                        child: Chip(
                          label: Text(_filter?.shortLabel ?? 'Todas as lojas'),
                          avatar: const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Filtros de oferta',
                        onSelected: (tag) => setState(() {
                          _activeSearchTag = tag.isEmpty ? null : tag;
                        }),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '',
                            child: Text('Sem filtro rápido'),
                          ),
                          for (final tag in _quickSearchTags)
                            PopupMenuItem(
                              value: tag.id,
                              child: Tooltip(
                                message: tag.hint,
                                child: Text(tag.label),
                              ),
                            ),
                        ],
                        child: Chip(
                          label: Text(
                            _quickSearchTags
                                    .where((tag) => tag.id == _activeSearchTag)
                                    .firstOrNull
                                    ?.label ??
                                'Filtros de oferta',
                          ),
                          avatar: const Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                          ),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Grátis da semana'),
                        selected: _onlyFreeHub,
                        onSelected: (value) => setState(() {
                          _onlyFreeHub = value;
                          if (value) _filter = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
            padding: EdgeInsets.symmetric(horizontal: gutter),
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
                    deals.length < available.length || _api.hasMoreFor(_filter)
                        ? 'Toque em "Mostrar mais promoções" para carregar mais ofertas das lojas selecionadas.'
                        : 'Todas as ofertas disponíveis para esta seleção foram carregadas.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
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

/// Mount each section at first use and keep its scroll and form state afterward.
class _LazySections extends StatefulWidget {
  const _LazySections({required this.index, required this.pages});

  final int index;
  final List<Widget Function()> pages;

  @override
  State<_LazySections> createState() => _LazySectionsState();
}

class _LazySectionsState extends State<_LazySections> {
  final _visited = <int>{};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.pages.length; i++)
          if (_visited.contains(i))
            TickerMode(enabled: i == widget.index, child: widget.pages[i]())
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
