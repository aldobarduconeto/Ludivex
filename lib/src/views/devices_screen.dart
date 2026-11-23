import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/gaming_device.dart';
import '../services/bluetooth_devices.dart';
import '../services/device_service.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({
    super.key,
    required this.service,
    this.active = true,
    this.showTitle = true,
    this.onAppearance,
  });
  final DeviceService service;
  final bool active;
  final bool showTitle;
  final VoidCallback? onAppearance;
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with WidgetsBindingObserver {
  final _reading = <String>{};
  GamingDeviceKind? _filter;
  bool _isRefreshingAll = false;
  Timer? _batteryRefresh;
  DeviceService get service => widget.service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncBatteryRefresh();
  }

  @override
  void didUpdateWidget(covariant DevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncBatteryRefresh();
  }

  void _syncBatteryRefresh() {
    _batteryRefresh?.cancel();
    if (!(BluetoothDevices.windows ||
            BluetoothDevices.linux ||
            BluetoothDevices.android) ||
        !widget.active)
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshBattery());
    });
    _batteryRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshBattery());
    });
  }

  Future<void> _refreshBattery() async {
    if (BluetoothDevices.android &&
        !await BluetoothDevices.hasAndroidPermission()) {
      return;
    }
    if (mounted && widget.active) await _scan();
  }

  @override
  void dispose() {
    _batteryRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _scan() async {
    if (service.scanning) return;
    await service.refresh();
  }

  Future<void> _refreshAll() async {
    if (_isRefreshingAll || service.scanning) return;
    setState(() => _isRefreshingAll = true);
    try {
      if (BluetoothDevices.supported) {
        await service.refresh();
      }
      if (mounted) {
        if (service.error != null) {
          _message(service.error!);
        } else {
          _message('Dispositivos atualizados com sucesso.');
        }
      }
    } catch (_) {
      if (mounted) _message('Não foi possível atualizar os dados.');
    } finally {
      if (mounted) setState(() => _isRefreshingAll = false);
    }
  }

  Future<void> _refreshDevice(GamingDevice device) async {
    if (BluetoothDevices.canReadDetails(device)) {
      await _read(device);
      return;
    }
    await _refreshAll();
  }

  Future<void> _read(GamingDevice device) async {
    if (_reading.contains(device.id)) return;
    setState(() => _reading.add(device.id));
    try {
      await service.readDetails(device);
      _message('Dados de ${device.name} atualizados.');
    } catch (e) {
      _message('Não foi possível ler os dados completos de ${device.name}.');
    } finally {
      if (mounted) setState(() => _reading.remove(device.id));
    }
  }

  Future<void> _edit([GamingDevice? device]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DeviceDialog(service: service, device: device),
    );
    if (result == true && mounted) {
      _message(
        device == null
            ? 'Dispositivo adicionado.'
            : 'Dados do dispositivo salvos.',
      );
    }
  }

  Future<void> _remove(GamingDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover dispositivo?'),
        content: Text(
          'Deseja remover "${device.name}" da lista? Dispositivos detectados pelo sistema podem reaparecer na próxima busca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.remove(device.id);
      _message('Dispositivo removido.');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final theme = Theme.of(context);
      final devices = service.devices
          .where((d) => _filter == null || d.kind == _filter)
          .toList();
      final busy = service.scanning || _isRefreshingAll;
      return LayoutBuilder(
        builder: (context, viewport) {
          final gutter = viewport.maxWidth < 600 ? 16.0 : 24.0;
          final scale = MediaQuery.textScalerOf(context)
              .scale(1)
              .clamp(1.0, 3.0);
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.onAppearance != null)
                IconButton.outlined(
                  tooltip: 'Tema e cor de destaque',
                  onPressed: widget.onAppearance,
                  icon: const Icon(Icons.palette_outlined),
                ),
              OutlinedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar'),
              ),
              if (BluetoothDevices.supported)
                FilledButton.tonalIcon(
                  onPressed: busy ? null : _scan,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(busy ? 'Buscando…' : 'Buscar dispositivos'),
                ),
            ],
          );
          final title = Text(
            'Dispositivos',
            style: theme.textTheme.headlineMedium,
          );
          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.showTitle)
                          actions
                        else if (viewport.maxWidth >= 740 * scale)
                          Row(
                            children: [
                              Expanded(child: title),
                              actions,
                            ],
                          )
                        else ...[
                          title,
                          const SizedBox(height: 12),
                          actions,
                        ],
                        if (busy) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                        if (service.error case final error?) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        if (service.devices.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final (kind, label) in const [
                                (null, 'Todos'),
                                (GamingDeviceKind.controller, 'Controles'),
                                (GamingDeviceKind.headset, 'Fones'),
                                (GamingDeviceKind.other, 'Outros'),
                              ])
                                ChoiceChip(
                                  label: Text(label),
                                  selected: _filter == kind,
                                  onSelected: (selected) => setState(
                                    () => _filter = selected ? kind : null,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (devices.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(gutter),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.devices_other_outlined,
                                color: theme.colorScheme.primary,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                busy
                                    ? 'Buscando dispositivos'
                                    : _filter == null
                                    ? 'Nenhum dispositivo'
                                    : 'Nenhum dispositivo neste filtro',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (_filter == null && !busy) ...[
                                const SizedBox(height: 8),
                                Text(
                                  BluetoothDevices.supported
                                      ? BluetoothDevices.listingDescription
                                      : 'Use Adicionar para cadastrar um periférico.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 12.0;
                        final minWidth = scale > 1.4 ? 380 : 264;
                        final columns =
                            ((constraints.crossAxisExtent + gap) /
                                    (minWidth + gap))
                                .floor();
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns < 1 ? 1 : columns,
                                mainAxisExtent: 132 + (scale - 1) * 60,
                                mainAxisSpacing: gap,
                                crossAxisSpacing: gap,
                              ),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return DeviceCard(
                              key: ValueKey(device.id),
                              device: device,
                              found: service.found.contains(device.id),
                              reading: _reading.contains(device.id),
                              onEdit: () => _edit(device),
                              onRemove: () => _remove(device),
                              onRefresh: () => _refreshDevice(device),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

enum _DeviceAction { details, refresh, edit, remove }

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.found,
    required this.reading,
    required this.onEdit,
    required this.onRemove,
    required this.onRefresh,
  });

  final GamingDevice device;
  final bool found, reading;
  final VoidCallback onEdit, onRemove, onRefresh;

  void _showDetails(BuildContext context) {
    final date = DateFormat('dd/MM HH:mm').format(device.seenAt.toLocal());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Detalhes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(device.displayModel),
            Text(device.displayManufacturer),
            if (device.firmware case final firmware?)
              Text('Firmware $firmware'),
            Text('Último registro em $date'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final battery = device.battery;
    final level = device.batteryLevel;
    final low =
        (battery != null && battery <= 20) ||
        level == DeviceBatteryLevel.empty ||
        level == DeviceBatteryLevel.low;
    final batteryColor = low ? colors.error : colors.primary;
    final status = device.manual
        ? 'Manual'
        : found
        ? 'Detectado'
        : 'Salvo';
    final canRead = BluetoothDevices.canReadDetails(device);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (device.kind) {
                    GamingDeviceKind.controller =>
                      Icons.sports_esports_outlined,
                    GamingDeviceKind.headset => Icons.headphones_outlined,
                    GamingDeviceKind.other => Icons.devices_other_outlined,
                  },
                  size: 21,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${device.kind.label} · $status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_DeviceAction>(
                  tooltip: 'Opções de ${device.name}',
                  onSelected: (action) => switch (action) {
                    _DeviceAction.details => _showDetails(context),
                    _DeviceAction.refresh => onRefresh(),
                    _DeviceAction.edit => onEdit(),
                    _DeviceAction.remove => onRemove(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _DeviceAction.details,
                      child: Text('Detalhes'),
                    ),
                    if (canRead || BluetoothDevices.supported)
                      PopupMenuItem(
                        value: _DeviceAction.refresh,
                        enabled: !reading,
                        child: Text(
                          canRead ? 'Ler dados Bluetooth' : 'Atualizar dados',
                        ),
                      ),
                    const PopupMenuItem(
                      value: _DeviceAction.edit,
                      child: Text('Editar dados'),
                    ),
                    const PopupMenuItem(
                      value: _DeviceAction.remove,
                      child: Text('Remover'),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                children: [
                  Icon(
                    low
                        ? Icons.battery_alert_rounded
                        : battery == null && level == null
                        ? Icons.battery_unknown_rounded
                        : Icons.battery_std_rounded,
                    size: 18,
                    color: battery == null && level == null
                        ? colors.onSurfaceVariant
                        : batteryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reading
                          ? 'Lendo bateria…'
                          : battery != null
                          ? '$battery% de bateria'
                          : level != null
                          ? 'Bateria ${level.label.toLowerCase()}'
                          : 'Bateria indisponível',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: low ? colors.error : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (battery != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: LinearProgressIndicator(
                  value: battery / 100,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                  color: batteryColor,
                  backgroundColor: colors.surfaceContainerHighest,
                  semanticsLabel: 'Carga da bateria',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog({required this.service, this.device});
  final DeviceService service;
  final GamingDevice? device;
  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.device?.name);
  late final _model = TextEditingController(text: widget.device?.model);
  late final _manufacturer = TextEditingController(
    text: widget.device?.manufacturer,
  );
  late final _firmware = TextEditingController(text: widget.device?.firmware);
  late GamingDeviceKind _kind =
      widget.device?.kind ?? GamingDeviceKind.controller;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _model.dispose();
    _manufacturer.dispose();
    _firmware.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.service.save(
        GamingDevice(
          id:
              widget.device?.id ??
              'manual:${DateTime.now().microsecondsSinceEpoch}',
          name: _name.text.trim(),
          manufacturer: _manufacturer.text.trim(),
          model: _model.text.trim().isEmpty ? null : _model.text.trim(),
          kind: _kind,
          firmware: _firmware.text.trim().isEmpty
              ? null
              : _firmware.text.trim(),
          battery: widget.device?.battery,
          batteryLevel: widget.device?.batteryLevel,
          gattReadable: widget.device?.gattReadable ?? false,
          manual: true,
          seenAt: DateTime.now().toUtc(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Tente novamente.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        widget.device == null ? 'Adicionar dispositivo' : 'Editar dispositivo',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Nome do dispositivo',
                    helperText:
                        'Ex.: Xbox Wireless Controller, DualSense, Buds Core.',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe o nome do dispositivo.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _model,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Modelo (opcional)',
                    helperText: 'Ex.: Model 1914, CFI-ZCT1W, SM-R400N, etc.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<GamingDeviceKind>(
                  initialValue: _kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: GamingDeviceKind.values
                      .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k.label)),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _kind = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _manufacturer,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Fabricante (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firmware,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Firmware atual (opcional)',
                    helperText: 'Copie a versão exibida no aplicativo oficial.',
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando…' : 'Salvar dispositivo'),
        ),
      ],
    ),
  );
}
