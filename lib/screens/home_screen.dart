// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

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

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // 전체 배경: 흰색
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context, authProvider),
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xD66B7280)), // 연한 회색
                  ),
                )
                    : _buildContent(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 15,
      ),
      decoration: const BoxDecoration(
        color: Color(0xD66B7280), // 연한 회색
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Text(
                '📰', // 신문 이모지
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(width: 8),
              Text(
                '뉴스 디베이터',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white, size: 24), // outline 아이콘
            onPressed: () => _showLogoutDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshControl(
      onRefresh: _onRefresh,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(0),
        children: [
          _buildProfileHeader(),
          _buildStatsCards(),
          _buildQuickActions(),
          _buildSectionTitle('최근 참여한 토론', Icons.chat_bubble_outline),
          if (_recentNews.isEmpty)
            _buildEmptyState()
          else
            ..._recentNews.asMap().entries.map((entry) =>
                _buildNewsCard(entry.value, entry.key)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final authProvider = context.watch<AuthProvider>();
    final userInfo = authProvider.userInfo ?? {};

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // 흰색 배경
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)), // 연한 회색 테두리
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.transparent, // 투명 배경
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2), // 연한 회색 테두리
            ),
            child: const Icon(Icons.person_outline, color: Color(0xFF999999), size: 24), // 회색 아이콘
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${authProvider.nickname}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '활성 디베이터',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: const Color(0xD66B7280), // 연한 회색 아이콘
            onPressed: () => _showEditNicknameDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final authProvider = context.watch<AuthProvider>();
    final userInfo = authProvider.userInfo ?? {};
    final favorites = userInfo['favoriteCount'] ?? 12;
    final comments = userInfo['commentCount'] ?? 45;
    final tokens = userInfo['tokenCount'] ?? 150;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(Icons.favorite_outline, favorites.toString(), '즐겨찾기'),
          const SizedBox(width: 8),
          _buildStatCard(Icons.chat_bubble_outline, comments.toString(), '댓글'),
          const SizedBox(width: 8),
          _buildStatCard(Icons.star_outline, tokens.toString(), '토큰'),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10), // 세로 패딩 더 줄임
        decoration: BoxDecoration(
          color: Colors.white, // 흰색 배경
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0F0F0)), // 연한 회색 테두리
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xD66B7280), size: 20), // 연한 회색, 크기 더 줄임
            const SizedBox(height: 3), // 간격 더 줄임
            Text(
              value,
              style: const TextStyle(
                fontSize: 17, // 폰트 크기 더 줄임
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 10, // 폰트 크기 더 줄임
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.navigation,
              label: '뉴스탐색',
              isPrimary: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              icon: Icons.bookmark_outline,
              label: '즐겨찾기',
              isPrimary: false,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              icon: Icons.refresh,
              label: '새로고침',
              isPrimary: false,
              onTap: _onRefresh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xD66B7280) : Colors.white, // 연한 회색 또는 흰색
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xD66B7280)), // 연한 회색 테두리
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : const Color(0xD66B7280), // 연한 회색 아이콘
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xD66B7280),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xD66B7280), size: 20), // 연한 회색 아이콘
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsDiscussionItem news, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7.5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, // 흰색 배경
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        // 참여한 토론 강조 - 좌측 테두리
        border: index < 2
            ? Border(
          left: const BorderSide(color: Color(0xD66B7280), width: 3), // 연한 회색 강조
          top: const BorderSide(color: Color(0xFFF0F0F0)),
          right: const BorderSide(color: Color(0xFFF0F0F0)),
          bottom: const BorderSide(color: Color(0xFFF0F0F0)),
        )
            : Border.all(color: const Color(0xFFF0F0F0)), // 연한 회색 테두리
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xD66B7280), // 연한 회색 배경
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '경제',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDateTime(news.lastCommentTime)}',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (index < 3)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xD66B7280), // 연한 회색 배경
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 제목
          Text(
            news.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // 내용
          Text(
            '정부의 가상화폐 규제 강화 방안에 투자자들 사이에서 격론이 벌어지고 있습니다...',
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // 태그
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('#비트코인'),
              _buildTag('#규제'),
              _buildTag('#투자'),
            ],
          ),
          const SizedBox(height: 12),

          // 통계 및 액션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildStatBadge(Icons.favorite_outline, '${news.participantCount}'),
                  const SizedBox(width: 20),
                  _buildStatBadge(Icons.chat_bubble_outline, '${news.commentCount}'),
                  const SizedBox(width: 20),
                  _buildStatBadge(Icons.visibility_outlined, '${(news.participantCount * 10 / 1000).toStringAsFixed(1)}K'),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.bookmark_outline,
                  size: 20,
                  color: Color(0xFFCCCCCC), // 연한 회색
                ),
              ),
            ],
          ),

          // 참여 표시
          if (index < 2)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xD66B7280), // 연한 회색 배경
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '참여함',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF666666)), // 회색 아이콘
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 14,
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
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 48,
                color: Colors.grey.shade400, // 회색 아이콘
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 참여한 토론이 없습니다',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                );
              },
              icon: const Icon(Icons.explore_outlined),
              label: const Text('뉴스 탐색하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xD66B7280), // 연한 회색 버튼
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
      decoration: const BoxDecoration(
        color: Colors.white, // 흰색 배경
        border: Border(
          top: BorderSide(color: Color(0xFFF0F0F0)), // 연한 회색 테두리
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.home_outlined,
                label: '홈',
                isSelected: true,
                onTap: () {},
              ),
              _buildBottomNavItem(
                icon: Icons.trending_up_outlined,
                label: '뉴스',
                isSelected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExploreScreen()),
                  );
                },
              ),
              _buildBottomNavItem(
                icon: Icons.bookmark_outline,
                label: '즐겨찾기',
                isSelected: false,
                onTap: () {},
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666), // 연한 회색으로 통일
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666), // 연한 회색으로 통일
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
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
              backgroundColor: const Color(0xD66B7280), // 연한 회색 버튼
            ),
            child: const Text('로그아웃'),
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
              borderSide: const BorderSide(color: Color(0xD66B7280), width: 2), // 연한 회색 테두리
            ),
          ),
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
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
              backgroundColor: const Color(0xD66B7280), // 연한 회색 버튼
            ),
            child: const Text('저장'),
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
    super.dispose();
  }
}

// RefreshControl 위젯 (Pull to Refresh)
class RefreshControl extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const RefreshControl({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xD66B7280), // 연한 회색 인디케이터
      child: child,
    );
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