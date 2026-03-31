import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

/// 全局会话服务。
///
/// 目标：把鉴权能力抽到基础设施层，业务模块只关心功能开发。
class SessionService extends ChangeNotifier {
  SessionService(this._storage);

  final SecureStorageService _storage;

  bool _initialized = false;
  bool _isAuthenticated = false;
  SessionUser? _user;

  bool get initialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  SessionUser? get user => _user;

  Future<void> bootstrap() async {
    if (_initialized) return;

    final token = await _storage.read(key: AppConstants.tokenKey);
    final userRaw = await _storage.read(key: AppConstants.userKey);

    if (token?.isNotEmpty == true) {
      _isAuthenticated = true;
      if (userRaw != null) {
        _user = SessionUser.fromJson(
          jsonDecode(userRaw) as Map<String, dynamic>,
        );
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    // 这里保留最小可运行实现，后续可直接替换为真实 API。
    final displayName = email.split('@').first;
    final token = 'session_${DateTime.now().millisecondsSinceEpoch}';

    _user = SessionUser(email: email, name: displayName);
    _isAuthenticated = true;

    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(
      key: AppConstants.userKey,
      value: jsonEncode(_user!.toJson()),
    );

    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);

    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

class SessionUser {
  const SessionUser({required this.email, required this.name});

  final String email;
  final String name;

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
      };

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'User',
    );
  }
}
