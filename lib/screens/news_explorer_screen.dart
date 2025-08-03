// lib/screens/improved_news_explorer_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/news_auto_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/category_chip.dart';
import '../widgets/tag_chip.dart';
import '../utils/constants.dart';

class ImprovedNewsExplorerScreen extends StatefulWidget {
  const ImprovedNewsExplorerScreen({super.key});

  @override
  State<ImprovedNewsExplorerScreen> createState() => _ImprovedNewsExplorerScreenState();
}

class _ImprovedNewsExplorerScreenState extends State<ImprovedNewsExplorerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NewsAutoService _newsService = NewsAutoService();

  String _selectedCategory = '인기';
  String? _selectedTag;
  List<AutoCollectedNews> _newsList = [];
  List<DebatableIssue> _debatableIssues = [];
  bool _isLoading = false;
  bool _isLoadingIssues = false;
  Set<String> _favoriteNewsIds = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
    _loadNews();
    _loadDebatableIssues();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteNewsIds = (prefs.getStringList('favorite_news') ?? []).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_news', _favoriteNewsIds.toList());
  }

  Future<void> _loadNews() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      List<AutoCollectedNews> newsList;

      if (_selectedTag != null && _selectedCategory != '인기') {
        newsList = await _newsService.searchNewsByTag(_selectedCategory, _selectedTag!);
      } else if (_selectedCategory != '인기') {
        newsList = await _newsService.searchNewsByCategory(_selectedCategory);
      } else {
        newsList = await _newsService.collectKoreanNews();
      }

      setState(() {
        _newsList = newsList;
      });
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDebatableIssues() async {
    if (_isLoadingIssues) return;

    setState(() => _isLoadingIssues = true);

    try {
      final issues = await _newsService.generateDebatableIssues();
      setState(() {
        _debatableIssues = issues;
      });
    } catch (e) {
      print('논쟁적 이슈 로딩 실패: $e');
    } finally {
      setState(() => _isLoadingIssues = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: '뉴스 탐색',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '실시간 뉴스', icon: Icon(Icons.newspaper)),
            Tab(text: '논쟁 이슈', icon: Icon(Icons.forum)),
          ],
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewsTab(),
          _buildDebateTab(),
        ],
      ),
    );
  }

  Widget _buildNewsTab() {
    return Column(
      children: [
        // 카테고리 선택
        _buildCategorySelector(),

        // 태그 선택 (선택된 카테고리에 태그가 있는 경우)
        if (_getSelectedCategoryTags().isNotEmpty)
          _buildTagSelector(),

        // 뉴스 목록
        Expanded(
          child: _buildNewsList(),
        ),
      ],
    );
  }

  Widget _buildDebateTab() {
    return RefreshIndicator(
      onRefresh: _loadDebatableIssues,
      child: _isLoadingIssues
          ? const Center(child: CircularProgressIndicator())
          : _debatableIssues.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('논쟁적인 이슈를 찾고 있습니다...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _debatableIssues.length,
        itemBuilder: (context, index) {
          return _buildDebatableIssueCard(_debatableIssues[index]);
        },
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.padding),
        itemCount: NewsCategory.allCategories.length,
        itemBuilder: (context, index) {
          final category = NewsCategory.allCategories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CategoryChip(
              category: category,
              isSelected: _selectedCategory == category.name,
              onTap: () {
                setState(() {
                  _selectedCategory = category.name;
                  _selectedTag = null; // 카테고리 변경 시 태그 초기화
                });
                _loadNews();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagSelector() {
    final tags = _getSelectedCategoryTags();

    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.padding),
        itemCount: tags.length + 1, // +1 for "전체" option
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TagChip(
                tag: '전체',
                isSelected: _selectedTag == null,
                onTap: () {
                  setState(() {
                    _selectedTag = null;
                  });
                  _loadNews();
                },
              ),
            );
          }

          final tag = tags[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TagChip(
              tag: tag,
              isSelected: _selectedTag == tag,
              onTap: () {
                setState(() {
                  _selectedTag = tag;
                });
                _loadNews();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('뉴스를 불러오는 중...'),
          ],
        ),
      );
    }

    if (_newsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.newspaper_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTag != null
                  ? '$_selectedCategory > $_selectedTag 뉴스가 없습니다'
                  : '$_selectedCategory 뉴스가 없습니다',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadNews,
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _newsList.length,
        itemBuilder: (context, index) {
          return _buildImprovedNewsCard(_newsList[index]);
        },
      ),
    );
  }

  Widget _buildImprovedNewsCard(AutoCollectedNews news) {
    final newsId = news.url; // URL을 unique ID로 사용
    final isFavorite = _favoriteNewsIds.contains(newsId);

    return GestureDetector(
      onTap: () => _showNewsDetailWithDiscussion(news),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.margin),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 (있는 경우)
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.borderRadius),
                ),
                child: Image.network(
                  news.imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppDimensions.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리, 태그, 즐겨찾기 버튼
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          news.autoCategory,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (news.autoTags.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            news.autoTags.first,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      // 즐겨찾기 버튼
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => _toggleFavorite(newsId),
                      ),
                      Text(
                        _formatDateTime(news.publishedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 제목
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // 설명
                  Text(
                    news.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // 하단 정보 및 액션 버튼
                  Row(
                    children: [
                      Icon(
                        Icons.source,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        news.source,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '토론하기',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ],
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

  Widget _buildDebatableIssueCard(DebatableIssue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.margin),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(AppDimensions.padding),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.borderRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    issue.category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.forum, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 4),
                const Text(
                  '논쟁 이슈',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${issue.relatedNews.length}개 뉴스',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 내용
          Padding(
            padding: const EdgeInsets.all(AppDimensions.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  issue.summary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // 찬반 뉴스 개수
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thumb_up, color: Colors.blue, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '찬성 ${issue.proNews.length}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.thumb_down, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '반대 ${issue.conNews.length}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _createIssueFromDebatable(issue),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('이슈 생성'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        minimumSize: const Size(0, 32),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSelectedCategoryTags() {
    final category = NewsCategory.findByName(_selectedCategory);
    return category?.tags ?? [];
  }

  void _toggleFavorite(String newsId) {
    setState(() {
      if (_favoriteNewsIds.contains(newsId)) {
        _favoriteNewsIds.remove(newsId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에서 제거되었습니다'),
            duration: Duration(seconds: 1),
          ),
        );
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
        _favoriteNewsIds.add(newsId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('즐겨찾기에 추가되었습니다'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
    _saveFavorites();
  }

  void _showNewsDetailWithDiscussion(AutoCollectedNews news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewsDetailWithDiscussion(news: news),
    );
  }

  void _createIssueFromDebatable(DebatableIssue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('논쟁 이슈를 토론 주제로 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 이슈를 토론 주제로 등록하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.summary,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _registerDebatableIssue(issue);
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerDebatableIssue(DebatableIssue issue) async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('토론 이슈가 성공적으로 등록되었습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이슈 등록 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// 뉴스 상세보기 + 토론 위젯
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
  String _selectedStance = 'pro';
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    // 임시 댓글 데이터 (실제로는 API에서 로드)
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _comments = [
        NewsComment(
          id: 1,
          newsUrl: widget.news.url,
          nickname: '뉴스러버',
          stance: 'pro',
          content: '이 뉴스 정말 흥미롭네요. 앞으로 어떻게 발전할지 기대됩니다.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        NewsComment(
          id: 2,
          newsUrl: widget.news.url,
          nickname: '분석가',
          stance: 'con',
          content: '하지만 여러 문제점들이 있을 것 같은데요. 좀 더 신중하게 접근해야 할 것 같습니다.',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 뉴스 내용
                      _buildNewsContent(),

                      const Divider(thickness: 8, color: Color(0xFFF5F5F5)),

                      // 토론 섹션
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
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리와 태그
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                label: Text(widget.news.autoCategory),
                backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                labelStyle: const TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              ...widget.news.autoTags.map((tag) => Chip(
                label: Text(tag),
                backgroundColor: Colors.grey.withOpacity(0.1),
                labelStyle: const TextStyle(fontSize: 12),
              )),
            ],
          ),
          const SizedBox(height: 16),

          // 제목
          Text(
            widget.news.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // 소스와 시간
          Row(
            children: [
              Text(
                widget.news.source,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(widget.news.publishedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 이미지 (있는 경우)
          if (widget.news.imageUrl != null && widget.news.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.news.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  );
                },
              ),
            ),
          if (widget.news.imageUrl != null && widget.news.imageUrl!.isNotEmpty)
            const SizedBox(height: 16),

          // 내용
          Text(
            widget.news.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // 원문 보기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl(widget.news.url),
              icon: const Icon(Icons.open_in_new),
              label: const Text('원문 보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionSection() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 토론 헤더
          Row(
            children: [
              const Icon(Icons.forum, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              const Text(
                '이 뉴스에 대한 토론',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_comments.length}개 의견',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 댓글 입력
          _buildCommentInput(),
          const SizedBox(height: 20),

          // 댓글 목록
          const Text(
            '토론 의견',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (_comments.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '아직 의견이 없습니다.\n첫 번째 의견을 남겨보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._comments.map((comment) => _buildCommentItem(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.padding),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '의견 작성',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // 찬반 선택
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('찬성', style: TextStyle(fontSize: 14)),
                  value: 'pro',
                  groupValue: _selectedStance,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() {
                      _selectedStance = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('반대', style: TextStyle(fontSize: 14)),
                  value: 'con',
                  groupValue: _selectedStance,
                  activeColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() {
                      _selectedStance = value!;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 댓글 입력
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '이 뉴스에 대한 의견을 작성해주세요',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // 작성 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedStance == 'pro' ? Colors.blue : Colors.red,
              ),
              child: _isSubmittingComment
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : Text(_selectedStance == 'pro' ? '찬성 의견 작성' : '반대 의견 작성'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(NewsComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.margin),
      padding: const EdgeInsets.all(AppDimensions.padding),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        border: Border.all(
          color: comment.isPro
              ? Colors.blue.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 찬반 뱃지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: comment.isPro
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      comment.isPro ? Icons.thumb_up : Icons.thumb_down,
                      size: 14,
                      color: comment.isPro ? Colors.blue : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      comment.isPro ? '찬성' : '반대',
                      style: TextStyle(
                        fontSize: 12,
                        color: comment.isPro ? Colors.blue : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 닉네임
              Text(
                comment.nickname,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 작성 시간
              Text(
                _formatDateTime(comment.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 댓글 내용
          Text(
            comment.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
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
      // 실제로는 API 호출
      await Future.delayed(const Duration(seconds: 1));

      final newComment = NewsComment(
        id: _comments.length + 1,
        newsUrl: widget.news.url,
        nickname: '사용자${DateTime.now().millisecondsSinceEpoch % 1000}',
        stance: _selectedStance,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      setState(() {
        _comments.insert(0, newComment); // 최신 댓글을 맨 위에 추가
        _commentController.clear();
      });

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

  Future<void> _launchUrl(String url) async {
    // URL 실행 로직
    print('Opening URL: $url');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// 뉴스 댓글 모델
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

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    return NewsComment(
      id: json['id'],
      newsUrl: json['news_url'],
      nickname: json['nickname'],
      stance: json['stance'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'news_url': newsUrl,
      'nickname': nickname,
      'stance': stance,
      'content': content,
    };
  }
}