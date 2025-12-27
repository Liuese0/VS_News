// lib/screens/news_explorer_screen.dart (완전 통합 버전)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/models.dart';
import '../services/news_auto_service.dart';
import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';
import '../providers/news_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_service.dart';
import 'web_view_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final NewsAutoService _newsService = NewsAutoService();
  final FirestoreService _firestoreService = FirestoreService();
  final AdService _adService = AdService();
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
  bool _isLoadingMore = false;
  Set<String> _favoriteNewsIds = <String>{};
  List<String> _popularNewsUrls = []; // 카테고리별 인기 뉴스 URL 추적 (순서 유지)

  // 페이지네이션 (인기 뉴스용)
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  static const int _pageSize = 10;

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

    // 광고 미리 로드
    _adService.preloadAd();

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

    // AppBar 숨김/표시 로직
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

    // 페이지네이션: 모든 카테고리에서 지원
    // 스크롤이 80% 이상 도달하면 다음 페이지 로드
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      if (_selectedCategory == '인기') {
        // 인기 뉴스는 Firestore 페이지네이션
        if (_hasMore) {
          _loadMorePopularNews();
        }
      } else {
        // 나머지 카테고리는 NewsProvider 페이지네이션
        final newsProvider = context.read<NewsProvider>();
        if (newsProvider.hasMore(_selectedCategory)) {
          _loadMoreCategoryNews();
        }
      }
    }
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

    setState(() {
      _isLoading = true;
      _newsList.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      if (_selectedCategory == '인기') {
        await _loadPopularNews();
      } else {
        await _loadCategoryNewsInitial();
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
      final result = await _firestoreService.getPopularDiscussions(
        limit: _pageSize,
        lastDocument: null,
      );

      final popularDiscussions = result['discussions'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;

      if (popularDiscussions.isEmpty) {
        // 인기 뉴스가 없으면 일반 뉴스 표시
        final newsProvider = context.read<NewsProvider>();
        final newsList = await newsProvider.loadNews(category: '전체');

        if (mounted) {
          setState(() {
            _newsList = newsList.take(_pageSize).toList();
            _hasMore = false;
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
          // 뉴스 메타데이터가 newsStats에 저장되어 있음
          news = AutoCollectedNews(
            title: discussion['title'] ?? '제목 없음',
            description: discussion['description'] ?? '자세한 내용을 보려면 클릭하세요',
            url: newsUrl,
            source: discussion['source'] ?? '뉴스',
            imageUrl: discussion['imageUrl'],
            publishedAt: (discussion['lastCommentTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            autoCategory: '인기',
            autoTags: [],
          );
        }

        popularNewsList.add(news);
      }

      if (mounted) {
        setState(() {
          _newsList = popularNewsList;
          // '인기' 카테고리에서는 상위 3개를 인기 뉴스로 표시
          _popularNewsUrls = popularNewsList.take(3).map((news) => news.url).toList();
        });
      }
    } catch (e) {
      print('인기 뉴스 로드 실패: $e');
      // 실패 시 일반 뉴스로 대체
      final newsProvider = context.read<NewsProvider>();
      final newsList = await newsProvider.loadNews(category: '전체');

      if (mounted) {
        setState(() {
          _newsList = newsList.take(_pageSize).toList();
          _hasMore = false;
          _popularNewsUrls.clear();
        });
      }
    }
  }

  Future<void> _loadMorePopularNews() async {
    if (_isLoadingMore || !_hasMore || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await _firestoreService.getPopularDiscussions(
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      final popularDiscussions = result['discussions'] as List<Map<String, dynamic>>;
      _lastDocument = result['lastDocument'] as DocumentSnapshot?;
      _hasMore = result['hasMore'] as bool;

      if (popularDiscussions.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }

      final newsProvider = context.read<NewsProvider>();
      List<AutoCollectedNews> additionalNews = [];

      for (var discussion in popularDiscussions) {
        final newsUrl = discussion['newsUrl'] as String;

        var news = newsProvider.getNewsByUrl(newsUrl);

        if (news == null) {
          news = AutoCollectedNews(
            title: discussion['title'] ?? '제목 없음',
            description: discussion['description'] ?? '자세한 내용을 보려면 클릭하세요',
            url: newsUrl,
            source: discussion['source'] ?? '뉴스',
            imageUrl: discussion['imageUrl'],
            publishedAt: (discussion['lastCommentTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
            autoCategory: '인기',
            autoTags: [],
          );
        }

        additionalNews.add(news);
      }

      if (mounted) {
        setState(() {
          _newsList.addAll(additionalNews);
        });
      }
    } catch (e) {
      print('추가 뉴스 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadCategoryNewsInitial() async {
    try {
      final newsProvider = context.read<NewsProvider>();
      final newsList = await newsProvider.loadNews(category: _selectedCategory);

      if (newsList.isEmpty) {
        if (mounted) {
          setState(() {
            _newsList = [];
            _popularNewsUrls.clear();
          });
        }
        return;
      }

      // 각 뉴스의 통계 정보를 배치로 가져오기
      final newsUrls = newsList.map((news) => news.url).toList();
      final statsMap = await _firestoreService.getBatchNewsStats(newsUrls);

      // commentCount 기준으로 정렬하여 상위 3개 추출
      final newsWithStats = newsList.map((news) {
        final stats = statsMap[news.url] ?? {'commentCount': 0};
        return {
          'news': news,
          'commentCount': stats['commentCount'] as int,
        };
      }).toList();

      // commentCount 기준 내림차순 정렬
      newsWithStats.sort((a, b) {
        final aCount = (a['commentCount'] ?? 0) as int;
        final bCount = (b['commentCount'] ?? 0) as int;
        return bCount.compareTo(aCount);
      });


      // 상위 3개 추출
      final topThree = newsWithStats.take(3).map((item) => item['news'] as AutoCollectedNews).toList();
      final topThreeUrls = topThree.map((news) => news.url).toList();

      // 나머지는 publishedAt 기준으로 정렬
      final remaining = newsWithStats.skip(3).map((item) => item['news'] as AutoCollectedNews).toList();
      remaining.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // 최종 리스트: 인기 3개 + 나머지
      final sortedNewsList = [...topThree, ...remaining];

      if (mounted) {
        setState(() {
          _newsList = sortedNewsList;
          _popularNewsUrls = topThreeUrls;
        });
      }
    } catch (e) {
      print('카테고리 뉴스 로드 실패: $e');
      if (mounted) {
        setState(() {
          _newsList = [];
          _popularNewsUrls.clear();
        });
      }
    }
  }

  Future<void> _loadMoreCategoryNews() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newsProvider = context.read<NewsProvider>();
      final newNews = await newsProvider.loadMoreNews(_selectedCategory);

      if (mounted && newNews.isNotEmpty) {
        setState(() {
          _newsList.addAll(newNews);
        });
      }

      print('카테고리 뉴스 추가 로드 완료: +${newNews.length}개, 총 ${_newsList.length}개');
    } catch (e) {
      print('카테고리 뉴스 추가 로딩 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
    final appBarContentHeight = screenWidth * 0.55;
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

  Widget _buildBannerAd() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (!_adService.isExploreBannerAdLoaded || _adService.exploreBannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        top: 45,
        bottom: 10,
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
          child: AdWidget(ad: _adService.exploreBannerAd!),
        ),
      ),
    );
  }

  Widget _buildNewsList() {
    if (_newsList.isEmpty) {
      return _buildEmptyState();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final newsProvider = context.watch<NewsProvider>();
    final hasMore = _selectedCategory == '인기'
        ? _hasMore
        : newsProvider.hasMore(_selectedCategory);

    // 배너 개수 계산: 맨 위 1개 + 10개마다 1개
    final totalBanners = 1 + (_newsList.length / 10).floor();
    final totalItems = _newsList.length + totalBanners + 1; // 뉴스 + 배너들 + 로딩/완료

    return RefreshIndicator(
      onRefresh: _loadNews,
      color: const Color(0xD66B7280),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: screenWidth * 0.05,
          right: screenWidth * 0.05,
          top: 0,
          bottom: screenWidth * 0.05,
        ),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          // 맨 위 배너 광고
          if (index == 0) {
            return _buildBannerAd();
          }

          // 로딩/완료 인디케이터를 마지막에 표시
          if (index == totalItems - 1) {
            if (_isLoadingMore) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.05),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xD66B7280)),
                  ),
                ),
              );
            } else if (!hasMore && _newsList.isNotEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                child: Center(
                  child: Text(
                    '모든 뉴스를 불러왔습니다',
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: const Color(0xFF999999),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          // 10개마다 중간 배너 광고 표시
          // index가 11, 22, 33, ... 위치일 때 배너
          int positionAfterFirstBanner = index - 1;
          if (positionAfterFirstBanner % 11 == 10) {
            return _buildBannerAd();
          }

          // 실제 뉴스 아이템 인덱스 계산
          int additionalBanners = positionAfterFirstBanner ~/ 11;
          int newsIndex = positionAfterFirstBanner - additionalBanners;

          return _buildNewsCard(_newsList[newsIndex], newsIndex);
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
                  Builder(
                    builder: (context) {
                      // 인기 뉴스인지 확인하고 순위 가져오기
                      final rankIndex = _popularNewsUrls.indexOf(news.url);
                      if (rankIndex != -1) {
                        // 순위가 있는 경우 (0=1위, 1=2위, 2=3위)
                        return Container(
                          margin: EdgeInsets.only(bottom: screenWidth * 0.02),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.02,
                            vertical: screenWidth * 0.01,
                          ),
                          decoration: BoxDecoration(
                            color: rankIndex == 0
                                ? const Color(0xFFFFD700).withOpacity(0.2)
                                : rankIndex == 1
                                ? const Color(0xFFC0C0C0).withOpacity(0.2)
                                : const Color(0xFFCD7F32).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                rankIndex == 0 ? '🥇' : rankIndex == 1 ? '🥈' : '🥉',
                                style: TextStyle(fontSize: screenWidth * 0.035),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                '${rankIndex + 1}위',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  fontWeight: FontWeight.bold,
                                  color: rankIndex == 0
                                      ? const Color(0xFFFFD700)
                                      : rankIndex == 1
                                      ? const Color(0xFF808080)
                                      : const Color(0xFFCD7F32),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
        if (_favoriteNewsIds.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('즐겨찾기는 최대 10개까지 가능합니다'),
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

// ========== 뉴스 상세 + 토론 바텀시트 (기존 코드 그대로 유지) ==========

class NewsDetailWithDiscussion extends StatefulWidget {
  final AutoCollectedNews news;

  const NewsDetailWithDiscussion({super.key, required this.news});

  @override
  State<NewsDetailWithDiscussion> createState() => _NewsDetailWithDiscussionState();
}

class _NewsDetailWithDiscussionState extends State<NewsDetailWithDiscussion> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<NewsComment> _comments = [];
  String? _userVote;
  Map<String, int> _voteStats = {'pro': 0, 'neutral': 0, 'con': 0};

  bool _isSubmittingVote = false;
  bool _isSubmittingComment = false;
  bool _showCommentInput = false;

  String? _replyingToCommentId;
  String? _replyingToNickname;

  // 아이템 사용 플래그
  bool _useSpeakingRight = false;
  bool _useSpeakingExtension = false;

  // 댓글 필터 상태: 'all', 'pro', 'con'
  String _selectedStanceFilter = 'all';

  // 요약 관련 상태
  bool _isLoadingSummary = false;
  String? _summary;
  bool _showSummary = false;

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
    try {
      final firestoreService = FirestoreService();
      final commentsData = await firestoreService.getComments(widget.news.url);

      setState(() {
        _comments = commentsData.map((data) {
          final createdAt = data['createdAt'];

          final repliesData = data['replies'] as List<dynamic>? ?? [];
          final replies = repliesData.map((replyData) {
            final replyCreatedAt = replyData['createdAt'];
            return NewsComment(
              id: replyData['id'],
              newsUrl: widget.news.url,
              nickname: replyData['nickname'] ?? '익명',
              stance: replyData['stance'] ?? 'pro',
              content: replyData['content'] ?? '',
              createdAt: replyCreatedAt is Timestamp
                  ? replyCreatedAt.toDate()
                  : DateTime.now(),
              parentId: replyData['parentId'],
              depth: replyData['depth'] ?? 1,
              replyCount: 0,
            );
          }).toList();

          return NewsComment(
            id: data['id'],
            newsUrl: widget.news.url,
            nickname: data['nickname'] ?? '익명',
            stance: data['stance'] ?? 'pro',
            content: data['content'] ?? '',
            createdAt: createdAt is Timestamp
                ? createdAt.toDate()
                : DateTime.now(),
            parentId: data['parentId'],
            depth: data['depth'] ?? 0,
            replyCount: data['replyCount'] ?? 0,
            replies: replies,
          );
        }).toList();
      });
    } catch (e) {
      print('댓글 로드 실패: $e');
    }
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

  Future<void> _generateSummary() async {
    if (_isLoadingSummary) return;

    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final summary = await GeminiService.summarizeNews(
        title: widget.news.title,
        description: widget.news.description,
        url: widget.news.url,
        category: widget.news.autoCategory,
      );

      setState(() {
        _summary = summary;
        _showSummary = true;
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSummary = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('요약 생성 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openWebView() {
    String url = widget.news.url;

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('뉴스 링크가 없습니다'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: url,
          title: widget.news.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      _buildNewsDetailBannerAd(),
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
          // 원문 보기 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openWebView,
              icon: Icon(Icons.open_in_browser, size: screenWidth * 0.045),
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
          SizedBox(height: screenWidth * 0.03),
          // 요약하기 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingSummary ? null : _generateSummary,
              icon: _isLoadingSummary
                  ? SizedBox(
                width: screenWidth * 0.045,
                height: screenWidth * 0.045,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xD66B7280),
                  ),
                ),
              )
                  : Icon(Icons.auto_awesome, size: screenWidth * 0.045),
              label: Text(
                _isLoadingSummary ? '요약 생성 중...' : '요약하기',
                style: TextStyle(fontSize: screenWidth * 0.037),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xD68B5CF6),
                side: const BorderSide(color: Color(0xD68B5CF6)),
                padding: EdgeInsets.symmetric(vertical: screenWidth * 0.035),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // 요약 내용 표시
          if (_showSummary && _summary != null) ...[
            SizedBox(height: screenWidth * 0.04),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xD68B5CF6),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: screenWidth * 0.04,
                            color: const Color(0xD68B5CF6),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            'AI 요약',
                            style: TextStyle(
                              fontSize: screenWidth * 0.038,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xD68B5CF6),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: screenWidth * 0.045,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showSummary = false;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  SizedBox(height: screenWidth * 0.03),
                  Text(
                    _summary!,
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      height: 1.6,
                      color: const Color(0xFF444444),
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

  Widget _buildVotingSection() {
    final totalVotes = _voteStats['pro']! + _voteStats['neutral']! + _voteStats['con']!;
    final proPercentage = totalVotes > 0
        ? (_voteStats['pro']! / totalVotes * 100).round()
        : 0;
    final neutralPercentage = totalVotes > 0
        ? (_voteStats['neutral']! / totalVotes * 100).round()
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
                          '${_userVote == 'pro' ? '찬성' : _userVote == 'neutral' ? '중립' : '반대'}에 투표하셨습니다',
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
                      if (_voteStats['pro']! > 0)
                        Expanded(
                          flex: _voteStats['pro']!,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: _voteStats['neutral']! == 0 && _voteStats['con']! == 0
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      if (_voteStats['neutral']! > 0)
                        Expanded(
                          flex: _voteStats['neutral']!,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: _voteStats['pro']! == 0 && _voteStats['con']! == 0
                                  ? BorderRadius.circular(4)
                                  : BorderRadius.zero,
                            ),
                          ),
                        ),
                      if (_voteStats['con']! > 0)
                        Expanded(
                          flex: _voteStats['con']!,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: _voteStats['pro']! == 0 && _voteStats['neutral']! == 0
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      if (totalVotes == 0)
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(4),
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
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Flexible(
                              child: Text(
                                '찬성 $proPercentage% (${_voteStats['pro']})',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
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
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Flexible(
                              child: Text(
                                '중립 $neutralPercentage% (${_voteStats['neutral']})',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
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
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Flexible(
                              child: Text(
                                '반대 $conPercentage% (${_voteStats['con']})',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.028,
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
                    color: Colors.green,
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildVoteButton(
                    label: '중립',
                    icon: Icons.remove_outlined,
                    stance: 'neutral',
                    color: Colors.orange,
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: _buildVoteButton(
                    label: '반대',
                    icon: Icons.thumb_down_outlined,
                    stance: 'con',
                    color: Colors.red,
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

  Widget _buildNewsDetailBannerAd() {
    final screenWidth = MediaQuery.of(context).size.width;
    final adService = AdService();

    if (!adService.isNewsDetailBannerAdLoaded || adService.newsDetailBannerAd == null) {
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
          child: AdWidget(ad: adService.newsDetailBannerAd!),
        ),
      ),
    );
  }

  // 필터링된 댓글 목록 (대댓글 제외)
  List<NewsComment> get _filteredComments {
    // 부모 댓글만 필터링 (대댓글 제외)
    final parentComments = _comments.where((comment) => !comment.isReply).toList();

    if (_selectedStanceFilter == 'all') {
      return parentComments;
    } else if (_selectedStanceFilter == 'pro') {
      return parentComments.where((comment) => comment.isPro).toList();
    } else if (_selectedStanceFilter == 'neutral') {
      return parentComments.where((comment) => comment.isNeutral).toList();
    } else if (_selectedStanceFilter == 'con') {
      return parentComments.where((comment) => comment.isCon).toList();
    }

    return parentComments;
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
          SizedBox(height: screenWidth * 0.03),
          // 댓글 필터 버튼
          Row(
            children: [
              _buildFilterButton('전체', 'all', screenWidth),
              SizedBox(width: screenWidth * 0.02),
              _buildFilterButton('찬성', 'pro', screenWidth),
              SizedBox(width: screenWidth * 0.02),
              _buildFilterButton('중립', 'neutral', screenWidth),
              SizedBox(width: screenWidth * 0.02),
              _buildFilterButton('반대', 'con', screenWidth),
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          FutureBuilder<int>(
            future: FirestoreService().getTodayCommentCount(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final todayCount = snapshot.data!;
              final remaining = 5 - todayCount;

              if (remaining <= 0) {
                return Container(
                  margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF5350)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: const Color(0xFFEF5350),
                        size: screenWidth * 0.045,
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Text(
                          '오늘의 댓글 작성 제한(5개)에 도달했습니다',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: const Color(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: EdgeInsets.only(bottom: screenWidth * 0.04),
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: remaining <= 2
                      ? const Color(0xFFFFF9E6)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: remaining <= 2
                        ? const Color(0xFFFFE082)
                        : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      remaining <= 2 ? Icons.warning_amber : Icons.info_outline,
                      color: remaining <= 2
                          ? const Color(0xFFF57C00)
                          : const Color(0xFF66BB6A),
                      size: screenWidth * 0.045,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '오늘 댓글 ${remaining}개 남음 (최대 50자)',
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_showCommentInput) ...[
            if (_replyingToCommentId != null)
              _buildCommentInput(
                parentId: _replyingToCommentId,
                parentNickname: _replyingToNickname,
              )
            else
              _buildCommentInput(),
            SizedBox(height: screenWidth * 0.06),
          ],
          if (_filteredComments.isEmpty)
            _buildEmptyComments()
          else
            ..._filteredComments.map((comment) => _buildCommentItem(comment)),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String filterValue, double screenWidth) {
    final isSelected = _selectedStanceFilter == filterValue;

    // 각 필터별 색상 설정
    Color buttonColor;
    Color textColor;
    if (filterValue == 'pro') {
      buttonColor = isSelected ? const Color(0xFF3B82F6) : Colors.white;
      textColor = isSelected ? Colors.white : const Color(0xFF3B82F6);
    } else if (filterValue == 'neutral') {
      buttonColor = isSelected ? const Color(0xFFFF9800) : Colors.white;
      textColor = isSelected ? Colors.white : const Color(0xFFFF9800);
    } else if (filterValue == 'con') {
      buttonColor = isSelected ? const Color(0xFFEF4444) : Colors.white;
      textColor = isSelected ? Colors.white : const Color(0xFFEF4444);
    } else {
      buttonColor = isSelected ? const Color(0xD66B7280) : Colors.white;
      textColor = isSelected ? Colors.white : const Color(0xD66B7280);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStanceFilter = filterValue;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: screenWidth * 0.025,
          ),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: filterValue == 'pro'
                  ? const Color(0xFF3B82F6)
                  : filterValue == 'neutral'
                  ? const Color(0xFFFF9800)
                  : filterValue == 'con'
                  ? const Color(0xFFEF4444)
                  : const Color(0xD66B7280),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.035,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentInput({String? parentId, String? parentNickname}) {
    final stanceLabel = _userVote == 'pro' ? '찬성' : _userVote == 'neutral' ? '중립' : '반대';
    final stanceColor = _userVote == 'pro'
        ? Colors.green
        : _userVote == 'neutral'
        ? Colors.orange
        : Colors.red;
    final screenWidth = MediaQuery.of(context).size.width;

    final controller = parentId != null ? _replyController : _commentController;
    final isReplying = parentId != null;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isReplying
              ? const Color(0xD66B7280).withOpacity(0.3)
              : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                          : _userVote == 'neutral'
                          ? Icons.remove
                          : Icons.thumb_down,
                      size: screenWidth * 0.04,
                      color: stanceColor,
                    ),
                    SizedBox(width: screenWidth * 0.015),
                    Text(
                      isReplying ? '답글 작성' : '$stanceLabel 의견',
                      style: TextStyle(
                        fontSize: screenWidth * 0.032,
                        color: stanceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReplying) ...[
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: Text(
                    '@$parentNickname',
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      color: const Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: screenWidth * 0.045,
                  onPressed: () {
                    setState(() {
                      _replyingToCommentId = null;
                      _replyingToNickname = null;
                    });
                    _replyController.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          SizedBox(height: screenWidth * 0.03),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final length = value.text.length;
              final isOver50 = length > 50;
              final isOver100 = length > 100;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 100,
                    style: TextStyle(fontSize: screenWidth * 0.037),
                    decoration: InputDecoration(
                      hintText: isReplying
                          ? '$parentNickname님에게 답글...'
                          : '$stanceLabel 의견을 작성해주세요...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: screenWidth * 0.035,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isOver100
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isOver100
                              ? Colors.red
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isOver100
                              ? Colors.red
                              : const Color(0xD66B7280),
                          width: 2,
                        ),
                      ),
                      counterText: '',
                      contentPadding: EdgeInsets.all(screenWidth * 0.035),
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.02),
                  Row(
                    children: [
                      Text(
                        '$length/50${isOver50 ? ' (+${length - 50})' : ''}',
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: isOver100
                              ? Colors.red
                              : isOver50
                              ? Colors.orange
                              : length > 40
                              ? Colors.orange.shade300
                              : Colors.grey,
                          fontWeight: isOver50 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isOver100) ...[
                        SizedBox(width: screenWidth * 0.02),
                        Icon(
                          Icons.error_outline,
                          size: screenWidth * 0.04,
                          color: Colors.red,
                        ),
                        SizedBox(width: screenWidth * 0.01),
                        Text(
                          '최대 100자',
                          style: TextStyle(
                            fontSize: screenWidth * 0.028,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
          // 아이템 사용 옵션
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final userInfo = authProvider.userInfo ?? {};
              final speakingExtensionCount = userInfo['speakingExtensionCount'] ?? 0;
              final textLength = controller.text.length;
              final needsExtension = textLength > 50 && textLength <= 100;

              if (!needsExtension) return const SizedBox.shrink();

              return Column(
                children: [
                  SizedBox(height: screenWidth * 0.02),
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.03),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _useSpeakingExtension,
                          onChanged: speakingExtensionCount > 0
                              ? (value) {
                                  setState(() {
                                    _useSpeakingExtension = value ?? false;
                                  });
                                }
                              : null,
                          activeColor: const Color(0xFF2196F3),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '발언연장권 사용 (50글자 추가)',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.bold,
                                  color: speakingExtensionCount > 0
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey,
                                ),
                              ),
                              Text(
                                '보유: $speakingExtensionCount개',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  color: speakingExtensionCount > 0
                                      ? const Color(0xFF666666)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: screenWidth * 0.03),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingComment
                  ? null
                  : () => isReplying
                  ? _submitReply(parentId!)
                  : _submitComment(),
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
                isReplying ? '답글 작성' : '의견 작성',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: comment.isPro
                    ? Colors.green.withOpacity(0.3)
                    : comment.isNeutral
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
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
                            ? Colors.green
                            : comment.isNeutral
                            ? Colors.orange
                            : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            comment.isPro
                                ? Icons.thumb_up
                                : comment.isNeutral
                                ? Icons.remove
                                : Icons.thumb_down,
                            size: screenWidth * 0.03,
                            color: Colors.white,
                          ),
                          SizedBox(width: screenWidth * 0.01),
                          Text(
                            comment.isPro ? '찬성' : comment.isNeutral ? '중립' : '반대',
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
                SizedBox(height: screenWidth * 0.025),
                Row(
                  children: [
                    if (comment.replyCount > 0)
                      Container(
                        margin: EdgeInsets.only(right: screenWidth * 0.02),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: screenWidth * 0.01,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right,
                              size: screenWidth * 0.035,
                              color: const Color(0xFF666666),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              '답글 ${comment.replyCount}',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _userVote == null
                          ? null
                          : () {
                        setState(() {
                          _replyingToCommentId = comment.id;
                          _replyingToNickname = comment.nickname;
                        });
                      },
                      icon: Icon(
                        Icons.reply,
                        size: screenWidth * 0.04,
                      ),
                      label: Text(
                        '답글',
                        style: TextStyle(fontSize: screenWidth * 0.032),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xD66B7280),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.02,
                          vertical: screenWidth * 0.01,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: screenWidth * 0.08,
                top: screenWidth * 0.02,
              ),
              child: Column(
                children: comment.replies.map((reply) {
                  return Container(
                    margin: EdgeInsets.only(bottom: screenWidth * 0.02),
                    padding: EdgeInsets.all(screenWidth * 0.035),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: reply.isPro
                            ? Colors.green.withOpacity(0.2)
                            : reply.isNeutral
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right,
                              size: screenWidth * 0.035,
                              color: const Color(0xFF999999),
                            ),
                            SizedBox(width: screenWidth * 0.015),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.02,
                                vertical: screenWidth * 0.008,
                              ),
                              decoration: BoxDecoration(
                                color: reply.isPro
                                    ? Colors.green.withOpacity(0.1)
                                    : reply.isNeutral
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                reply.isPro ? '찬성' : reply.isNeutral ? '중립' : '반대',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.025,
                                  color: reply.isPro
                                      ? Colors.green
                                      : reply.isNeutral
                                      ? Colors.orange
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Flexible(
                              child: Text(
                                reply.nickname,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.032,
                                  color: const Color(0xFF333333),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDateTime(reply.createdAt),
                              style: TextStyle(
                                fontSize: screenWidth * 0.028,
                                color: const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenWidth * 0.025),
                        Text(
                          reply.content,
                          style: TextStyle(
                            fontSize: screenWidth * 0.032,
                            height: 1.5,
                            color: const Color(0xFF444444),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
    final currentStance = _userVote == 'pro' ? '찬성' : _userVote == 'neutral' ? '중립' : '반대';
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '입장 변경',
          style: TextStyle(fontSize: screenWidth * 0.045, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 입장: $currentStance',
              style: TextStyle(
                fontSize: screenWidth * 0.037,
                color: const Color(0xFF666666),
              ),
            ),
            SizedBox(height: screenWidth * 0.04),
            Text(
              '변경할 입장을 선택해주세요:',
              style: TextStyle(
                fontSize: screenWidth * 0.037,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: screenWidth * 0.03),
            if (_userVote != 'pro')
              _buildStanceOption(
                label: '찬성',
                icon: Icons.thumb_up_outlined,
                stance: 'pro',
                color: Colors.green,
                screenWidth: screenWidth,
              ),
            if (_userVote != 'neutral')
              _buildStanceOption(
                label: '중립',
                icon: Icons.remove_outlined,
                stance: 'neutral',
                color: Colors.orange,
                screenWidth: screenWidth,
              ),
            if (_userVote != 'con')
              _buildStanceOption(
                label: '반대',
                icon: Icons.thumb_down_outlined,
                stance: 'con',
                color: Colors.red,
                screenWidth: screenWidth,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(fontSize: screenWidth * 0.037),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStanceOption({
    required String label,
    required IconData icon,
    required String stance,
    required Color color,
    required double screenWidth,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _submitVote(stance);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: screenWidth * 0.02),
        padding: EdgeInsets.all(screenWidth * 0.03),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: screenWidth * 0.05),
            SizedBox(width: screenWidth * 0.03),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

    final contentLength = _commentController.text.trim().length;
    if (contentLength > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('댓글은 최대 100자까지 작성 가능합니다'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    // 50자 초과 시 발언연장권 확인
    if (contentLength > 50 && !_useSpeakingExtension) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('50자를 초과하려면 발언연장권을 사용해주세요'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      final firestoreService = FirestoreService();
      final authProvider = context.read<AuthProvider>();
      final userInfo = authProvider.userInfo ?? {};
      final speakingRightCount = userInfo['speakingRightCount'] ?? 0;

      // 일일 제한 확인
      final todayCount = await firestoreService.getTodayCommentCount();
      if (todayCount >= 5 && !_useSpeakingRight) {
        // 발언권이 있으면 사용 여부 물어보기
        if (speakingRightCount > 0) {
          final useRight = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('일일 댓글 제한'),
              content: Text('하루 댓글 작성 제한(5개)에 도달했습니다.\n발언권을 사용하시겠습니까? (보유: $speakingRightCount개)'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xD66B7280),
                  ),
                  child: const Text('사용'),
                ),
              ],
            ),
          );

          if (useRight != true) {
            setState(() => _isSubmittingComment = false);
            return;
          }

          setState(() => _useSpeakingRight = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('하루 댓글 작성 제한(5개)에 도달했습니다'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          setState(() => _isSubmittingComment = false);
          return;
        }
      }

      await firestoreService.addComment(
        newsUrl: widget.news.url,
        content: _commentController.text.trim(),
        stance: _userVote!,
        newsTitle: widget.news.title,
        newsDescription: widget.news.description,
        newsImageUrl: widget.news.imageUrl,
        newsSource: widget.news.source,
        useSpeakingRight: _useSpeakingRight,
        useSpeakingExtension: _useSpeakingExtension,
      );

      setState(() {
        _commentController.clear();
        _useSpeakingRight = false;
        _useSpeakingExtension = false;
      });
      await _loadComments();
      await authProvider.loadUserInfo();

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
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _submitReply(String parentId) async {
    if (_replyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답글을 입력해주세요')),
      );
      return;
    }

    final contentLength = _replyController.text.trim().length;
    if (contentLength > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답글은 최대 100자까지 작성 가능합니다'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    // 50자 초과 시 발언연장권 확인
    if (contentLength > 50 && !_useSpeakingExtension) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('50자를 초과하려면 발언연장권을 사용해주세요'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      final firestoreService = FirestoreService();
      final authProvider = context.read<AuthProvider>();
      final userInfo = authProvider.userInfo ?? {};
      final speakingRightCount = userInfo['speakingRightCount'] ?? 0;

      // 일일 제한 확인
      final todayCount = await firestoreService.getTodayCommentCount();
      if (todayCount >= 5 && !_useSpeakingRight) {
        // 발언권이 있으면 사용 여부 물어보기
        if (speakingRightCount > 0) {
          final useRight = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('일일 댓글 제한'),
              content: Text('하루 댓글 작성 제한(5개)에 도달했습니다.\n발언권을 사용하시겠습니까? (보유: $speakingRightCount개)'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xD66B7280),
                  ),
                  child: const Text('사용'),
                ),
              ],
            ),
          );

          if (useRight != true) {
            setState(() => _isSubmittingComment = false);
            return;
          }

          setState(() => _useSpeakingRight = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('하루 댓글 작성 제한(5개)에 도달했습니다'),
              backgroundColor: AppColors.errorColor,
            ),
          );
          setState(() => _isSubmittingComment = false);
          return;
        }
      }

      await firestoreService.addComment(
        newsUrl: widget.news.url,
        content: _replyController.text.trim(),
        stance: _userVote!,
        parentId: parentId,
        newsTitle: widget.news.title,
        newsDescription: widget.news.description,
        newsImageUrl: widget.news.imageUrl,
        newsSource: widget.news.source,
        useSpeakingRight: _useSpeakingRight,
        useSpeakingExtension: _useSpeakingExtension,
      );

      setState(() {
        _replyController.clear();
        _replyingToCommentId = null;
        _replyingToNickname = null;
        _useSpeakingRight = false;
        _useSpeakingExtension = false;
      });

      await _loadComments();
      await authProvider.loadUserInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('답글이 등록되었습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 3),
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
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class NewsComment {
  final String id;
  final String newsUrl;
  final String nickname;
  final String stance;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final int depth;
  final int replyCount;
  final List<NewsComment> replies;

  NewsComment({
    required this.id,
    required this.newsUrl,
    required this.nickname,
    required this.stance,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.depth = 0,
    this.replyCount = 0,
    this.replies = const [],
  });

  bool get isPro => stance == 'pro';
  bool get isNeutral => stance == 'neutral';
  bool get isCon => stance == 'con';
  bool get isReply => parentId != null;
}