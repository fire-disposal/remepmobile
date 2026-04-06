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
            child: _scanResults.isEmpty
                ? const EmptyState(
                    icon: Icons.bluetooth_searching_rounded,
                    title: '未发现设备',
                    subtitle: '点击下方按钮开始扫描周边的蓝牙 BLE 设备',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scanResults.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildDeviceCard(_scanResults[index], colorScheme, theme),
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
    return Container(
      padding: const EdgeInsets.all(20),
      color: colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.bug_report_rounded, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设备列表', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('共发现 ${_scanResults.length} 个活跃设备', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => BluetoothPickerSheet.show(context),
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: '测试组件版',
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
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildSignalIndicator(result.rssi, colorScheme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(device.remoteId.str, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.outline),
          ],
        ),
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
