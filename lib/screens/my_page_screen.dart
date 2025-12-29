// lib/screens/my_page_screen.dart (AdMob 연동 버전)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/ad_service.dart';
import '../services/billing_service.dart';
import '../utils/constants.dart';
import 'auth/welcome_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final AdService _adService = AdService();
  final BillingService _billingService = BillingService();

  bool _isLoadingAd = false;
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    // 광고 미리 로드
    _adService.preloadAd();

    // 결제 서비스 초기화
    _initializeBilling();
  }

  @override
  void dispose() {
    _billingService.dispose();
    super.dispose();
  }

  Future<void> _initializeBilling() async {
    setState(() {
      _isLoadingProducts = true;
    });

    await _billingService.initialize();

    // 결제 성공 콜백 설정
    _billingService.onPurchaseSuccess = (productId, tokens) async {
      try {
        // 토큰 지급
        await _authService.incrementTokens(tokens);
        final authProvider = context.read<AuthProvider>();
        await authProvider.loadUserInfo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('$tokens 토큰을 구매했습니다!'),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('토큰 지급 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    };

    // 결제 에러 콜백 설정
    _billingService.onPurchaseError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    setState(() {
      _isLoadingProducts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userInfo = authProvider.userInfo ?? {};
    final screenWidth = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 통합된 프로필 섹션 (상단바 포함)
                _buildIntegratedProfileSection(authProvider, userInfo, screenWidth),

                SizedBox(height: screenWidth * 0.05),

                // 활동 통계
                _buildActivityStats(userInfo, screenWidth),

                SizedBox(height: screenWidth * 0.05),

                // 토큰 & 상점 & 획득
                _buildTokenSection(userInfo, screenWidth),

                SizedBox(height: screenWidth * 0.05),

                // 설정 메뉴
                _buildSettingsMenu(authProvider, screenWidth),

                SizedBox(height: screenWidth * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedProfileSection(AuthProvider authProvider, Map<String, dynamic> userInfo, double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 15,
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: screenWidth * 0.08,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xD66B7280),
            Color(0xD64B5563),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // 상단바 (뒤로가기 버튼 + 설정 아이콘)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
              Text(
                '마이페이지',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              GestureDetector(
                onTap: () => _showSettings(context),
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: screenWidth * 0.06),

          // 프로필 이미지
          Container(
            width: screenWidth * 0.22,
            height: screenWidth * 0.22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: screenWidth * 0.11,
              color: const Color(0xD66B7280),
            ),
          ),
          SizedBox(height: screenWidth * 0.04),

          // 닉네임
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                authProvider.nickname,
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              GestureDetector(
                onTap: () => _showEditNicknameDialog(context, authProvider),
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.015),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: screenWidth * 0.04,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.02),

          // 레벨 또는 등급
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenWidth * 0.015,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user,
                  size: screenWidth * 0.04,
                  color: Colors.white,
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  '활성 디베이터',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStats(Map<String, dynamic> userInfo, double screenWidth) {
    final favorites = userInfo['favoriteCount'] ?? 0;
    final comments = userInfo['commentCount'] ?? 0;
    final tokens = userInfo['tokenCount'] ?? 0;
    final permanentSlots = userInfo['permanentBookmarkSlots'] ?? 0;
    final maxFavorites = 10 + permanentSlots;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '활동 통계',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.bookmark,
                  label: '즐겨찾기',
                  value: favorites.toString(),
                  subLabel: '최대 $maxFavorites개',
                  color: const Color(0xFFFFD700),
                  screenWidth: screenWidth,
                ),
                _buildStatItem(
                  icon: Icons.chat_bubble,
                  label: '작성 댓글',
                  value: comments.toString(),
                  color: const Color(0xD66B7280),
                  screenWidth: screenWidth,
                ),
                _buildStatItem(
                  icon: Icons.star,
                  label: '보유 토큰',
                  value: tokens.toString(),
                  color: const Color(0xFFFF9800),
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double screenWidth,
    String? subLabel,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.03),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: screenWidth * 0.06,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          value,
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF333333),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth * 0.03,
            color: const Color(0xFF666666),
          ),
        ),
        if (subLabel != null) ...[
          SizedBox(height: screenWidth * 0.005),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: screenWidth * 0.025,
              color: const Color(0xFF999999),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenSection(Map<String, dynamic> userInfo, double screenWidth) {
    final tokens = userInfo['tokenCount'] ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFFA000),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '보유 토큰',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.01),
                    Row(
                      children: [
                        Icon(
                          Icons.stars,
                          color: Colors.white,
                          size: screenWidth * 0.08,
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          '$tokens',
                          style: TextStyle(
                            fontSize: screenWidth * 0.08,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _showTokenEarn(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFFA000),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenWidth * 0.03,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '획득',
                        style: TextStyle(
                          fontSize: screenWidth * 0.037,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    ElevatedButton(
                      onPressed: () {
                        _showTokenShop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFFA000),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenWidth * 0.03,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '상점',
                        style: TextStyle(
                          fontSize: screenWidth * 0.037,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: screenWidth * 0.03),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.025),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: screenWidth * 0.04,
                    color: Colors.white,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      '토큰은 댓글 작성, 토론 참여로 획득할 수 있습니다',
                      style: TextStyle(
                        fontSize: screenWidth * 0.028,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(AuthProvider authProvider, double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildMenuItem(
              icon: Icons.help_outline,
              title: '도움말',
              onTap: () {
                _showHelp(context);
              },
              screenWidth: screenWidth,
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.info_outline,
              title: '앱 정보',
              onTap: () {
                _showAppInfo(context);
              },
              screenWidth: screenWidth,
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout,
              title: '로그아웃',
              onTap: () => _showLogoutDialog(context, authProvider),
              textColor: const Color(0xFFEF5350),
              screenWidth: screenWidth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double screenWidth,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? const Color(0xD66B7280),
        size: screenWidth * 0.06,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.04,
          color: textColor ?? const Color(0xFF333333),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: screenWidth * 0.04,
        color: const Color(0xFF999999),
      ),
      onTap: onTap,
    );
  }

  void _showEditNicknameDialog(BuildContext context, AuthProvider authProvider) {
    final controller = TextEditingController(text: authProvider.nickname);
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '닉네임 변경',
          style: TextStyle(fontSize: screenWidth * 0.045),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '새로운 닉네임을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xD66B7280), width: 2),
            ),
          ),
          maxLength: 10,
          style: TextStyle(fontSize: screenWidth * 0.037),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                try {
                  await authProvider.updateNickname(newNickname);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('닉네임이 변경되었습니다')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xD66B7280),
            ),
            child: Text(
              '저장',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '로그아웃',
          style: TextStyle(fontSize: screenWidth * 0.045),
        ),
        content: Text(
          '정말 로그아웃하시겠습니까?',
          style: TextStyle(fontSize: screenWidth * 0.037),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그아웃 실패: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xD66B7280),
            ),
            child: Text(
              '로그아웃',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenEarn(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final adStats = _adService.getAdStats();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                // 드래그 핸들
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 헤더
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: Row(
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        color: const Color(0xFFFFD700),
                        size: screenWidth * 0.07,
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Text(
                        '토큰 획득',
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),

                // 광고 보기 옵션
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: GestureDetector(
                    onTap: _isLoadingAd ? null : () async {
                      setModalState(() {
                        _isLoadingAd = true;
                      });

                      await _watchRewardedAd(context);

                      setModalState(() {
                        _isLoadingAd = false;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _adService.canWatchAd
                              ? [
                            const Color(0xFFFF6B6B),
                            const Color(0xFFFF5252),
                          ]
                              : [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: (_adService.canWatchAd
                                ? const Color(0xFFFF6B6B)
                                : Colors.grey)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _isLoadingAd
                                      ? Icons.hourglass_empty
                                      : Icons.play_circle_filled,
                                  color: Colors.white,
                                  size: screenWidth * 0.08,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isLoadingAd
                                          ? '광고 로딩 중...'
                                          : '광고 보고 토큰 받기',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: screenWidth * 0.01),
                                    Text(
                                      _isLoadingAd
                                          ? '잠시만 기다려주세요'
                                          : '30초 광고 시청',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.032,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.03,
                                  vertical: screenWidth * 0.015,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stars,
                                      color: const Color(0xFFFFD700),
                                      size: screenWidth * 0.045,
                                    ),
                                    SizedBox(width: screenWidth * 0.01),
                                    Text(
                                      '+${_adService.tokensPerAd}',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFF5252),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.03),
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.025),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: screenWidth * 0.04,
                                  color: Colors.white,
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Expanded(
                                  child: Text(
                                    '오늘 ${adStats['remainingAds']}회 남음 (총 ${adStats['remainingAds'] * _adService.tokensPerAd}토큰)',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.028,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 절취선
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenWidth * 0.05,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.grey.shade300,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                        child: Row(
                          children: [
                            Icon(
                              Icons.content_cut,
                              size: screenWidth * 0.04,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              '또는',
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Icon(
                              Icons.content_cut,
                              size: screenWidth * 0.04,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade300,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 캐시 충전 옵션
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showPurchaseDialog(context);
                    },
                    child: Container(
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF45A049),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                  size: screenWidth * 0.08,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '캐시로 토큰 구매',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: screenWidth * 0.01),
                                    Text(
                                      '다양한 패키지 제공',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.032,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: screenWidth * 0.05,
                              ),
                            ],
                          ),
                          SizedBox(height: screenWidth * 0.03),
                          Container(
                            padding: EdgeInsets.all(screenWidth * 0.025),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCashPackage('100토큰', '₩200', screenWidth),
                                Container(
                                  width: 1,
                                  height: screenWidth * 0.08,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                _buildCashPackage('500토큰', '₩800', screenWidth),
                                Container(
                                  width: 1,
                                  height: screenWidth * 0.08,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                _buildCashPackage('1000토큰', '₩1,500', screenWidth),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // 닫기 버튼
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                      ),
                      child: Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 광고 시청 로직
  Future<void> _watchRewardedAd(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    await _adService.showRewardedAd(
      onRewarded: (tokens) async {
        // 토큰 지급
        try {
          await _authService.incrementTokens(tokens);
          await authProvider.loadUserInfo();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('$tokens 토큰을 획득했습니다!'),
                  ],
                ),
                backgroundColor: const Color(0xFF4CAF50),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );

            // 모달 닫기
            Navigator.pop(context);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('토큰 지급 중 오류가 발생했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onError: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: const Color(0xFFFF9800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildCashPackage(String tokens, String price, double screenWidth) {
    return Column(
      children: [
        Text(
          tokens,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: screenWidth * 0.005),
        Text(
          price,
          style: TextStyle(
            fontSize: screenWidth * 0.028,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  void _showTokenShop(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final authProvider = context.read<AuthProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: const Color(0xFFFFD700),
                    size: screenWidth * 0.07,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Text(
                    '토큰 상점',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                children: [
                  _buildShopItem(
                    context: context,
                    authProvider: authProvider,
                    icon: Icons.chat_bubble_outline,
                    title: '발언권',
                    description: '댓글 추가권 (1회)',
                    tokenCost: 25,
                    itemType: 'speakingRightCount',
                    color: const Color(0xFF4CAF50),
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  _buildShopItem(
                    context: context,
                    authProvider: authProvider,
                    icon: Icons.text_fields,
                    title: '발언연장권',
                    description: '50글자 추가권 (1회)',
                    tokenCost: 30,
                    itemType: 'speakingExtensionCount',
                    color: const Color(0xFF2196F3),
                    screenWidth: screenWidth,
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  _buildShopItem(
                    context: context,
                    authProvider: authProvider,
                    icon: Icons.bookmark_add,
                    title: '즐겨찾기 영구 추가권',
                    description: '한도 영구 +1 (누적)',
                    tokenCost: 100,
                    itemType: 'permanentBookmarkSlots',
                    color: const Color(0xFFFF9800),
                    screenWidth: screenWidth,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopItem({
    required BuildContext context,
    required AuthProvider authProvider,
    required IconData icon,
    required String title,
    required String description,
    required int tokenCost,
    required String itemType,
    required Color color,
    required double screenWidth,
  }) {
    final userInfo = authProvider.userInfo ?? {};
    final currentTokens = userInfo['tokenCount'] ?? 0;
    final itemCount = userInfo[itemType] ?? 0;
    final canAfford = currentTokens >= tokenCost;

    // 영구 즐겨찾기 슬롯인 경우 현재 한도 표시
    String displayDescription = description;
    if (itemType == 'permanentBookmarkSlots') {
      final currentLimit = 10 + itemCount;
      displayDescription = '한도 영구 +1 (현재: $currentLimit개)';
    }

    return GestureDetector(
      onTap: () async {
        if (canAfford) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '$title 구매',
                style: TextStyle(fontSize: screenWidth * 0.045),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title을(를) $tokenCost 토큰에 구매하시겠습니까?',
                    style: TextStyle(fontSize: screenWidth * 0.037),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Text(
                    '현재 보유: $itemCount개',
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    '취소',
                    style: TextStyle(fontSize: screenWidth * 0.037),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xD66B7280),
                  ),
                  child: Text(
                    '구매',
                    style: TextStyle(fontSize: screenWidth * 0.037),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              // 아이템 구매 (토큰 차감 + 아이템 증가)
              await _authService.purchaseItem(itemType, tokenCost);
              await authProvider.loadUserInfo();

              if (context.mounted) {
                final updatedUserInfo = authProvider.userInfo ?? {};
                final newItemCount = updatedUserInfo[itemType] ?? 0;

                String message = '$title을(를) 구매했습니다!';

                // 영구 즐겨찾기 슬롯인 경우 한도 표시
                if (itemType == 'permanentBookmarkSlots') {
                  final newLimit = 10 + newItemCount;
                  message = '$title 구매 완료!\n즐겨찾기 한도: $newLimit개';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(message)),
                      ],
                    ),
                    backgroundColor: const Color(0xFF4CAF50),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
                Navigator.pop(context);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('구매 중 오류가 발생했습니다: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('토큰이 부족합니다'),
              backgroundColor: Color(0xFFFF9800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: canAfford ? color.withOpacity(0.3) : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: canAfford ? color.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: canAfford ? color : Colors.grey.shade400,
                size: screenWidth * 0.08,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.043,
                      fontWeight: FontWeight.bold,
                      color: canAfford ? const Color(0xFF333333) : Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    displayDescription,
                    style: TextStyle(
                      fontSize: screenWidth * 0.033,
                      color: canAfford ? const Color(0xFF666666) : Colors.grey.shade500,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.005),
                  Text(
                    '보유: $itemCount개',
                    style: TextStyle(
                      fontSize: screenWidth * 0.028,
                      color: itemCount > 0 ? color : Colors.grey.shade400,
                      fontWeight: itemCount > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenWidth * 0.015,
              ),
              decoration: BoxDecoration(
                color: canAfford ? color : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars,
                    color: Colors.white,
                    size: screenWidth * 0.04,
                  ),
                  SizedBox(width: screenWidth * 0.01),
                  Text(
                    '$tokenCost',
                    style: TextStyle(
                      fontSize: screenWidth * 0.037,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: const Color(0xD66B7280),
                    size: screenWidth * 0.07,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Text(
                    '설정',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                children: [
                  SwitchListTile(
                    title: Text(
                      '알림 설정',
                      style: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                    subtitle: Text(
                      '새로운 댓글 알림 받기',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    value: true,
                    onChanged: (value) {},
                    activeColor: const Color(0xD66B7280),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      '다크 모드',
                      style: TextStyle(fontSize: screenWidth * 0.04),
                    ),
                    subtitle: Text(
                      '어두운 테마 사용',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    value: false,
                    onChanged: (value) {},
                    activeColor: const Color(0xD66B7280),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
              child: Row(
                children: [
                  Icon(
                    Icons.help,
                    color: const Color(0xD66B7280),
                    size: screenWidth * 0.07,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Text(
                    '도움말',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                children: [
                  _buildHelpItem(
                    '토큰은 어떻게 얻나요?',
                    '광고 시청, 캐시 구매, 댓글 작성, 토론 참여로 토큰을 얻을 수 있습니다.',
                    screenWidth,
                  ),
                  _buildHelpItem(
                    '토큰은 어디에 사용하나요?',
                    '토큰 상점에서 발언권(댓글 추가), 발언연장권(50글자 추가), 즐겨찾기 영구 추가권을 구매할 수 있습니다.',
                    screenWidth,
                  ),
                  _buildHelpItem(
                    '광고는 하루에 몇 번 볼 수 있나요?',
                    '하루에 최대 5회까지 광고를 시청할 수 있으며, 광고당 10토큰을 얻을 수 있습니다.',
                    screenWidth,
                  ),
                  _buildHelpItem(
                    '즐겨찾기는 몇 개까지 가능한가요?',
                    '기본 10개까지 가능하며, 영구 추가권을 구매하면 한도가 영구적으로 증가합니다.',
                    screenWidth,
                  ),
                  _buildHelpItem(
                    '댓글 작성 제한이 있나요?',
                    '하루 최대 5개(발언권으로 추가 가능), 기본 50자(발언연장권으로 100자까지 가능)입니다.',
                    screenWidth,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String question, String answer, double screenWidth) {
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(
          fontSize: screenWidth * 0.038,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF333333),
        ),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              color: const Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final products = _billingService.products;
          final isLoading = _isLoadingProducts || _billingService.purchasePending;

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                // 드래그 핸들
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 헤더
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: const Color(0xFF4CAF50),
                        size: screenWidth * 0.07,
                      ),
                      SizedBox(width: screenWidth * 0.03),
                      Text(
                        '토큰 구매',
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isLoading)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFF4CAF50),
                          ),
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            _billingService.purchasePending
                                ? '결제 진행 중...'
                                : '상품 정보 로딩 중...',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_billingService.isAvailable)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: screenWidth * 0.15,
                            color: Colors.grey.shade400,
                          ),
                          SizedBox(height: screenWidth * 0.04),
                          Text(
                            '인앱 결제를 사용할 수 없습니다',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(height: screenWidth * 0.02),
                          Text(
                            'Google Play 스토어를 확인해주세요',
                            style: TextStyle(
                              fontSize: screenWidth * 0.033,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (products.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: screenWidth * 0.15,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: screenWidth * 0.04),
                            Text(
                              '사용 가능한 상품이 없습니다',
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        children: products.map((product) {
                          return _buildPurchaseItem(
                            context: context,
                            product: product,
                            screenWidth: screenWidth,
                            setModalState: setModalState,
                          );
                        }).toList(),
                      ),
                    ),

                // 닫기 버튼
                Padding(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                      ),
                      child: Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPurchaseItem({
    required BuildContext context,
    required ProductDetails product,
    required double screenWidth,
    required Function setModalState,
  }) {
    // 상품 ID에서 토큰 수 파싱
    int tokens = 0;
    if (product.id == BillingService.tokens100) {
      tokens = 100;
    } else if (product.id == BillingService.tokens500) {
      tokens = 500;
    } else if (product.id == BillingService.tokens1000) {
      tokens = 1000;
    }

    return GestureDetector(
      onTap: _billingService.purchasePending
          ? null
          : () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              '토큰 구매',
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$tokens 토큰을 ${product.price}에 구매하시겠습니까?',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
                SizedBox(height: screenWidth * 0.02),
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: screenWidth * 0.04,
                        color: const Color(0xFF666666),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Text(
                          'Google Play 결제가 진행됩니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  '취소',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: Text(
                  '구매',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          setModalState(() {});
          await _billingService.buyProduct(product);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenWidth * 0.03),
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF45A049),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.stars,
                color: Colors.white,
                size: screenWidth * 0.08,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tokens 토큰',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.005),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.02,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                product.price,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.article,
              color: const Color(0xD66B7280),
              size: screenWidth * 0.06,
            ),
            SizedBox(width: screenWidth * 0.02),
            Text(
              'LOGOS : Forum',
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '버전 1.0.0',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: const Color(0xFF666666),
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            Text(
              '뜨거운 이슈에 대한 현대인으로서 의견을 나누세요.',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xD66B7280),
            ),
            child: Text(
              '확인',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
        ],
      ),
    );
  }
}