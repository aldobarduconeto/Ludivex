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
    this.activeStore,
  });

  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final ValueChanged<GamePlatform> onStore;
  final List<GamePlatform> stores;
  final GamePlatform? activeStore;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const navigation = [
      (0, Icons.explore_outlined, 'Descobrir'),
      (1, Icons.favorite_outline_rounded, 'Lista de desejos'),
      (3, Icons.sports_esports_outlined, 'Biblioteca'),
      (newsTabIndex, Icons.newspaper_outlined, 'Notícias'),
      (devicesTabIndex, Icons.devices_other_outlined, 'Dispositivos'),
      (2, Icons.tune_rounded, 'Configurações'),
    ];
    return SizedBox(
      width: 210,
      child: Material(
        color: colors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              end: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 8, 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/branding/app_icon.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ludivex',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (index, icon, label) in navigation)
                  ListTile(
                    dense: true,
                    selected: selectedIndex == index,
                    selectedTileColor: colors.primaryContainer,
                    selectedColor: colors.onPrimaryContainer,
                    leading: Icon(icon, size: 20),
                    title: Text(label),
                    onTap: () => onNavigate(index),
                  ),
                const Divider(height: 24),
                if (stores.isNotEmpty)
                  ExpansionTile(
                    key: const PageStorageKey('sidebar-stores'),
                    initiallyExpanded: activeStore != null,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: const Icon(Icons.storefront_outlined, size: 20),
                    title: const Text('Lojas'),
                    children: [
                      for (final store in stores)
                        ListTile(
                          dense: true,
                          selected: selectedIndex == 0 && activeStore == store,
                          selectedTileColor: colors.primaryContainer,
                          selectedColor: colors.onPrimaryContainer,
                          leading: Icon(store.icon, size: 18),
                          title: Text(store.label),
                          onTap: () => onStore(store),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Adicionar jogo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
