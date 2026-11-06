import 'package:flutter/material.dart';

/// Shared geometry keeps discovery and campaign cards consistent at any width.
abstract final class DealGrid {
  static SliverGridDelegateWithFixedCrossAxisCount delegate(
    double width,
    double textScale, {
    bool compact = false,
  }) {
    const gap = 16.0;
    final minWidth = textScale > 1.3
        ? 340.0
        : compact
        ? 220.0
        : 260.0;
    final columns = ((width + gap) / (minWidth + gap)).floor().clamp(
      1,
      compact ? 8 : 6,
    );
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: gap,
      mainAxisSpacing: gap,
      mainAxisExtent: (compact ? 322 : 426) + (textScale - 1).clamp(0, 4) * 170,
    );
  }
}
