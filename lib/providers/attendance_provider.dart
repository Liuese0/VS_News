// lib/providers/attendance_provider.dart
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AttendanceProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _hasCheckedToday = false;
  int _consecutiveDays = 0;
  List<String> _monthlyAttendance = [];
  bool _isLoading = false;

  bool get hasCheckedToday => _hasCheckedToday;
  int get consecutiveDays => _consecutiveDays;
  List<String> get monthlyAttendance => _monthlyAttendance;
  bool get isLoading => _isLoading;

  // 출석 상태 로드
  Future<void> loadAttendanceStatus() async {
    try {
      _isLoading = true;
      notifyListeners();

      final status = await _authService.getAttendanceStatus();
      _hasCheckedToday = status['hasCheckedToday'] ?? false;
      _consecutiveDays = status['consecutiveDays'] ?? 0;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('출석 상태 로드 실패: $e');
    }
  }

  // 이번 달 출석 기록 로드
  Future<void> loadMonthlyAttendance() async {
    try {
      _monthlyAttendance = await _authService.getMonthlyAttendance();
      notifyListeners();
    } catch (e) {
      print('월간 출석 기록 로드 실패: $e');
    }
  }

  // 출석 체크 및 보상 받기
  Future<Map<String, dynamic>> claimReward() async {
    try {
      final result = await _authService.claimDailyAttendance();

      // 상태 업데이트
      _hasCheckedToday = true;
      _consecutiveDays = result['consecutiveDays'] ?? 0;
      notifyListeners();

      // 월간 출석 기록 다시 로드
      await loadMonthlyAttendance();

      return result;
    } catch (e) {
      throw Exception('출석체크에 실패했습니다: $e');
    }
  }
}