// lib/models/attendance.dart

class AttendanceStatus {
  final bool hasClaimedToday;
  final String todayDate;
  final int currentStreak;
  final int maxStreak;
  final int totalDays;
  final String? lastAttendanceDate;

  AttendanceStatus({
    required this.hasClaimedToday,
    required this.todayDate,
    required this.currentStreak,
    required this.maxStreak,
    required this.totalDays,
    this.lastAttendanceDate,
  });

  factory AttendanceStatus.fromMap(Map<String, dynamic> map) {
    return AttendanceStatus(
      hasClaimedToday: map['hasClaimedToday'] ?? false,
      todayDate: map['todayDate'] ?? '',
      currentStreak: map['currentStreak'] ?? 0,
      maxStreak: map['maxStreak'] ?? 0,
      totalDays: map['totalDays'] ?? 0,
      lastAttendanceDate: map['lastAttendanceDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hasClaimedToday': hasClaimedToday,
      'todayDate': todayDate,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'totalDays': totalDays,
      'lastAttendanceDate': lastAttendanceDate,
    };
  }
}

class AttendanceReward {
  final bool success;
  final int rewardTokens;
  final int newBalance;
  final int consecutiveDays;
  final int totalDays;
  final bool isWeekend;

  AttendanceReward({
    required this.success,
    required this.rewardTokens,
    required this.newBalance,
    required this.consecutiveDays,
    required this.totalDays,
    required this.isWeekend,
  });

  factory AttendanceReward.fromMap(Map<String, dynamic> map) {
    return AttendanceReward(
      success: map['success'] ?? false,
      rewardTokens: map['rewardTokens'] ?? 0,
      newBalance: map['newBalance'] ?? 0,
      consecutiveDays: map['consecutiveDays'] ?? 0,
      totalDays: map['totalDays'] ?? 0,
      isWeekend: map['isWeekend'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'rewardTokens': rewardTokens,
      'newBalance': newBalance,
      'consecutiveDays': consecutiveDays,
      'totalDays': totalDays,
      'isWeekend': isWeekend,
    };
  }
}