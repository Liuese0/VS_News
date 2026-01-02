// lib/widgets/daily_attendance_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class DailyAttendanceWidget extends StatefulWidget {
  const DailyAttendanceWidget({Key? key}) : super(key: key);

  @override
  State<DailyAttendanceWidget> createState() => _DailyAttendanceWidgetState();
}

class _DailyAttendanceWidgetState extends State<DailyAttendanceWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadAttendanceStatus();
    });
  }

  Future<void> _claimReward() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final authProvider = context.read<AuthProvider>();

    final reward = await attendanceProvider.claimReward();

    if (reward != null && mounted) {
      // 사용자 정보 갱신
      await authProvider.loadUserInfo();

      // 보상 받음 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${reward.isWeekend ? '주말' : '평일'} 출석 완료! ${reward.rewardTokens}토큰을 받았습니다 🎉\n'
            '연속 ${reward.consecutiveDays}일 출석 중',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (attendanceProvider.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attendanceProvider.errorMessage!),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, child) {
        final status = attendanceProvider.attendanceStatus;
        final hasClaimedToday = status?.hasClaimedToday ?? false;
        final currentStreak = status?.currentStreak ?? 0;
        final totalDays = status?.totalDays ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: hasClaimedToday
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasClaimedToday ? Icons.check_circle : Icons.calendar_today,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 텍스트 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasClaimedToday ? '오늘 출석 완료!' : '오늘 출석하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '연속 ${currentStreak}일 | 총 ${totalDays}일',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        if (!hasClaimedToday) ...[
                          const SizedBox(height: 4),
                          Text(
                            _getRewardText(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 버튼
                  if (!hasClaimedToday)
                    ElevatedButton(
                      onPressed: attendanceProvider.isLoading ? null : _claimReward,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: attendanceProvider.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '출석',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRewardText() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;

    // 토요일(6) 또는 일요일(7)
    if (dayOfWeek == 6 || dayOfWeek == 7) {
      return '주말 보너스: 30토큰';
    } else {
      return '평일 보상: 10토큰';
    }
  }
}
