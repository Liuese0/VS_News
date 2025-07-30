import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthProvider extends ChangeNotifier {
  String _userId = '';
  String _nickname = '';
  bool _isInitialized = false;

  String get userId => _userId;
  String get nickname => _nickname;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();

    // 저장된 사용자 ID가 있는지 확인
    String? savedUserId = prefs.getString('user_id');
    String? savedNickname = prefs.getString('nickname');

    if (savedUserId == null) {
      // 새 사용자 생성
      const uuid = Uuid();
      _userId = uuid.v4();
      _nickname = '익명${DateTime.now().millisecondsSinceEpoch % 10000}';

      await prefs.setString('user_id', _userId);
      await prefs.setString('nickname', _nickname);
    } else {
      _userId = savedUserId;
      _nickname = savedNickname ?? '익명';
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateNickname(String newNickname) async {
    _nickname = newNickname;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', newNickname);
    notifyListeners();
  }
}