import 'package:flutter/material.dart';

import '../../domain/repositories/auth_repository.dart';

/// 认证状态
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// 认证控制器
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthState _state = const AuthState();
  AuthState get state => _state;

  AuthController(this._authRepository) {
    _checkLoginStatus();
  }

  /// 检查登录状态
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authRepository.isLoggedIn();
    _state = _state.copyWith(isLoggedIn: isLoggedIn);
    notifyListeners();
  }

  /// 登录
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final result = await _authRepository.login(
        email: email,
        password: password,
      );

      if (result.success) {
        _state = _state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          user: result.user,
        );
        notifyListeners();
        return true;
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: result.error,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: '登录失败: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// 注册
  Future<bool> register({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final result = await _authRepository.register(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );

      if (result.success) {
        _state = _state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          user: result.user,
        );
        notifyListeners();
        return true;
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: result.error,
        );
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: '注册失败: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    await _authRepository.logout();

    _state = const AuthState();
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }
}