import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../core/auth/session_service.dart';

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
    final session = Modular.get<SessionService>();
    await session.bootstrap();
    if (!mounted) return;

    if (session.isAuthenticated) {
      Modular.to.navigate('/app/dashboard');
    } else {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
