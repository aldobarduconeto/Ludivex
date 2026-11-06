import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/gaming_device.dart';
import '../services/bluetooth_devices.dart';
import '../services/device_service.dart';
import 'widgets/page_components.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key, required this.service, this.active = true});
  final DeviceService service;
  final bool active;
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with WidgetsBindingObserver {
  final _reading = <String>{};
  GamingDeviceKind? _filter;
  bool _isRefreshingAll = false;
  DeviceService get service => widget.service;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
    if (BluetoothDevices.android && device.gattReadable) {
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
      final devices = service.devices
          .where((d) => _filter == null || d.kind == _filter)
          .toList();
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
      return RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageIntro(
                      eyebrow: 'SEU SETUP',
                      title: 'Prontos para a próxima partida.',
                      description: 'Controles e fones Bluetooth, modelo e bateria em um só lugar.',
                      icon: Icons.devices_other_rounded,
                      metrics: [
                        MetricPill(
                          icon: Icons.sports_esports_outlined,
                          label: '${service.devices.length} dispositivos',
                        ),
                      ],
                      actions: [
                        if (BluetoothDevices.supported)
                          FilledButton.icon(
                            onPressed: service.scanning ? null : _scan,
                            icon: service.scanning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.bluetooth_searching_rounded),
                            label: Text(
                              service.scanning
                                  ? 'Buscando…'
                                  : 'Buscar dispositivos',
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Adicionar dispositivo'),
                        ),
                        IconButton.outlined(
                          tooltip: 'Atualizar dados e conexões',
                          icon: _isRefreshingAll
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          onPressed: (_isRefreshingAll || service.scanning)
                              ? null
                              : _refreshAll,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      BluetoothDevices.listingDescription,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (service.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          service.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: _filter == null,
                            onSelected: (_) => setState(() => _filter = null),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Controles'),
                            selected: _filter == GamingDeviceKind.controller,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? GamingDeviceKind.controller
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Fones'),
                            selected: _filter == GamingDeviceKind.headset,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? GamingDeviceKind.headset
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Outros'),
                            selected: _filter == GamingDeviceKind.other,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? GamingDeviceKind.other
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (devices.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: AppEmptyState(
                    icon: Icons.bluetooth_rounded,
                    title: 'Seu setup começa aqui.',
                    description: 'Pareie o controle ou fone nas configurações Bluetooth do sistema e busque novamente. Também é possível cadastrar um dispositivo manualmente.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) => SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          (constraints.crossAxisExtent /
                                  (scale > 1.3 ? 380 : 300))
                              .floor()
                              .clamp(1, 4),
                      mainAxisExtent: 185 + (scale - 1) * 90,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                    ),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return DeviceCard(
                        device: device,
                        found: service.found.contains(device.id),
                        reading: _reading.contains(device.id),
                        onRead: () => _read(device),
                        onEdit: () => _edit(device),
                        onRemove: () => _remove(device),
                        onRefresh: () => _refreshDevice(device),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.found,
    required this.reading,
    required this.onRead,
    required this.onEdit,
    required this.onRemove,
    this.onRefresh,
  });
  final GamingDevice device;
  final bool found, reading;
  final VoidCallback onRead, onEdit, onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: c.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: c.primary.withValues(alpha: 0.12),
                  foregroundColor: c.primary,
                  child: Icon(
                    device.kind == GamingDeviceKind.controller
                        ? Icons.sports_esports_rounded
                        : device.kind == GamingDeviceKind.headset
                            ? Icons.headphones_rounded
                            : Icons.bluetooth_rounded,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              device.displayManufacturer,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: c.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              device.manual
                                  ? 'Manual'
                                  : found
                                      ? 'Conectado agora'
                                      : 'Salvo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Atualizar dados de ${device.name}',
                    icon: reading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    onPressed: reading ? null : onRefresh,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Opções de ${device.name}',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'remove') onRemove();
                    if (value == 'read') onRead();
                  },
                  itemBuilder: (_) => [
                    if (BluetoothDevices.android && device.gattReadable)
                      const PopupMenuItem(
                        value: 'read',
                        child: Text('Ler dados Bluetooth'),
                      ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar dados')),
                    const PopupMenuItem(value: 'remove', child: Text('Remover')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),

            // Model Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
              decoration: BoxDecoration(
                color: c.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Icon(Icons.devices_rounded, size: 13, color: c.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Modelo: ${device.displayModel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Battery Display with Progress Bar
            Row(
              children: [
                Icon(
                  device.battery == null
                      ? Icons.battery_unknown_rounded
                      : device.battery! <= 20
                          ? Icons.battery_alert_rounded
                          : device.battery! <= 50
                              ? Icons.battery_4_bar_rounded
                              : Icons.battery_full_rounded,
                  color: device.battery == null
                      ? c.onSurfaceVariant
                      : device.battery! <= 20
                          ? Colors.redAccent
                          : device.battery! <= 50
                              ? Colors.amber
                              : const Color(0xFF20B969),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            device.battery == null
                                ? 'Bateria não informada'
                                : '${device.battery}% de bateria',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: device.battery == null
                                  ? c.onSurfaceVariant
                                  : device.battery! <= 20
                                      ? Colors.redAccent
                                      : c.onSurface,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (device.battery != null)
                            Text(
                              device.battery! <= 20
                                  ? 'Fraca'
                                  : device.battery! <= 50
                                      ? 'Média'
                                      : 'Boa',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: device.battery! <= 20
                                    ? Colors.redAccent
                                    : device.battery! <= 50
                                        ? Colors.amber
                                        : const Color(0xFF20B969),
                              ),
                            ),
                        ],
                      ),
                      if (device.battery != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: device.battery!.clamp(0, 100) / 100.0,
                            minHeight: 4.5,
                            backgroundColor:
                                c.outlineVariant.withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              device.battery! <= 20
                                  ? Colors.redAccent
                                  : device.battery! <= 50
                                      ? Colors.amber
                                      : const Color(0xFF20B969),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (device.firmware != null && device.firmware!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.memory_rounded,
                    size: 13,
                    color: c.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Firmware: ${device.firmware}',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // Footer: Timestamp + Actions
            Row(
              children: [
                Text(
                  'Registro: ${DateFormat('dd/MM HH:mm').format(device.seenAt.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: c.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (BluetoothDevices.android && device.gattReadable) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: reading ? null : onRead,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        reading ? 'Lendo…' : 'Ler dados',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(
                            k.label,
                          ),
                        ),
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
