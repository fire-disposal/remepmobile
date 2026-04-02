import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    // 直接进入主应用，不再检查登录状态
    Modular.to.navigate('/app/fall-detector');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
