import 'package:flutter/material.dart';

import '../../services/bluetooth_devices.dart';
import '../../services/notification.dart';

class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const WelcomeDialog(),
    );
  }

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  bool _enableNotifications = true;
  bool _enableBluetooth = true;
  bool _isRequesting = false;

  Future<void> _handleStart(bool withPermissions) async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    var notificationsGranted = false;
    if (withPermissions) {
      if (_enableNotifications) {
        try {
          notificationsGranted =
              await NotificationService.instance.requestPermission();
        } catch (_) {}
      }
      if (_enableBluetooth && BluetoothDevices.supported) {
        try {
          await BluetoothDevices.requestPermission();
        } catch (_) {}
      }
    }

    if (mounted) {
      Navigator.of(context).pop(notificationsGranted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: isCompact ? 20 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF12171F)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: c.outlineVariant.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 20 : 32,
                        isCompact ? 24 : 32,
                        isCompact ? 20 : 32,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: App Logo + Badges
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: c.primary.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/branding/app_icon.png',
                                    cacheWidth: 150,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'ludivex',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.7,
                                            color: c.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: c.primary.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'NOVO',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: c.primary,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'ALL YOUR GAMES. ONE PLACE.',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: c.onSurfaceVariant.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Welcome message
                          Text(
                            'Seu espaço definitivo para jogar mais e economizar.',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              fontSize: isCompact ? 19 : 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Descubra tudo o que o Ludivex faz por você:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: c.onSurfaceVariant,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Core Feature Highlights
                          const _FeatureHighlight(
                            icon: Icons.storefront_rounded,
                            iconColor: Color(0xFF3988FF),
                            title: 'Todas as Lojas Reunidas',
                            description:
                                'Acompanhe promoções em tempo real da Steam, PlayStation, Xbox, Epic Games e Nuuvem em um catálogo unificado.',
                          ),
                          const SizedBox(height: 12),
                          const _FeatureHighlight(
                            icon: Icons.notifications_active_rounded,
                            iconColor: Color(0xFF45C96B),
                            title: 'Lista de Desejos com Alerta de Preço',
                            description:
                                'Defina preços-alvo para seus jogos dos sonhos e receba notificações imediatas quando o preço cair ou abrir uma nova promoção.',
                          ),
                          const SizedBox(height: 12),
                          const _FeatureHighlight(
                            icon: Icons.sports_esports_rounded,
                            iconColor: Color(0xFFAD94FF),
                            title: 'Setup & Dispositivos Bluetooth',
                            description:
                                'Monitore bateria e novidades de firmware de controles (Xbox, DualSense, 8BitDo) e fones sem fio pareados.',
                          ),

                          const SizedBox(height: 22),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: c.outlineVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),

                          // Permissions interactive choices
                          Text(
                            'PERMISSÕES RECOMENDADAS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: c.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 10),

                          _PermissionToggle(
                            icon: Icons.notifications_rounded,
                            title: 'Notificações de Promoções',
                            subtitle:
                                'Avisos quando um jogo da sua lista entrar em oferta ou uma nova promoção imperdível abrir.',
                            value: _enableNotifications,
                            onChanged: (val) =>
                                setState(() => _enableNotifications = val),
                          ),
                          if (BluetoothDevices.supported) ...[
                            const SizedBox(height: 8),
                            _PermissionToggle(
                              icon: Icons.bluetooth_searching_rounded,
                              title: 'Acesso a Dispositivos Bluetooth',
                              subtitle:
                                  'Permite detectar controles e fones para exibir bateria e firmwares.',
                              value: _enableBluetooth,
                              onChanged: (val) =>
                                  setState(() => _enableBluetooth = val),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 20 : 32,
                      14,
                      isCompact ? 20 : 32,
                      isCompact ? 20 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerLowest.withValues(alpha: 0.7),
                      border: Border(
                        top: BorderSide(
                          color: c.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: c.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isRequesting
                              ? null
                              : () => _handleStart(
                                    _enableNotifications || _enableBluetooth,
                                  ),
                          icon: _isRequesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: Text(
                            _isRequesting
                                ? 'Configurando...'
                                : 'Permitir e Começar a Jogar',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: c.onSurfaceVariant,
                              ),
                              onPressed: _isRequesting
                                  ? null
                                  : () => _handleStart(false),
                              child: const Text(
                                'Agora não, entrar direto',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 13,
                                  color: c.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '100% privado • Dados locais',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: c.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  const _FeatureHighlight({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title, description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Material(
      color: value
          ? c.primary.withValues(alpha: 0.08)
          : c.surfaceContainerHighest.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? c.primary.withValues(alpha: 0.25)
                  : c.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: value ? c.primary : c.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: value ? c.onSurface : c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeTrackColor: c.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
