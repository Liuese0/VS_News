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

  // 뉴스와 토론을 명확히 분리
  List<NewsDiscussionItem> _popularNews = []; // 인기 뉴스 (댓글 많은 순)
  List<NewsDiscussionItem> _favoriteNews = []; // 즐겨찾기한 뉴스
  List<NewsDiscussionItem> _participatedDiscussions = []; // 참여한 토론 (인기 토론 중 본인이 참여한 것)

  int _selectedTabIndex = 0;
  int _selectedQuickTab = 0; // 0=인기 뉴스, 1=즐겨찾기, 2=참여한 토론
  bool _isLoading = false;
  bool _isRefreshing = false;
  Set<String> _favoriteNewsUrls = {}; // 즐겨찾기 URL 목록

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

      // 1. 즐겨찾기 목록 로드
      final favorites = await _firestoreService.getUserFavorites();
      _favoriteNewsUrls = favorites.toSet();

      // 2. 모든 뉴스의 댓글 통계 로드 (캐시에서)
      final allNewsCache = await _firestoreService.getPopularDiscussions();

      // 3. 인기 뉴스 = 댓글이 많은 순서대로 모든 뉴스 정렬
      _popularNews = allNewsCache.map((data) {
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

      // 댓글 수 기준 내림차순 정렬 (상위 20개)
      _popularNews.sort((a, b) => b.commentCount.compareTo(a.commentCount));
      _popularNews = _popularNews.take(20).toList();

      // 4. 즐겨찾기한 뉴스 상세 정보 로드
      if (_favoriteNewsUrls.isNotEmpty) {
        final favoriteNewsDetails = await _firestoreService.getFavoriteNewsDetails();
        _favoriteNews = favoriteNewsDetails.map((data) {
          final lastCommentTime = data['lastCommentTime'];
          return NewsDiscussionItem(
            newsUrl: data['newsUrl'] ?? '',
            title: data['title'] ?? '즐겨찾기한 뉴스',
            participantCount: data['participantCount'] ?? 0,
            commentCount: data['commentCount'] ?? 0,
            lastCommentTime: lastCommentTime is DateTime
                ? lastCommentTime
                : DateTime.now(),
          );
        }).toList();

        // 캐시에서 제목 찾아서 업데이트
        for (var favorite in _favoriteNews) {
          final cachedNews = _popularNews.firstWhere(
                (news) => news.newsUrl == favorite.newsUrl,
            orElse: () => favorite,
          );
          if (cachedNews != favorite && cachedNews.title != '제목 없음') {
            favorite.title = cachedNews.title;
          }
        }
      } else {
        _favoriteNews = [];
      }

      // 5. 참여한 토론 로드 (인기 토론 10개 중 본인이 참여한 것만)
      await newsCommentProvider.loadParticipatedDiscussions();
      final participatedUrls = newsCommentProvider.participatedNewsUrls.toSet();

      // 인기 토론 상위 10개
      final topDiscussions = _popularNews.take(10).toList();

      // 그 중 본인이 참여한 것만 필터링
      _participatedDiscussions = topDiscussions
          .where((news) => participatedUrls.contains(news.newsUrl))
          .toList();

      print('데이터 로드 완료: 인기 ${_popularNews.length}, 즐겨찾기 ${_favoriteNews.length}, 참여 ${_participatedDiscussions.length}');

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
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context, authProvider),
              Expanded(
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xD66B7280)),
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
        color: Color(0xD66B7280),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.article,
                  color: Color(0xD66B7280),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
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
            icon: const Icon(Icons.person_outline, color: Colors.white, size: 24),
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
          _buildSectionTitle(),
          _buildContentByTab(),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
            ),
            child: const Icon(Icons.person_outline, color: Color(0xFF999999), size: 24),
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
            color: const Color(0xD66B7280),
            onPressed: () => _showEditNicknameDialog(context, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final authProvider = context.watch<AuthProvider>();
    final userInfo = authProvider.userInfo ?? {};
    final favorites = _favoriteNewsUrls.length;
    final comments = userInfo['commentCount'] ?? 0;
    final tokens = userInfo['tokenCount'] ?? 0;

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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xD66B7280), size: 20),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 10,
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
              icon: Icons.trending_up,
              label: '인기',
              isPrimary: _selectedQuickTab == 0,
              onTap: () {
                setState(() => _selectedQuickTab = 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              icon: Icons.bookmark_outline,
              label: '즐겨찾기',
              isPrimary: _selectedQuickTab == 1,
              onTap: () {
                setState(() => _selectedQuickTab = 1);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              icon: Icons.forum_outlined,
              label: '토론',
              isPrimary: _selectedQuickTab == 2,
              onTap: () {
                setState(() => _selectedQuickTab = 2);
              },
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
          color: isPrimary ? const Color(0xD66B7280) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xD66B7280)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : const Color(0xD66B7280),
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

  Widget _buildSectionTitle() {
    String displayTitle = '인기 뉴스';
    IconData displayIcon = Icons.trending_up;

    if (_selectedQuickTab == 0) {
      displayTitle = '인기 뉴스';
      displayIcon = Icons.trending_up;
    } else if (_selectedQuickTab == 1) {
      displayTitle = '즐겨찾기한 뉴스';
      displayIcon = Icons.bookmark;
    } else if (_selectedQuickTab == 2) {
      displayTitle = '참여한 토론';
      displayIcon = Icons.forum;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        children: [
          Icon(displayIcon, color: const Color(0xD66B7280), size: 20),
          const SizedBox(width: 10),
          Text(
            displayTitle,
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

  Widget _buildContentByTab() {
    if (_selectedQuickTab == 0) {
      return _buildPopularNewsList();
    } else if (_selectedQuickTab == 1) {
      return _buildFavoriteNewsList();
    } else {
      return _buildParticipatedDiscussionsList();
    }
  }

  // 인기 뉴스 탭: 댓글이 많은 순서대로 뉴스 표시
  Widget _buildPopularNewsList() {
    if (_popularNews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.article_outlined,
        message: '인기 뉴스가 없습니다',
      );
    }

    return Column(
      children: _popularNews.asMap().entries.map((entry) =>
          _buildNewsCard(entry.value, entry.key, isNewsMode: true)).toList(),
    );
  }

  // 즐겨찾기 탭: 본인이 즐겨찾기한 뉴스만 표시
  Widget _buildFavoriteNewsList() {
    if (_favoriteNews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border,
        message: '즐겨찾기한 뉴스가 없습니다',
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD700)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '총 ${_favoriteNews.length}개의 즐겨찾기 뉴스',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._favoriteNews.asMap().entries.map((entry) =>
            _buildNewsCard(entry.value, entry.key, showFavoriteIcon: true, isNewsMode: true)),
      ],
    );
  }

  // 참여한 토론 탭: 인기 토론 10개 중 본인이 참여한 것만 표시
  Widget _buildParticipatedDiscussionsList() {
    if (_participatedDiscussions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.forum_outlined,
        message: '아직 참여한 토론이 없습니다',
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xD66B7280)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.forum,
                color: Color(0xD66B7280),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '인기 토론 중 ${_participatedDiscussions.length}개에 참여했습니다',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._participatedDiscussions.asMap().entries.map((entry) =>
            _buildNewsCard(entry.value, entry.key, showParticipated: true, isNewsMode: false)),
      ],
    );
  }

  Widget _buildNewsCard(NewsDiscussionItem news, int index, {
    bool showFavoriteIcon = false,
    bool showParticipated = false,
    bool isNewsMode = false
  }) {
    final isFavorite = _favoriteNewsUrls.contains(news.newsUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7.5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: (showParticipated || showFavoriteIcon)
            ? Border(
          left: BorderSide(
            color: showFavoriteIcon
                ? const Color(0xFFFFD700)
                : const Color(0xD66B7280),
            width: 3,
          ),
          top: const BorderSide(color: Color(0xFFF0F0F0)),
          right: const BorderSide(color: Color(0xFFF0F0F0)),
          bottom: const BorderSide(color: Color(0xFFF0F0F0)),
        )
            : Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xD66B7280),
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
              if (_selectedQuickTab == 0 && index < 3)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xD66B7280),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isNewsMode) ...[
                    // 뉴스 모드: 조회수, 읽기시간 표시
                    _buildStatBadge(Icons.visibility_outlined, '${(news.participantCount * 10 / 1000).toStringAsFixed(1)}K'),
                    const SizedBox(width: 20),
                    _buildStatBadge(Icons.access_time, '5분'),
                  ] else ...[
                    // 토론 모드: 좋아요, 댓글, 조회수 표시
                    _buildStatBadge(Icons.favorite_outline, '${news.participantCount}'),
                    const SizedBox(width: 20),
                    _buildStatBadge(Icons.chat_bubble_outline, '${news.commentCount}'),
                    const SizedBox(width: 20),
                    _buildStatBadge(Icons.visibility_outlined, '${(news.participantCount * 10 / 1000).toStringAsFixed(1)}K'),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () => _toggleFavorite(news.newsUrl),
                child: Icon(
                  isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                  size: 20,
                  color: isFavorite ? const Color(0xFFFFD700) : const Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),

          if (showParticipated)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xD66B7280),
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
        Icon(icon, size: 18, color: const Color(0xFF666666)),
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

  Widget _buildEmptyState({required IconData icon, required String message}) {
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
                icon,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
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
                backgroundColor: const Color(0xD66B7280),
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

  // 즐겨찾기 토글
  Future<void> _toggleFavorite(String newsUrl) async {
    try {
      if (_favoriteNewsUrls.contains(newsUrl)) {
        await _firestoreService.removeFavorite(newsUrl);
        setState(() {
          _favoriteNewsUrls.remove(newsUrl);
          _favoriteNews.removeWhere((news) => news.newsUrl == newsUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에서 제거되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        if (_favoriteNewsUrls.length >= 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기는 최대 100개까지 가능합니다'),
              backgroundColor: AppColors.warningColor,
            ),
          );
          return;
        }
        await _firestoreService.addFavorite(newsUrl);
        setState(() {
          _favoriteNewsUrls.add(newsUrl);
          // 인기 뉴스에서 해당 뉴스를 찾아 즐겨찾기 목록에 추가
          final newsItem = _popularNews.firstWhere(
                (news) => news.newsUrl == newsUrl,
            orElse: () => NewsDiscussionItem(
              newsUrl: newsUrl,
              title: '제목 없음',
              participantCount: 0,
              commentCount: 0,
              lastCommentTime: DateTime.now(),
            ),
          );
          _favoriteNews.add(newsItem);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에 추가되었습니다'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류 발생: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF0F0F0)),
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
                onTap: () {
                  setState(() => _selectedQuickTab = 1);
                },
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
            color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666),
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
              backgroundColor: const Color(0xD66B7280),
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
              borderSide: const BorderSide(color: Color(0xD66B7280), width: 2),
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
              backgroundColor: const Color(0xD66B7280),
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
      color: const Color(0xD66B7280),
      child: child,
    );
  }
}

class NewsDiscussionItem {
  final String newsUrl;
  String title; // final 제거하여 수정 가능하게 변경
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