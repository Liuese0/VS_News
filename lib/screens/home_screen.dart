// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';
import '../screens/news_explorer_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import '../providers/news_provider.dart';
import 'my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final AdService _adService = AdService();

  List<NewsDiscussionItem> _popularNews = [];
  List<NewsDiscussionItem> _favoriteNews = [];
  List<NewsDiscussionItem> _participatedDiscussions = [];

  int _selectedTabIndex = 0;
  int _selectedQuickTab = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  Set<String> _favoriteNewsUrls = {};

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

      final favoritesWithStats = await _firestoreService.getUserFavoritesWithStats();
      _favoriteNewsUrls = favoritesWithStats.map((f) => f['newsUrl'] as String).toSet();

      _favoriteNews = favoritesWithStats.map((favorite) {
        final publishedAt = favorite['publishedAt'];
        DateTime lastCommentTime = DateTime.now();
        if (publishedAt is Timestamp) {
          lastCommentTime = publishedAt.toDate();
        }

        return NewsDiscussionItem(
          newsUrl: favorite['newsUrl'] as String,
          title: favorite['title'] ?? '제목 없음',
          participantCount: favorite['participantCount'] ?? 0,
          commentCount: favorite['commentCount'] ?? 0,
          lastCommentTime: lastCommentTime,
          description: favorite['description'],
          imageUrl: favorite['imageUrl'],
          source: favorite['source'],
        );
      }).toList();

      final popularData = await _firestoreService.getPopularDiscussions(limit: 20);

      _popularNews = popularData.map((data) {
        final lastCommentTime = data['lastCommentTime'];
        return NewsDiscussionItem(
          newsUrl: data['newsUrl'] ?? '',
          title: data['title'] ?? '제목 없음',
          participantCount: data['participantCount'] ?? 0,
          commentCount: data['commentCount'] ?? 0,
          lastCommentTime: lastCommentTime is Timestamp
              ? lastCommentTime.toDate()
              : DateTime.now(),
          description: data['description'] ?? '자세한 내용을 보려면 탭하세요',
          imageUrl: data['imageUrl'],
          source: data['source'] ?? '뉴스',
        );
      }).toList();

      await newsCommentProvider.loadParticipatedDiscussions();
      final participatedUrls = newsCommentProvider.participatedNewsUrls.toSet();

      _participatedDiscussions = _popularNews
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
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
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.015),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.article,
                    color: const Color(0xD66B7280),
                    size: screenWidth * 0.05,
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Flexible(
                  child: Text(
                    'LOGOS : Forum',
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.person_outline,
              color: Colors.white,
              size: screenWidth * 0.06,
            ),
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

          // 배너 광고 삽입 (섹션 타이틀과 콘텐츠 사이)
          _buildBannerAd(),

          _buildContentByTab(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBannerAd() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (!_adService.isBannerAdLoaded || _adService.bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 50,
          child: AdWidget(ad: _adService.bannerAd!),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final authProvider = context.watch<AuthProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 15,
      ),
      padding: EdgeInsets.all(screenWidth * 0.045),
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
            width: screenWidth * 0.12,
            height: screenWidth * 0.12,
            constraints: const BoxConstraints(
              minWidth: 40,
              maxWidth: 60,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
            ),
            child: Icon(
              Icons.person_outline,
              color: const Color(0xFF999999),
              size: screenWidth * 0.06,
            ),
          ),
          SizedBox(width: screenWidth * 0.035),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  authProvider.nickname,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '활성 디베이터',
                  style: TextStyle(
                    color: const Color(0xFF666666),
                    fontSize: screenWidth * 0.035,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: screenWidth * 0.05,
            ),
            color: const Color(0xD66B7280),
            padding: EdgeInsets.all(screenWidth * 0.02),
            constraints: const BoxConstraints(),
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        children: [
          _buildStatCard(Icons.favorite_outline, favorites.toString(), '즐겨찾기'),
          SizedBox(width: screenWidth * 0.02),
          _buildStatCard(Icons.chat_bubble_outline, comments.toString(), '댓글'),
          SizedBox(width: screenWidth * 0.02),
          _buildStatCard(Icons.star_outline, tokens.toString(), '토큰'),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: screenWidth * 0.025,
          horizontal: screenWidth * 0.02,
        ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xD66B7280), size: screenWidth * 0.05),
            SizedBox(height: screenWidth * 0.007),
            Text(
              value,
              style: TextStyle(
                fontSize: screenWidth * 0.042,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF666666),
                fontSize: screenWidth * 0.025,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        15,
        screenWidth * 0.05,
        0,
      ),
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
          SizedBox(width: screenWidth * 0.02),
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
          SizedBox(width: screenWidth * 0.02),
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
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xD66B7280) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xD66B7280)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: screenWidth * 0.05,
              color: isPrimary ? Colors.white : const Color(0xD66B7280),
            ),
            SizedBox(width: screenWidth * 0.02),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: isPrimary ? Colors.white : const Color(0xD66B7280),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
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

    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        25,
        screenWidth * 0.05,
        15,
      ),
      child: Row(
        children: [
          Icon(displayIcon, color: const Color(0xD66B7280), size: screenWidth * 0.05),
          SizedBox(width: screenWidth * 0.025),
          Flexible(
            child: Text(
              displayTitle,
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
              ),
              overflow: TextOverflow.ellipsis,
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

  Widget _buildFavoriteNewsList() {
    if (_favoriteNews.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_border,
        message: '즐겨찾기한 뉴스가 없습니다',
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final favoriteCount = _favoriteNews.length;

    // 개수에 따른 색상 결정 (8개 이상: 주황색, 10개: 빨간색)
    Color borderColor;
    Color backgroundColor;
    Color iconColor;
    Color countColor;

    if (favoriteCount >= 10) {
      // 최대 도달 - 빨간색
      borderColor = const Color(0xFFEF5350);
      backgroundColor = const Color(0xFFFFEBEE);
      iconColor = const Color(0xFFEF5350);
      countColor = const Color(0xFFD32F2F);
    } else if (favoriteCount >= 8) {
      // 거의 찬 상태 - 주황색
      borderColor = const Color(0xFFFF9800);
      backgroundColor = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFFF9800);
      countColor = const Color(0xFFF57C00);
    } else {
      // 여유 있는 상태 - 금색
      borderColor = const Color(0xFFFFD700);
      backgroundColor = const Color(0xFFFFF9E6);
      iconColor = const Color(0xFFFFD700);
      countColor = const Color(0xFFFFD700);
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 10,
          ),
          padding: EdgeInsets.all(screenWidth * 0.03),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                favoriteCount >= 10 ? Icons.bookmark : Icons.bookmark,
                color: iconColor,
                size: screenWidth * 0.05,
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: const Color(0xFF666666),
                    ),
                    children: [
                      const TextSpan(text: '총 '),
                      TextSpan(
                        text: '$favoriteCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: countColor,
                          fontSize: screenWidth * 0.035,
                        ),
                      ),
                      const TextSpan(text: '개의 즐겨찾기 뉴스 '),
                      TextSpan(
                        text: '($favoriteCount/10)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: countColor,
                          fontSize: screenWidth * 0.032,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (favoriteCount >= 10)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.02,
                    vertical: screenWidth * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '최대',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.028,
                      fontWeight: FontWeight.bold,
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

  Widget _buildParticipatedDiscussionsList() {
    if (_participatedDiscussions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.forum_outlined,
        message: '아직 참여한 토론이 없습니다',
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: 10,
          ),
          padding: EdgeInsets.all(screenWidth * 0.03),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xD66B7280)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.forum,
                color: const Color(0xD66B7280),
                size: screenWidth * 0.05,
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Text(
                  '인기 토론 중 ${_participatedDiscussions.length}개에 참여했습니다',
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: const Color(0xFF666666),
                  ),
                  overflow: TextOverflow.ellipsis,
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 7.5,
      ),
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
      child: Stack(
        children: [
          if (showParticipated || showFavoriteIcon)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: showFavoriteIcon
                      ? const Color(0xFFFFD700)
                      : const Color(0xD66B7280),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(screenWidth * 0.035),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.02,
                              vertical: screenWidth * 0.01,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xD66B7280),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              news.source ?? '뉴스',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Flexible(
                            child: Text(
                              _formatDateTime(news.lastCommentTime),
                              style: TextStyle(
                                color: const Color(0xFF666666),
                                fontSize: screenWidth * 0.03,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedQuickTab == 0 && index < 3)
                      Container(
                        width: screenWidth * 0.06,
                        height: screenWidth * 0.06,
                        decoration: BoxDecoration(
                          color: const Color(0xD66B7280),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: screenWidth * 0.025),

                Text(
                  news.title,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenWidth * 0.02),

                Text(
                  news.description ?? '뉴스 내용을 확인하려면 탭하세요.',
                  style: TextStyle(
                    color: const Color(0xFF666666),
                    fontSize: screenWidth * 0.035,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: screenWidth * 0.03),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isNewsMode) ...[
                            _buildStatBadge(Icons.visibility_outlined, '${(news.participantCount * 10 / 1000).toStringAsFixed(1)}K'),
                            SizedBox(width: screenWidth * 0.05),
                            _buildStatBadge(Icons.chat_bubble_outline, '${news.commentCount}'),
                          ] else ...[
                            _buildStatBadge(Icons.favorite_outline, '${news.participantCount}'),
                            SizedBox(width: screenWidth * 0.05),
                            _buildStatBadge(Icons.chat_bubble_outline, '${news.commentCount}'),
                            SizedBox(width: screenWidth * 0.05),
                            _buildStatBadge(Icons.visibility_outlined, '${(news.participantCount * 10 / 1000).toStringAsFixed(1)}K'),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _toggleFavorite(news),
                      child: Icon(
                        isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                        size: screenWidth * 0.05,
                        color: isFavorite ? const Color(0xFFFFD700) : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),

                if (showParticipated)
                  Container(
                    margin: EdgeInsets.only(top: screenWidth * 0.02),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.02,
                      vertical: screenWidth * 0.01,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD66B7280),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '참여함',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: screenWidth * 0.045, color: const Color(0xFF666666)),
        SizedBox(width: screenWidth * 0.01),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFF666666),
            fontSize: screenWidth * 0.035,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.08),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: screenWidth * 0.12,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Text(
              message,
              style: TextStyle(
                fontSize: screenWidth * 0.037,
                color: const Color(0xFF666666),
              ),
            ),
            SizedBox(height: screenWidth * 0.06),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExploreScreen()),
                );
              },
              icon: Icon(Icons.explore_outlined, size: screenWidth * 0.045),
              label: Text(
                '뉴스 탐색하기',
                style: TextStyle(fontSize: screenWidth * 0.037),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xD66B7280),
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenWidth * 0.03,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(NewsDiscussionItem news) async {
    try {
      if (_favoriteNewsUrls.contains(news.newsUrl)) {
        await _firestoreService.removeFavorite(news.newsUrl);
        setState(() {
          _favoriteNewsUrls.remove(news.newsUrl);
          _favoriteNews.removeWhere((n) => n.newsUrl == news.newsUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에서 제거되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        // 10개 제한 체크 - 서버에서 처리되지만 UI에서 미리 체크
        if (_favoriteNewsUrls.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기는 최대 10개까지 가능합니다'),
              backgroundColor: AppColors.warningColor,
            ),
          );
          return;
        }
        await _firestoreService.addFavorite(
          news.newsUrl,
          title: news.title,
          description: news.description,
          imageUrl: news.imageUrl,
          source: news.source,
          publishedAt: news.lastCommentTime,
        );
        setState(() {
          _favoriteNewsUrls.add(news.newsUrl);
          _favoriteNews.add(news);
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF0F0F0)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
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
                icon: Icons.person_outline,
                label: '마이페이지',
                isSelected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyPageScreen()),
                  );
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
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666),
            size: screenWidth * 0.06,
          ),
          SizedBox(height: screenWidth * 0.01),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xD66B7280) : const Color(0xFF666666),
              fontSize: screenWidth * 0.03,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
  String title;
  final int participantCount;
  final int commentCount;
  final DateTime lastCommentTime;
  String? description;
  String? imageUrl;
  String? source;

  NewsDiscussionItem({
    required this.newsUrl,
    required this.title,
    required this.participantCount,
    required this.commentCount,
    required this.lastCommentTime,
    this.description,
    this.imageUrl,
    this.source,
  });
}