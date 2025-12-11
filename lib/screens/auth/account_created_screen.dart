// lib/screens/auth/account_created_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../home_screen.dart';

class AccountCreatedScreen extends StatefulWidget {
  final String userId;
  final String nickname;

  const AccountCreatedScreen({
    super.key,
    required this.userId,
    required this.nickname,
  });

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final TextEditingController _nicknameController = TextEditingController();
  bool _isCustomizingNickname = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.nickname;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.successColor,
              AppColors.successColor.withOpacity(0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.05),

                    // 성공 아이콘 (애니메이션)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.08),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: screenWidth * 0.2,
                          color: AppColors.successColor,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // 환영 메시지
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            '환영합니다!',
                            style: TextStyle(
                              fontSize: screenWidth * 0.08,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          Text(
                            '계정이 성공적으로 생성되었습니다',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.04),

                          // 계정 정보 카드
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.06),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // 계정 ID
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      color: AppColors.primaryColor,
                                      size: screenWidth * 0.06,
                                    ),
                                    SizedBox(width: screenWidth * 0.03),
                                    Flexible(
                                      child: Text(
                                        '기기 계정 ID',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.035,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: screenWidth * 0.03,
                                        vertical: screenWidth * 0.01,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatUserId(widget.userId),
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.03,
                                          color: AppColors.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                const Divider(),
                                SizedBox(height: screenHeight * 0.02),

                                // 닉네임
                                if (!_isCustomizingNickname) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: AppColors.primaryColor,
                                        size: screenWidth * 0.06,
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        '닉네임',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.035,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Flexible(
                                        child: Text(
                                          widget.nickname,
                                          style: TextStyle(
                                            fontSize: screenWidth * 0.04,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          size: screenWidth * 0.05,
                                          color: AppColors.primaryColor,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isCustomizingNickname = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  // 닉네임 편집 모드
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '닉네임 변경',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.035,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.01),
                                      TextField(
                                        controller: _nicknameController,
                                        style: TextStyle(fontSize: screenWidth * 0.037),
                                        decoration: InputDecoration(
                                          hintText: '닉네임을 입력하세요',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.03,
                                            vertical: screenWidth * 0.03,
                                          ),
                                        ),
                                        maxLength: 10,
                                      ),
                                      SizedBox(height: screenHeight * 0.01),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _nicknameController.text = widget.nickname;
                                                _isCustomizingNickname = false;
                                              });
                                            },
                                            child: Text(
                                              '취소',
                                              style: TextStyle(fontSize: screenWidth * 0.035),
                                            ),
                                          ),
                                          SizedBox(width: screenWidth * 0.02),
                                          ElevatedButton(
                                            onPressed: _isSaving ? null : _saveNickname,
                                            child: _isSaving
                                                ? SizedBox(
                                              width: screenWidth * 0.04,
                                              height: screenWidth * 0.04,
                                              child: const CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                                : Text(
                                              '저장',
                                              style: TextStyle(fontSize: screenWidth * 0.035),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.04),

                    // 안내 메시지
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: screenWidth * 0.05,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Text(
                                  '이 계정은 현재 기기에만 저장됩니다',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.03,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Text(
                            '앱을 삭제하면 계정 정보가 사라지니 주의하세요',
                            style: TextStyle(
                              fontSize: screenWidth * 0.027,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    // 시작하기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: screenHeight * 0.07,
                      child: ElevatedButton(
                        onPressed: _goToHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.successColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                        ),
                        child: Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatUserId(String userId) {
    if (userId.length > 8) {
      return '${userId.substring(0, 4)}...${userId.substring(userId.length - 4)}';
    }
    return userId;
  }

  Future<void> _saveNickname() async {
    final newNickname = _nicknameController.text.trim();

    if (newNickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닉네임을 입력해주세요'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AuthProvider>().updateNickname(newNickname);

      if (mounted) {
        setState(() {
          _isCustomizingNickname = false;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('닉네임이 변경되었습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('닉네임 변경 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
    );
  }
}