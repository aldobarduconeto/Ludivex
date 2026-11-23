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

/// A page heading with actions that wrap on narrow layouts.
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    this.description = '',
    this.actions = const [],
    this.metrics = const [],
  });

  final String title, description;
  final List<Widget> actions, metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title, style: theme.textTheme.headlineMedium),
        if (description.isNotEmpty)
          Text(description, style: theme.textTheme.bodySmall),
        if (metrics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 12, runSpacing: 4, children: metrics),
          ),
      ],
    );
    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) return heading;
          final inlineActions =
              constraints.maxWidth >= 760 &&
              MediaQuery.textScalerOf(context).scale(16) <= 20;
          if (inlineActions) {
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: controls,
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 8), controls],
          );
        },
      ),
    );
  }
}

/// A scrolling collection with naturally sized cards and more columns when space allows.
class AdaptiveCollection extends StatelessWidget {
  const AdaptiveCollection({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    this.padding,
    this.physics,
    this.minColumnWidth = 390,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
      final usableWidth = constraints.maxWidth - (padding?.horizontal ?? 0);
      final fitted = ((usableWidth + gap) / (minColumnWidth * scale + gap))
          .floor();
      final columns = fitted < 1 ? 1 : fitted;
      final headerRows = header == null ? 0 : 1;
      return ListView.builder(
        padding: padding,
        physics: physics,
        itemCount: (itemCount + columns - 1) ~/ columns + headerRows,
        itemBuilder: (context, row) {
          if (row < headerRows) return header!;
          final first = (row - headerRows) * columns;
          if (columns == 1) return itemBuilder(context, first);
          final width = (usableWidth - (columns - 1) * gap) / columns;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var offset = 0;
                offset < columns && first + offset < itemCount;
                offset++
              ) ...[
                if (offset > 0) const SizedBox(width: gap),
                SizedBox(
                  width: width,
                  child: itemBuilder(context, first + offset),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}

class MetricPill extends StatelessWidget {
  const MetricPill({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: c.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.onSurfaceVariant, height: 1.4),
              ),
            ],
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
