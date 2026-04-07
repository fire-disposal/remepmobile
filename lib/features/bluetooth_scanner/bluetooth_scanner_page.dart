import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;

import '../../core/di/service_locator.dart';
import '../../core/widgets/widgets.dart';
import 'bluetooth_scanner_controller.dart';

/// 蓝牙扫描页面
/// 扫描并展示周边 BLE 设备
class BluetoothScannerPage extends StatefulWidget {
  const BluetoothScannerPage({super.key});

  @override
  State<BluetoothScannerPage> createState() => _BluetoothScannerPageState();
}

class _BluetoothScannerPageState extends State<BluetoothScannerPage>
    with WidgetsBindingObserver {
  late final BluetoothScannerController _controller;
  bool _isInitialized = false;
  bool _onlyConnectable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _controller = getIt<BluetoothScannerController>();
    await _controller.initialize();

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stopScan();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '蓝牙设备扫描',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        actions: [
          IconButton(
            onPressed: () => _controller.clearDevices(),
            icon: const Icon(Icons.clear_all),
            tooltip: '清除列表',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isInitialized
          ? _buildScannerView()
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildScannerView() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final state = _controller.state;
        final devices = _controller.getFilteredDevices(
          onlyConnectable: _onlyConnectable,
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 状态栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildStatusBar(state),
              ),
            ),

            // 过滤器
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFilterChips(state),
              ),
            ),

            // 设备列表
            devices.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyState(state),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDeviceCard(
                          devices[index],
                          index == devices.length - 1,
                        ),
                        childCount: devices.length,
                      ),
                    ),
                  ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        );
      },
    );
  }

  Widget _buildStatusBar(BluetoothScannerState state) {
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (state.status) {
      case ScannerStatus.scanning:
        statusColor = Colors.blue;
        statusText = '扫描中';
        statusIcon = Icons.radar_rounded;
        break;
      case ScannerStatus.error:
        statusColor = Colors.red;
        statusText = '错误';
        statusIcon = Icons.error_outline_rounded;
        break;
      case ScannerStatus.idle:
        statusColor = state.devices.isNotEmpty ? Colors.green : Colors.grey;
        statusText = state.devices.isNotEmpty
            ? '发现 ${state.devices.length} 台设备'
            : '就绪';
        statusIcon = state.devices.isNotEmpty
            ? Icons.bluetooth_rounded
            : Icons.bluetooth_disabled_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          if (state.connectableCount > 0)
            Text(
              '${state.connectableCount} 台可连接',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BluetoothScannerState state) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          FilterChip(
            label: const Text('仅可连接设备'),
            selected: _onlyConnectable,
            onSelected: (value) {
              setState(() => _onlyConnectable = value);
            },
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          if (state.lastScanTime != null)
            Text(
              '上次扫描: ${_formatTime(state.lastScanTime!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BluetoothScannerState state) {
    if (state.isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text('正在搜索蓝牙设备...'),
          ],
        ),
      );
    }

    if (state.hasError) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: '扫描出错',
        subtitle: state.errorMessage ?? '请检查蓝牙权限后重试',
        actionText: '重试',
      onAction: () => _controller.startScan(),
      );
    }

    return const EmptyState(
      icon: Icons.bluetooth_searching_rounded,
      title: '未发现设备',
      subtitle: '点击下方按钮开始扫描周边的蓝牙 BLE 设备',
    );
  }

  Widget _buildDeviceCard(ble.ScanResult result, bool isLast) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final device = result.device;
    final name = device.platformName.isEmpty ? '未知设备' : device.platformName;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: ModernCard(
        onTap: () => _showDeviceDetails(result),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildSignalIndicator(result.rssi, colorScheme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.remoteId.str,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: result.advertisementData.connectable
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
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
            ],
          ),
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

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          Text(
            '$rssi',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isScanning = _controller.state.isScanning;

        return FloatingActionButton.extended(
          onPressed: () => _controller.toggleScan(),
          icon: Icon(isScanning ? Icons.stop_rounded : Icons.search_rounded),
          label: Text(isScanning ? '停止扫描' : '开始扫描'),
          backgroundColor: isScanning ? Colors.red : null,
        );
      },
    );
  }

  void _showDeviceDetails(ble.ScanResult result) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.bluetooth_connected_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.device.platformName.isEmpty
                              ? '未知设备'
                              : result.device.platformName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result.device.remoteId.str,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
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
                  _buildDetailTile('RSSI (信号强度)', '${result.rssi} dBm'),
                  _buildDetailTile('可连接性',
                      result.advertisementData.connectable ? '是' : '否'),
                  _buildDetailTile('TX Power Level',
                      '${result.advertisementData.txPowerLevel ?? "未知"} dBm'),
                  _buildDetailTile('Manufacturer Data',
                      result.advertisementData.manufacturerData.isNotEmpty
                          ? '${result.advertisementData.manufacturerData.length} bytes'
                          : '无'),
                  const SizedBox(height: 24),
                  if (result.advertisementData.connectable)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _controller.connectToDevice(result.device);
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('连接设备'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('关闭'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
