// lib/screens/news_explorer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/news_auto_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';
import '../providers/news_provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final NewsAutoService _newsService = NewsAutoService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _appBarAnimationController;
  late final Animation<Offset> _appBarSlideAnimation;
  late final Animation<double> _paddingAnimation;

  double _lastScrollOffset = 0.0;
  bool _isAppBarVisible = true;

  String _selectedCategory = '인기';
  int _selectedTab = 0;
  List<AutoCollectedNews> _newsList = [];
  bool _isLoading = false;
  Set<String> _favoriteNewsIds = <String>{};

  final List<Map<String, dynamic>> _categories = [
    {'name': '인기', 'icon': '🔥'},
    {'name': '정치', 'icon': '🏛️'},
    {'name': '경제', 'icon': '💰'},
    {'name': '사회', 'icon': '👥'},
    {'name': '과학기술', 'icon': '🔬'},
    {'name': '문화', 'icon': '🎭'},
  ];

  @override
  void initState() {
    super.initState();

    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _appBarSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeInOut,
    ));

    _paddingAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _appBarAnimationController,
      curve: Curves.easeInOut,
    ));

    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
      _loadNews();
    });
  }

  void _handleScroll() {
    final currentScrollOffset = _scrollController.offset;
    const scrollThreshold = 50.0;

    if (currentScrollOffset > _lastScrollOffset &&
        currentScrollOffset > scrollThreshold) {
      if (_isAppBarVisible) {
        setState(() => _isAppBarVisible = false);
        _appBarAnimationController.forward();
      }
    } else if (currentScrollOffset < _lastScrollOffset) {
      if (!_isAppBarVisible) {
        setState(() => _isAppBarVisible = true);
        _appBarAnimationController.reverse();
      }
    }

    _lastScrollOffset = currentScrollOffset;
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _firestoreService.getUserFavorites();
      if (mounted) {
        setState(() {
          _favoriteNewsIds = favorites.toSet();
        });
      }
    } catch (e) {
      print('즐겨찾기 로드 실패: $e');
    }
  }

  Future<void> _loadNews() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_selectedCategory == '인기') {
        await _loadPopularNews();
      } else {
        final newsProvider = context.read<NewsProvider>();
        final newsList = await newsProvider.loadNews(category: _selectedCategory);

        if (mounted) {
          setState(() {
            _newsList = newsList;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('뉴스 로딩 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPopularNews() async {
    try {
      final popularDiscussions = await _firestoreService.getPopularDiscussions(limit: 10);

      if (popularDiscussions.isEmpty) {
        final newsProvider = context.read<NewsProvider>();
        final newsList = await newsProvider.loadNews(category: '전체');

        if (mounted) {
          setState(() {
            _newsList = newsList.take(10).toList();
          });
        }
        return;
      }

      final newsProvider = context.read<NewsProvider>();
      List<AutoCollectedNews> popularNewsList = [];

      for (var discussion in popularDiscussions) {
        final newsUrl = discussion['newsUrl'] as String;

        var news = newsProvider.getNewsByUrl(newsUrl);

        if (news == null) {
          news = AutoCollectedNews(
            title: discussion['title'] ?? '제목 없음',
            description: '자세한 내용을 보려면 클릭하세요',
            url: newsUrl,
            source: '뉴스 소스',
            publishedAt: DateTime.now(),
            autoCategory: '인기',
            autoTags: [],
          );
        }

        popularNewsList.add(news);
      }

      if (mounted) {
        setState(() {
          _newsList = popularNewsList;
        });
      }
    } catch (e) {
      print('인기 뉴스 로드 실패: $e');
      final newsProvider = context.read<NewsProvider>();
      final newsList = await newsProvider.loadNews(category: '전체');

      if (mounted) {
        setState(() {
          _newsList = newsList.take(10).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarContentHeight = screenWidth * 0.8;
    final totalAppBarHeight = topPadding + appBarContentHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _paddingAnimation,
                builder: (context, child) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: totalAppBarHeight * _paddingAnimation.value,
                    ),
                    child: child,
                  );
                },
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xD66B7280)),
                  ),
                )
                    : _buildNewsList(),
              ),

              SlideTransition(
                position: _appBarSlideAnimation,
                child: _buildAnimatedAppBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
                    size: screenWidth * 0.045,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.015),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.explore,
                  color: const Color(0xD66B7280),
                  size: screenWidth * 0.05,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Flexible(
                child: Text(
                  '뉴스 탐색',
                  style: TextStyle(
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: screenWidth * 0.06,
                ),
                onPressed: _loadNews,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.035),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: screenWidth * 0.035),
              decoration: InputDecoration(
                hintText: '관심 있는 뉴스 검색',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: screenWidth * 0.035,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                  size: screenWidth * 0.055,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenWidth * 0.035,
                ),
              ),
            ),
          ),
          SizedBox(height: screenWidth * 0.035),

          Row(
            children: [
              Expanded(
                child: _buildTabButton('실시간 뉴스', 0),
              ),
              SizedBox(width: screenWidth * 0.025),
              Expanded(
                child: _buildTabButton('논쟁 이슈', 1),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.035),

          SizedBox(
            height: screenWidth * 0.095,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['name'];

                return Padding(
                  padding: EdgeInsets.only(right: screenWidth * 0.02),
                  child: _buildCategoryChip(
                    category['name'],
                    category['icon'],
                    isSelected,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: screenWidth * 0.035,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xD66B7280) : Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String name, String icon, bool isSelected) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = name;
        });
        _loadNews();
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.035,
          vertical: screenWidth * 0.02,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: screenWidth * 0.035)),
            SizedBox(width: screenWidth * 0.015),
            Text(
              name,
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                color: isSelected ? const Color(0xD66B7280) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsList() {
    if (_newsList.isEmpty) {
      return _buildEmptyState();
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: const Color(0xD66B7280),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(screenWidth * 0.05),
        itemCount: _newsList.length,
        itemBuilder: (context, index) {
          return _buildNewsCard(_newsList[index], index);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.06),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.newspaper_outlined,
              size: screenWidth * 0.14,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: screenWidth * 0.05),
          Text(
            _selectedCategory == '인기' ? '아직 인기 뉴스가 없습니다' : '뉴스가 없습니다',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
            child: Text(
              _selectedCategory == '인기'
                  ? '댓글이 달린 뉴스가 아직 없습니다'
                  : '다른 카테고리를 선택하거나 새로고침해주세요',
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                color: const Color(0xFF666666),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: screenWidth * 0.06),
          ElevatedButton.icon(
            onPressed: _loadNews,
            icon: Icon(Icons.refresh, size: screenWidth * 0.045),
            label: Text(
              '새로고침',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xD66B7280),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenWidth * 0.03,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(AutoCollectedNews news, int index) {
    final newsId = news.url;
    final isFavorite = _favoriteNewsIds.contains(newsId);
    final newsCommentProvider = context.watch<NewsCommentProvider>();
    final commentCount = newsCommentProvider.getCommentCount(news.url);
    final participantCount = newsCommentProvider.getParticipantCount(news.url);
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => _showNewsDetailWithDiscussion(news),
      child: Container(
        margin: EdgeInsets.only(bottom: screenWidth * 0.035),
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
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Image.network(
                  news.imageUrl!,
                  width: double.infinity,
                  height: screenWidth * 0.4,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: screenWidth * 0.3,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: screenWidth * 0.1,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: EdgeInsets.all(screenWidth * 0.035),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.025,
                            vertical: screenWidth * 0.012,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xD66B7280),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCategory == '인기' ? '🔥' : '🔥',
                                style: TextStyle(fontSize: screenWidth * 0.027),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Flexible(
                                child: Text(
                                  news.autoCategory,
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.027,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Flexible(
                        child: Text(
                          news.source,
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: const Color(0xFF666666),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateTime(news.publishedAt),
                        style: TextStyle(
                          fontSize: screenWidth * 0.027,
                          color: const Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),

                  if (_selectedCategory == '인기' && index < 3)
                    Container(
                      margin: EdgeInsets.only(bottom: screenWidth * 0.02),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                        vertical: screenWidth * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? const Color(0xFFFFD700).withOpacity(0.2)
                            : index == 1
                            ? const Color(0xFFC0C0C0).withOpacity(0.2)
                            : const Color(0xFFCD7F32).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉',
                            style: TextStyle(fontSize: screenWidth * 0.035),
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            '${index + 1}위',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                              color: index == 0
                                  ? const Color(0xFFFFD700)
                                  : index == 1
                                  ? const Color(0xFF808080)
                                  : const Color(0xFFCD7F32),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  if (news.description.isNotEmpty)
                    Text(
                      news.description,
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: const Color(0xFF666666),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: screenWidth * 0.035),

                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStatBadge(
                              Icons.visibility_outlined,
                              '${(participantCount * 10 / 1000).toStringAsFixed(1)}K',
                            ),
                            SizedBox(width: screenWidth * 0.04),
                            _buildStatBadge(
                              Icons.chat_bubble_outline,
                              '$commentCount',
                              isHighlight: _selectedCategory == '인기',
                            ),
                            SizedBox(width: screenWidth * 0.04),
                            _buildStatBadge(
                              Icons.people_outline,
                              '$participantCount',
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _toggleFavorite(news),
                        child: Container(
                          padding: EdgeInsets.all(screenWidth * 0.02),
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? const Color(0xFFFFF9E6)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                            size: screenWidth * 0.05,
                            color: isFavorite
                                ? const Color(0xFFFFD700)
                                : Colors.grey.shade500,
                          ),
                        ),
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

  Widget _buildStatBadge(IconData icon, String value, {bool isHighlight = false}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: screenWidth * 0.04,
          color: isHighlight ? const Color(0xD66B7280) : const Color(0xFF888888),
        ),
        SizedBox(width: screenWidth * 0.01),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xD66B7280) : const Color(0xFF666666),
            fontSize: screenWidth * 0.032,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(AutoCollectedNews news) async {
    final newsUrl = news.url;

    try {
      if (_favoriteNewsIds.contains(newsUrl)) {
        await _firestoreService.removeFavorite(newsUrl);
        if (mounted) {
          setState(() => _favoriteNewsIds.remove(newsUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기에서 제거되었습니다'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (_favoriteNewsIds.length >= 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기는 최대 100개까지 가능합니다'),
              backgroundColor: AppColors.warningColor,
            ),
          );
          return;
        }

        await _firestoreService.addFavorite(
          newsUrl,
          title: news.title,
          description: news.description,
          imageUrl: news.imageUrl,
          source: news.source,
          publishedAt: news.publishedAt,
        );

        if (mounted) {
          setState(() => _favoriteNewsIds.add(newsUrl));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기에 추가되었습니다'),
              backgroundColor: AppColors.successColor,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _showNewsDetailWithDiscussion(AutoCollectedNews news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewsDetailWithDiscussion(news: news),
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
    _searchController.dispose();
    _scrollController.dispose();
    _appBarAnimationController.dispose();
    super.dispose();
  }
}

// ========== 뉴스 상세 + 토론 바텀시트 ==========

class NewsDetailWithDiscussion extends StatefulWidget {
  final AutoCollectedNews news;

  const NewsDetailWithDiscussion({super.key, required this.news});

  @override
  State<NewsDetailWithDiscussion> createState() => _NewsDetailWithDiscussionState();
}

class _NewsDetailWithDiscussionState extends State<NewsDetailWithDiscussion> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NewsComment> _comments = [];
  String? _userVote;
  Map<String, int> _voteStats = {'pro': 0, 'con': 0};

  bool _isSubmittingVote = false;
  bool _isSubmittingComment = false;
  bool _showCommentInput = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadComments(),
      _loadUserVote(),
      _loadVoteStats(),
    ]);
  }

  Future<void> _loadComments() async {
    final newsCommentProvider = context.read<NewsCommentProvider>();
    await newsCommentProvider.loadComments(widget.news.url);

    setState(() {
      _comments = newsCommentProvider.getComments(widget.news.url);
    });
  }

  Future<void> _loadUserVote() async {
    final firestoreService = FirestoreService();
    final vote = await firestoreService.getUserVote(widget.news.url);

    setState(() {
      _userVote = vote;
      _showCommentInput = vote != null;
    });
  }

  Future<void> _loadVoteStats() async {
    final firestoreService = FirestoreService();
    final stats = await firestoreService.getVoteStats(widget.news.url);

    setState(() {
      _voteStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
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
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNewsContent(),
                      Container(
                        height: 8,
                        color: const Color(0xFFF5F5F5),
                      ),
                      _buildVotingSection(),
                      Container(
                        height: 8,
                        color: const Color(0xFFF5F5F5),
                      ),
                      _buildDiscussionSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsContent() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.03,
              vertical: screenWidth * 0.015,
            ),
            decoration: BoxDecoration(
              color: const Color(0xD66B7280),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.news.autoCategory,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: screenWidth * 0.04),

          Text(
            widget.news.title,
            style: TextStyle(
              fontSize: screenWidth * 0.055,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
              height: 1.4,
            ),
          ),
          SizedBox(height: screenWidth * 0.03),

          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenWidth * 0.01,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.news.source,
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: const Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Icon(
                Icons.access_time,
                size: screenWidth * 0.035,
                color: Colors.grey.shade500,
              ),
              SizedBox(width: screenWidth * 0.01),
              Flexible(
                child: Text(
                  _formatDateTime(widget.news.publishedAt),
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: const Color(0xFF999999),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.05),

          Text(
            widget.news.description,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              height: 1.7,
              color: const Color(0xFF444444),
            ),
          ),
          SizedBox(height: screenWidth * 0.06),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.open_in_new, size: screenWidth * 0.045),
              label: Text(
                '원문 보기',
                style: TextStyle(fontSize: screenWidth * 0.037),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xD66B7280),
                side: const BorderSide(color: Color(0xD66B7280)),
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingSection() {
    final totalVotes = _voteStats['pro']! + _voteStats['con']!;
    final proPercentage = totalVotes > 0
        ? (_voteStats['pro']! / totalVotes * 100).round()
        : 0;
    final conPercentage = totalVotes > 0
        ? (_voteStats['con']! / totalVotes * 100).round()
        : 0;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.how_to_vote_outlined,
                color: const Color(0xD66B7280),
                size: screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.02),
              Flexible(
                child: Text(
                  '이 이슈에 대한 당신의 의견은?',
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
          SizedBox(height: screenWidth * 0.05),

          if (_userVote != null) ...[
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: const Color(0xD66B7280),
                        size: screenWidth * 0.05,
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Flexible(
                        child: Text(
                          '${_userVote == 'pro' ? '찬성' : '반대'}에 투표하셨습니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '총 $totalVotes표',
                        style: TextStyle(
                          fontSize: screenWidth * 0.032,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.04),

                  Row(
                    children: [
                      Expanded(
                        flex: _voteStats['pro']! > 0 ? _voteStats['pro']! : 1,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xD66B7280),
                            borderRadius: totalVotes == 0 || _voteStats['con']! == 0
                                ? BorderRadius.circular(4)
                                : const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      if (_voteStats['con']! > 0)
                        Expanded(
                          flex: _voteStats['con']!,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF888888),
                              borderRadius: _voteStats['pro']! == 0
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: screenWidth * 0.03,
                              height: screenWidth * 0.03,
                              decoration: const BoxDecoration(
                                color: Color(0xD66B7280),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.015),
                            Flexible(
                              child: Text(
                                '찬성 $proPercentage% (${_voteStats['pro']}표)',
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
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: screenWidth * 0.03,
                              height: screenWidth * 0.03,
                              decoration: const BoxDecoration(
                                color: Color(0xFF888888),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.015),
                            Flexible(
                              child: Text(
                                '반대 $conPercentage% (${_voteStats['con']}표)',
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
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: screenWidth * 0.03),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showChangeVoteDialog(),
                icon: Icon(Icons.swap_horiz, size: screenWidth * 0.045),
                label: Text(
                  '입장 변경하기',
                  style: TextStyle(fontSize: screenWidth * 0.037),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF666666),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.03),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildVoteButton(
                    label: '찬성',
                    icon: Icons.thumb_up_outlined,
                    stance: 'pro',
                    color: const Color(0xD66B7280),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                Expanded(
                  child: _buildVoteButton(
                    label: '반대',
                    icon: Icons.thumb_down_outlined,
                    stance: 'con',
                    color: const Color(0xFF888888),
                  ),
                ),
              ],
            ),
            SizedBox(height: screenWidth * 0.04),

            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFFF57C00),
                    size: screenWidth * 0.045,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      '투표 후 댓글을 작성할 수 있습니다',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoteButton({
    required String label,
    required IconData icon,
    required String stance,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return ElevatedButton(
      onPressed: _isSubmittingVote ? null : () => _submitVote(stance),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: _isSubmittingVote
          ? SizedBox(
        width: screenWidth * 0.05,
        height: screenWidth * 0.05,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: screenWidth * 0.05),
          SizedBox(width: screenWidth * 0.02),
          Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionSection() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                color: const Color(0xD66B7280),
                size: screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                '토론',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenWidth * 0.01,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD66B7280).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: const Color(0xD66B7280),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.05),

          if (_showCommentInput) ...[
            _buildCommentInput(),
            SizedBox(height: screenWidth * 0.06),
          ],

          if (_comments.isEmpty)
            _buildEmptyComments()
          else
            ..._comments.map((comment) => _buildCommentItem(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final stanceLabel = _userVote == 'pro' ? '찬성' : '반대';
    final stanceColor = _userVote == 'pro'
        ? const Color(0xD66B7280)
        : const Color(0xFF888888);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.025,
              vertical: screenWidth * 0.015,
            ),
            decoration: BoxDecoration(
              color: stanceColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stanceColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _userVote == 'pro'
                      ? Icons.thumb_up
                      : Icons.thumb_down,
                  size: screenWidth * 0.04,
                  color: stanceColor,
                ),
                SizedBox(width: screenWidth * 0.015),
                Text(
                  '$stanceLabel 의견',
                  style: TextStyle(
                    fontSize: screenWidth * 0.032,
                    color: stanceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenWidth * 0.03),

          TextField(
            controller: _commentController,
            maxLines: 3,
            style: TextStyle(fontSize: screenWidth * 0.037),
            decoration: InputDecoration(
              hintText: '$stanceLabel 의견을 작성해주세요...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: screenWidth * 0.035,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xD66B7280), width: 2),
              ),
              contentPadding: EdgeInsets.all(screenWidth * 0.035),
            ),
          ),
          SizedBox(height: screenWidth * 0.03),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: stanceColor,
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSubmittingComment
                  ? SizedBox(
                width: screenWidth * 0.05,
                height: screenWidth * 0.05,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                '의견 작성',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: screenWidth * 0.037,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.08),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: screenWidth * 0.12,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            '첫 번째 의견을 남겨보세요!',
            style: TextStyle(
              fontSize: screenWidth * 0.037,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(NewsComment comment) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(bottom: screenWidth * 0.03),
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: comment.isPro
              ? const Color(0xD66B7280).withOpacity(0.3)
              : const Color(0xFF888888).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.025,
                  vertical: screenWidth * 0.012,
                ),
                decoration: BoxDecoration(
                  color: comment.isPro
                      ? const Color(0xD66B7280)
                      : const Color(0xFF888888),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comment.isPro
                          ? Icons.thumb_up
                          : Icons.thumb_down,
                      size: screenWidth * 0.03,
                      color: Colors.white,
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    Text(
                      comment.isPro ? '찬성' : '반대',
                      style: TextStyle(
                        fontSize: screenWidth * 0.027,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenWidth * 0.025),
              Flexible(
                child: Text(
                  comment.nickname,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.035,
                    color: const Color(0xFF333333),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(comment.createdAt),
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: const Color(0xFF999999),
                ),
              ),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            comment.content,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              height: 1.5,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitVote(String stance) async {
    setState(() => _isSubmittingVote = true);

    try {
      final firestoreService = FirestoreService();

      await firestoreService.vote(
        newsUrl: widget.news.url,
        stance: stance,
        newsTitle: widget.news.title,
        newsDescription: widget.news.description,
        newsImageUrl: widget.news.imageUrl,
        newsSource: widget.news.source,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${stance == 'pro' ? '찬성' : '반대'}에 투표했습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('투표 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSubmittingVote = false);
    }
  }

  void _showChangeVoteDialog() {
    final currentStance = _userVote == 'pro' ? '찬성' : '반대';
    final newStance = _userVote == 'pro' ? 'con' : 'pro';
    final newStanceLabel = newStance == 'pro' ? '찬성' : '반대';
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '입장 변경',
          style: TextStyle(fontSize: screenWidth * 0.045),
        ),
        content: Text(
          '$currentStance에서 $newStanceLabel으로 입장을 변경하시겠습니까?',
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
            onPressed: () {
              Navigator.pop(context);
              _submitVote(newStance);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xD66B7280),
            ),
            child: Text(
              '변경',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('의견을 입력해주세요')),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final newsCommentProvider = context.read<NewsCommentProvider>();

      final newComment = NewsComment(
        id: DateTime.now().millisecondsSinceEpoch,
        newsUrl: widget.news.url,
        nickname: authProvider.nickname,
        stance: _userVote!,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await newsCommentProvider.addComment(
        widget.news.url,
        newComment,
        newsTitle: widget.news.title,
        newsDescription: widget.news.description,
        newsImageUrl: widget.news.imageUrl,
        newsSource: widget.news.source,
      );

      setState(() => _commentController.clear());
      await _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('의견이 등록되었습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('의견 등록 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inMinutes < 60) return '${difference.inMinutes}분 전';
    if (difference.inHours < 24) return '${difference.inHours}시간 전';
    return '${dateTime.month}/${dateTime.day}';
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class NewsComment {
  final int id;
  final String newsUrl;
  final String nickname;
  final String stance;
  final String content;
  final DateTime createdAt;

  NewsComment({
    required this.id,
    required this.newsUrl,
    required this.nickname,
    required this.stance,
    required this.content,
    required this.createdAt,
  });

  bool get isPro => stance == 'pro';
}