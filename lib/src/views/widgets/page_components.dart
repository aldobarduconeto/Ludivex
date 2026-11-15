import 'package:flutter/material.dart';

/// Consistent collection search with a keyboard action and an accessible reset.
class CollectionSearchField extends StatelessWidget {
  const CollectionSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textInputAction: TextInputAction.search,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => value.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    ),
  );
}

/// Responsive page introductions shared by the library, wishlist and settings.
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actions = const [],
    this.metrics = const [],
  });
  final String title, description;
  final IconData icon;
  final List<Widget> actions, metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = theme.colorScheme;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 22, color: c.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineActions =
            actions.isNotEmpty &&
            constraints.maxWidth >= 840 &&
            MediaQuery.textScalerOf(context).scale(16) <= 20;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(constraints.maxWidth < 480 ? 14 : 20),
          decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outlineVariant.withValues(alpha: .65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inlineActions)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: heading),
                    const SizedBox(width: 16),
                    Flexible(flex: 2, child: controls),
                  ],
                )
              else
                heading,
              if (metrics.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: metrics),
              ],
              if (!inlineActions && actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                controls,
              ],
            ],
          ),
        );
      },
    );
  }
}

class MetricPill extends StatelessWidget {
  const MetricPill({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title, description;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: c.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant, height: 1.5),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 18 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: c.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
