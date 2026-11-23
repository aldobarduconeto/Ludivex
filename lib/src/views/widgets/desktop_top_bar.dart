import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get hasDesktopTopBar =>
    !kIsWeb &&
    const [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);

class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({
    super.key,
    required this.child,
    required this.onStores,
    required this.onRefresh,
    required this.onRandomGame,
  });

  final Widget child;
  final VoidCallback? onStores, onRefresh, onRandomGame;
  static const _window = MethodChannel('ludivex/window');

  Future<void> _windowAction(String method) async {
    await _window.invokeMethod<void>(method);
  }

  Widget _button(String label, IconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: label,
        icon: Icon(icon, size: 19),
        onPressed: onPressed,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Overlay.wrap(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Material(
                color: colors.surface,
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () => _windowAction('maximize'),
                          onPanStart: (_) => _windowAction('drag'),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/branding/app_icon.png',
                                  width: 24,
                                  height: 24,
                                  cacheWidth: 72,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Ludivex',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _button(
                        'Lojas e compatibilidade',
                        Icons.storefront_outlined,
                        onStores,
                      ),
                      _button(
                        'Sortear jogo da biblioteca',
                        Icons.casino_outlined,
                        onRandomGame,
                      ),
                      _button(
                        'Atualizar ofertas',
                        Icons.sync_rounded,
                        onRefresh,
                      ),
                      const SizedBox(width: 6),
                      const SizedBox(
                        height: 24,
                        child: VerticalDivider(width: 1),
                      ),
                      _button(
                        'Minimizar janela',
                        Icons.remove,
                        () => _windowAction('minimize'),
                      ),
                      _button(
                        'Maximizar ou restaurar janela',
                        Icons.crop_square,
                        () => _windowAction('maximize'),
                      ),
                      _button(
                        'Fechar janela',
                        Icons.close,
                        () => _windowAction('close'),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: child),
            ],
          ),
          if (defaultTargetPlatform == TargetPlatform.linux) ...[
            _edge(
              1,
              SystemMouseCursors.resizeUp,
              top: 0,
              left: 6,
              right: 6,
              height: 4,
            ),
            _edge(
              6,
              SystemMouseCursors.resizeDown,
              bottom: 0,
              left: 6,
              right: 6,
              height: 4,
            ),
            _edge(
              3,
              SystemMouseCursors.resizeLeft,
              left: 0,
              top: 6,
              bottom: 6,
              width: 4,
            ),
            _edge(
              4,
              SystemMouseCursors.resizeRight,
              right: 0,
              top: 6,
              bottom: 6,
              width: 4,
            ),
            _edge(
              0,
              SystemMouseCursors.resizeUpLeft,
              top: 0,
              left: 0,
              width: 6,
              height: 6,
            ),
            _edge(
              2,
              SystemMouseCursors.resizeUpRight,
              top: 0,
              right: 0,
              width: 6,
              height: 6,
            ),
            _edge(
              5,
              SystemMouseCursors.resizeDownLeft,
              bottom: 0,
              left: 0,
              width: 6,
              height: 6,
            ),
            _edge(
              7,
              SystemMouseCursors.resizeDownRight,
              bottom: 0,
              right: 0,
              width: 6,
              height: 6,
            ),
          ],
        ],
      ),
    );
  }

  Widget _edge(
    int edge,
    MouseCursor cursor, {
    double? left,
    top,
    right,
    bottom,
    width,
    height,
  }) => Positioned(
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    width: width,
    height: height,
    child: MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons == kPrimaryMouseButton)
            _windowAction('resize$edge');
        },
      ),
    ),
  );
}
