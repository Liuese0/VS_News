// lib/widgets/daily_attendance_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/auth_provider.dart';

class DailyAttendanceDialog extends StatefulWidget {
  const DailyAttendanceDialog({Key? key}) : super(key: key);

  @override
  State<DailyAttendanceDialog> createState() => _DailyAttendanceDialogState();
}

class _DailyAttendanceDialogState extends State<DailyAttendanceDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isClaimed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();

    // 출석 상태 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadAttendanceStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _claimReward() async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final authProvider = context.read<AuthProvider>();

    setState(() => _isClaimed = true);

    final reward = await attendanceProvider.claimReward();

    if (reward != null && mounted) {
      // 사용자 정보 갱신
      await authProvider.loadUserInfo();

      // 성공 애니메이션 후 다이얼로그 닫기
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop();

        // 보상 받음 알림
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${reward.isWeekend ? '주말' : '평일'} 출석 완료! ${reward.rewardTokens}토큰을 받았습니다 🎉',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else if (attendanceProvider.errorMessage != null && mounted) {
      setState(() => _isClaimed = false);
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
    final screenWidth = MediaQuery.of(context).size.width;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Consumer<AttendanceProvider>(
          builder: (context, attendanceProvider, child) {
            final status = attendanceProvider.attendanceStatus;
            final hasClaimedToday = status?.hasClaimedToday ?? false;
            final currentStreak = status?.currentStreak ?? 0;
            final totalDays = status?.totalDays ?? 0;
            final isLoading = attendanceProvider.isLoading;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: hasClaimedToday || _isClaimed
                      ? [Colors.green.shade400, Colors.green.shade600]
                      : [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 닫기 버튼
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasClaimedToday || _isClaimed
                          ? Icons.check_circle
                          : Icons.calendar_today,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 제목
                  Text(
                    hasClaimedToday || _isClaimed ? '출석 완료!' : '출석하기',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 부제목
                  if (!hasClaimedToday && !_isClaimed)
                    Text(
                      _getRewardText(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 통계 카드
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('연속', '$currentStreak일', Icons.local_fire_department),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildStatItem('누적', '$totalDays일', Icons.star),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 버튼
                  if (!hasClaimedToday && !_isClaimed)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _claimReward,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          '출석하고 토큰 받기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isClaimed ? '출석 완료!' : '오늘은 이미 출석했어요',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // 닫기 텍스트 버튼
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
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

// 출석체크 다이얼로그 표시 헬퍼 함수
void showDailyAttendanceDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const DailyAttendanceDialog(),
  );
}