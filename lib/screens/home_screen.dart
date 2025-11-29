// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';
import '../screens/news_explorer_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  List<NewsDiscussionItem> _recentNews = [];
  int _selectedTabIndex = 0;
  bool _isLoading = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 펄스 애니메이션 설정
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final newsCommentProvider = context.read<NewsCommentProvider>();
      await newsCommentProvider.loadParticipatedDiscussions();

      final popularCache = await _firestoreService.getPopularDiscussions();
      _recentNews = popularCache.take(10).map((data) {
        final lastCommentTime = data['lastCommentTime'];
        return NewsDiscussionItem(
          newsUrl: data['newsUrl'] ?? '',
          title: data['title'] ?? '제목 없음',
          participantCount: data['participantCount'] ?? 0,
          commentCount: data['commentCount'] ?? 0,
          lastCommentTime: lastCommentTime is Timestamp
              ? lastCommentTime.toDate()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('데이터 로딩 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, authProvider),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              )
                  : _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    final userInfo = authProvider.userInfo ?? {};
    final tokenCount = userInfo['tokenCount'] ?? 0;
    final favoriteCount = userInfo['favoriteCount'] ?? 0;
    final commentCount = userInfo['commentCount'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x4010B981), // 에메랄드 25% 투명도
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 상단 바 (로고 + 프로필)
            Row(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: AppShadows.small,
                      ),
                      child: const Icon(
                        Icons.article,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '뉴스 디베이터',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Color(0x40000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    onPressed: () => _showLogoutDialog(context, authProvider),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 사용자 정보 카드 (그라데이션 + 그림자)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.large,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 그라데이션 아바타
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: AppColors.shimmerGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.small,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${authProvider.nickname} 디베이터',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryLight.withOpacity(0.2),
                                    AppColors.primaryColor.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '활동 디베이터',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.lightGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppShadows.small,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.white,
                          onPressed: () {
                            _showEditNicknameDialog(context, authProvider);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 통계 (그라데이션 카드)
                  Row(
                    children: [
                      _buildStatItem(
                        icon: Icons.favorite,
                        label: '좋아요',
                        value: favoriteCount.toString(),
                      ),
                      _buildStatItem(
                        icon: Icons.comment,
                        label: '의견',
                        value: commentCount.toString(),
                      ),
                      _buildStatItem(
                        icon: Icons.bookmark,
                        label: '토론',
                        value: tokenCount.toString(),
                      ),
                    ],
                  ),
                ],
              ),
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
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryColor.withOpacity(0.1),
              AppColors.primaryLight.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.lightGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 탭 버튼들 (그라데이션)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildTabButton(0, '뉴스탐색', Icons.explore),
              const SizedBox(width: 8),
              _buildTabButton(1, '즐겨찾기', Icons.bookmark),
              const SizedBox(width: 8),
              _buildTabButton(2, '새로고침', Icons.refresh),
            ],
          ),
        ),

        // 최근 참여한 토론 섹션
        Expanded(
          child: Container(
            color: Colors.grey.shade50,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.lightGradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: AppShadows.small,
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '최근 참여한 토론',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_recentNews.isEmpty)
                  _buildEmptyState()
                else
                  ..._recentNews.map((news) => _buildNewsDiscussionCard(news)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTabIndex = index);
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExploreScreen(),
              ),
            );
          } else if (index == 2) {
            _loadData();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.grey.shade300,
            ),
            boxShadow: isSelected ? AppShadows.medium : AppShadows.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsDiscussionCard(NewsDiscussionItem discussion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: AppShadows.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppColors.lightGradient,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text(
                      '🔥',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '정책',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(discussion.lastCommentTime),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            discussion.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatBadge(
                Icons.favorite,
                '${discussion.participantCount}',
                AppColors.primaryColor,
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                Icons.comment,
                '${discussion.commentCount}',
                Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                Icons.visibility,
                '${discussion.participantCount * 10}',
                Colors.grey.shade600,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.bookmark_outline,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(0.2),
                    AppColors.primaryColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 64,
                color: AppColors.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 참여한 토론이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.medium,
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExploreScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.explore),
                label: const Text('뉴스 탐색하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.home,
                label: '홈',
                isSelected: true,
              ),
              _buildBottomNavItem(
                icon: Icons.trending_up,
                label: '뉴스',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExploreScreen(),
                    ),
                  );
                },
              ),
              _buildBottomNavItem(
                icon: Icons.bookmark,
                label: '즐겨찾기',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.lightGradient : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? AppShadows.small : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?\n앱을 삭제하면 계정 정보가 사라지니 주의하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
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
                      SnackBar(
                        content: Text('로그아웃 실패: $e'),
                        backgroundColor: AppColors.errorColor,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('로그아웃'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNicknameDialog(BuildContext context, AuthProvider authProvider) {
    final controller = TextEditingController(text: authProvider.nickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '새로운 닉네임을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
            ),
          ),
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppShadows.small,
            ),
            child: ElevatedButton(
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
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    if (difference.inDays < 7) return '${difference.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

class NewsDiscussionItem {
  final String newsUrl;
  final String title;
  final int participantCount;
  final int commentCount;
  final DateTime lastCommentTime;

  NewsDiscussionItem({
    required this.newsUrl,
    required this.title,
    required this.participantCount,
    required this.commentCount,
    required this.lastCommentTime,
  });
}