import 'package:flutter/material.dart';

import '../../models/platform.dart';
import 'app_navigation.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    required this.stores,
    required this.onStore,
    required this.onAdd,
    required this.wishlistCount,
    this.activeStore,
    this.offerCount = 0,
  });
  final int selectedIndex, wishlistCount, offerCount;
  final ValueChanged<int> onNavigate;
  final ValueChanged<GamePlatform> onStore;
  final List<GamePlatform> stores;
  final GamePlatform? activeStore;
  final VoidCallback onAdd;

  Widget _nav(
    BuildContext context,
    int index,
    IconData icon,
    String title, {
    String? count,
  }) {
    final c = Theme.of(context).colorScheme;
    final selected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? c.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onNavigate(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? c.primary.withValues(alpha: 0.22)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (selected)
                  Container(
                    width: 3.5,
                    height: 16,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(width: 3.5, height: 16),
                Icon(
                  icon,
                  size: 19,
                  color: selected ? c.primary : c.onSurfaceVariant,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.onSurface : c.onSurfaceVariant,
                    ),
                  ),
                ),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.primary.withValues(alpha: 0.20)
                          : c.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? c.primary : c.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeItem(BuildContext context, GamePlatform store) {
    final c = Theme.of(context).colorScheme;
    final selected = selectedIndex == 0 && activeStore == store;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? store.tint.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onStore(store),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? store.tint.withValues(alpha: 0.25)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: store.tint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    store.icon,
                    size: 14,
                    color: store.tint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    store.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? c.onSurface : c.onSurfaceVariant,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: store.tint,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final isOled =
        dark && theme.scaffoldBackgroundColor == const Color(0xFF000000);
    return SizedBox(
      width: 256,
      child: Material(
        color: isOled
            ? const Color(0xFF000000)
            : (dark ? const Color(0xFF10141A) : Colors.white),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isOled
                    ? const Color(0xFF22262E)
                    : c.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: c.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        padding: const EdgeInsets.all(5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/branding/app_icon.png',
                            cacheWidth: 114,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ludivex',
                              style: TextStyle(
                                fontSize: 20,
                                letterSpacing: -.7,
                                fontWeight: FontWeight.w800,
                                color: c.onSurface,
                              ),
                            ),
                            Text(
                              'ALL YOUR GAMES. ONE PLACE.',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: .4,
                                fontWeight: FontWeight.w700,
                                color: c.onSurfaceVariant.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _nav(
                        context,
                        0,
                        Icons.explore_outlined,
                        'Descobrir',
                        count: '$offerCount',
                      ),
                      _nav(
                        context,
                        1,
                        Icons.favorite_outline_rounded,
                        'Lista de desejos',
                        count: '$wishlistCount',
                      ),
                      _nav(
                        context,
                        3,
                        Icons.sports_esports_outlined,
                        'Biblioteca',
                      ),
                      _nav(
                        context,
                        newsTabIndex,
                        Icons.newspaper_outlined,
                        'Notícias',
                      ),
                      _nav(
                        context,
                        devicesTabIndex,
                        Icons.devices_other_outlined,
                        'Dispositivos',
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 16,
                        thickness: 0.5,
                        color: c.outlineVariant.withValues(alpha: 0.25),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Row(
                          children: [
                            Text(
                              'SUAS LOJAS',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                                color: c.onSurfaceVariant.withValues(alpha: 0.65),
                              ),
                            ),
                            const Spacer(),
                            if (stores.isNotEmpty)
                              Text(
                                '${stores.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: c.onSurfaceVariant.withValues(alpha: 0.45),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final store in stores) _storeItem(context, store),
                      if (stores.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Escolha suas lojas nas configurações.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 16,
                        thickness: 0.5,
                        color: c.outlineVariant.withValues(alpha: 0.25),
                      ),
                      _nav(context, 2, Icons.tune_rounded, 'Configurações'),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: c.outlineVariant.withValues(alpha: 0.25),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: c.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Adicionar jogo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceContainerLowest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: c.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sua lista. No seu dispositivo.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: c.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
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
        ),
      ),
    );
  }
}
