// lib/providers/attendance_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/attendance.dart';

class AttendanceProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AttendanceStatus? _attendanceStatus;
  bool _isLoading = false;
  String? _errorMessage;

  AttendanceStatus? get attendanceStatus => _attendanceStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasClaimedToday => _attendanceStatus?.hasClaimedToday ?? false;
  int get currentStreak => _attendanceStatus?.currentStreak ?? 0;
  int get totalDays => _attendanceStatus?.totalDays ?? 0;

  /// 출석 현황 조회
  Future<void> loadAttendanceStatus() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.getAttendanceStatus();
      _attendanceStatus = AttendanceStatus.fromMap(result);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 출석 보상 청구
  Future<AttendanceReward?> claimReward() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.claimDailyAttendance();
      final reward = AttendanceReward.fromMap(result);

      // 출석 현황 갱신
      await loadAttendanceStatus();

      _isLoading = false;
      notifyListeners();

      return reward;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// 에러 메시지 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}