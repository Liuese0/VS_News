// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  String _userId = '';
  String _nickname = '';
  bool _isInitialized = false;
  bool _hasExistingAccount = false;
  Map<String, dynamic>? _userInfo;

  String get userId => _userId;
  String get nickname => _nickname;
  bool get isInitialized => _isInitialized;
  bool get hasExistingAccount => _hasExistingAccount;
  Map<String, dynamic>? get userInfo => _userInfo;

  AuthProvider() {
    _checkExistingAccount();
  }

  // 기존 계정 확인 (자동)
  Future<void> _checkExistingAccount() async {
    try {
      final hasAccount = await _authService.hasExistingAccount();
      _hasExistingAccount = hasAccount;

      if (hasAccount) {
        // 기존 계정이 있으면 자동 로그인
        await _initializeUser();
      } else {
        // 기존 계정이 없으면 Welcome 화면으로
        _isInitialized = true;
      }

      notifyListeners();
    } catch (e) {
      print('계정 확인 실패: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 수동으로 사용자 초기화 (Welcome 화면에서 호출)
  Future<void> initializeUserManually() async {
    try {
      _userId = await _authService.initializeUser();
      _userInfo = await _authService.getUserInfo();
      _nickname = _userInfo?['nickname'] ?? '익명';
      _hasExistingAccount = true;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('사용자 초기화 실패: $e');
      rethrow;
    }
  }

  // 자동 사용자 초기화 (기존 계정이 있을 때)
  Future<void> _initializeUser() async {
    try {
      _userId = await _authService.getCurrentUid();
      _userInfo = await _authService.getUserInfo();
      _nickname = _userInfo?['nickname'] ?? '익명';
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('사용자 초기화 실패: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  // 닉네임 업데이트
  Future<void> updateNickname(String newNickname) async {
    try {
      await _authService.updateNickname(newNickname);
      _nickname = newNickname;
      notifyListeners();
    } catch (e) {
      print('닉네임 업데이트 실패: $e');
      rethrow;
    }
  }

  // 사용자 정보 새로고침 (refreshUserInfo와 동일)
  Future<void> refreshUserInfo() async {
    try {
      _userInfo = await _authService.getUserInfo();
      _nickname = _userInfo?['nickname'] ?? '익명';
      notifyListeners();
    } catch (e) {
      print('사용자 정보 새로고침 실패: $e');
    }
  }

  // 사용자 정보 로드 (refreshUserInfo의 별칭)
  Future<void> loadUserInfo() async {
    await refreshUserInfo();
  }

  // 로그아웃
  Future<void> logout() async {
    try {
      await _authService.logout();
      _userId = '';
      _nickname = '';
      _isInitialized = false;
      _hasExistingAccount = false;
      _userInfo = null;
      notifyListeners();
    } catch (e) {
      print('로그아웃 실패: $e');
      rethrow;
    }
  }
}