import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import '../../core/bluetooth/bluetooth_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/widgets/widgets.dart';

class BluetoothDebugPage extends StatefulWidget {
  const BluetoothDebugPage({super.key});

  @override
  State<BluetoothDebugPage> createState() => _BluetoothDebugPageState();
}

class _BluetoothDebugPageState extends State<BluetoothDebugPage> {
  final _bluetoothService = getIt<BluetoothService>();
  bool _isScanning = false;
  List<ble.ScanResult> _scanResults = [];
  bool _onlyConnectable = false;
  
  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await _bluetoothService.init();
  }

  void _toggleScan() async {
    if (_isScanning) {
      await _bluetoothService.stopScan();
      setState(() => _isScanning = false);
    } else {
      setState(() {
        _scanResults.clear();
        _isScanning = true;
      });
      _bluetoothService.scan(timeout: const Duration(seconds: 15)).listen(
        (result) {
          if (!mounted) return;
          setState(() {
            final index = _scanResults.indexWhere((r) => r.device.remoteId == result.device.remoteId);
            if (index >= 0) {
              _scanResults[index] = result;
            } else {
              _scanResults.add(result);
              _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
            }
          });
        },
        onDone: () => setState(() => _isScanning = false),
        onError: (e) => setState(() => _isScanning = false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleDevices = _onlyConnectable
        ? _scanResults.where((item) => item.advertisementData.connectable).toList()
        : _scanResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('蓝牙调试工具'),
        actions: [
          if (_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(colorScheme, theme),
          Expanded(
            child: visibleDevices.isEmpty
                ? const EmptyState(
                    icon: Icons.bluetooth_searching_rounded,
                    title: '未发现设备',
                    subtitle: '点击下方按钮开始扫描周边的蓝牙 BLE 设备',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                    itemCount: visibleDevices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildDeviceCard(visibleDevices[index], colorScheme, theme),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_isScanning ? Icons.stop_rounded : Icons.search_rounded),
        label: Text(_isScanning ? '停止扫描' : '开始扫描'),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme) {
    final connectableCount = _scanResults.where((result) => result.advertisementData.connectable).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.bug_report_rounded, size: 16, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('设备列表', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('共 ${_scanResults.length} 台，支持连接 $connectableCount 台', style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: () => BluetoothPickerSheet.show(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                tooltip: '测试组件版',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('仅可连接设备'),
                selected: _onlyConnectable,
                onSelected: (value) => setState(() => _onlyConnectable = value),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                _isScanning ? '扫描中' : '空闲',
                _isScanning ? Icons.radar_rounded : Icons.check_circle_outline_rounded,
                _isScanning ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ble.ScanResult result, ColorScheme colorScheme, ThemeData theme) {
    final device = result.device;
    final name = device.platformName.isEmpty ? '未知设备' : device.platformName;

    return ModernCard(
      onTap: () => _showDeviceDetails(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildSignalIndicator(result.rssi, colorScheme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.remoteId.str,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: result.advertisementData.connectable
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.advertisementData.connectable ? '可连接' : '仅广播',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: result.advertisementData.connectable
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalIndicator(int rssi, ColorScheme colorScheme) {
    IconData icon;
    Color color;
    if (rssi > -60) {
      icon = Icons.signal_cellular_alt_rounded;
      color = Colors.green;
    } else if (rssi > -80) {
      icon = Icons.signal_cellular_alt_2_bar_rounded;
      color = Colors.orange;
    } else {
      icon = Icons.signal_cellular_alt_1_bar_rounded;
      color = Colors.red;
    }

    return Column(
      children: [
        Icon(icon, color: color),
        Text('$rssi', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showDeviceDetails(ble.ScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeviceDetailSheet(result: result),
    );
  }
}

class _DeviceDetailSheet extends StatelessWidget {
  final ble.ScanResult result;

  const _DeviceDetailSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Icon(Icons.bluetooth_connected_rounded, color: colorScheme.onSecondaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.device.platformName.isEmpty ? '未知设备' : result.device.platformName, 
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(result.device.remoteId.str, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildInfoTile('RSSI (信号强度)', '${result.rssi} dBm', colorScheme, theme),
                _buildInfoTile('可连接性', result.advertisementData.connectable ? '是' : '否', colorScheme, theme),
                _buildInfoTile('TX Power', '${result.advertisementData.txPowerLevel ?? "未知"}', colorScheme, theme),
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('正在尝试连接设备... (调试模式)')),
                      );
                    },
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('尝试建立连接'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('关闭'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline)),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
