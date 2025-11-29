// lib/screens/news_explorer_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/news_auto_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NewsAutoService _newsService = NewsAutoService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = '전체';
  List<AutoCollectedNews> _newsList = [];
  bool _isLoading = false;
  Set<String> _favoriteNewsIds = <String>{};

  // 카테고리 목록
  final List<Map<String, dynamic>> _categories = [
    {'name': '전체', 'icon': '📰'},
    {'name': '정치', 'icon': '🏛️'},
    {'name': '경제', 'icon': '💰'},
    {'name': '사회', 'icon': '👥'},
    {'name': '문화', 'icon': '🎭'},
    {'name': '과학기술', 'icon': '🔬'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFavorites();
    _loadNews();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _firestoreService.getUserFavorites();
      setState(() {
        _favoriteNewsIds = favorites.toSet();
      });
    } catch (e) {
      print('즐겨찾기 로드 실패: $e');
    }
  }

  Future<void> _loadNews() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      List<AutoCollectedNews> newsList;

      if (_selectedCategory == '전체') {
        newsList = await _newsService.collectKoreanNews();
      } else {
        newsList = await _newsService.searchNewsByCategory(_selectedCategory);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '뉴스 디베이터',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.primaryColor),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              // 검색 바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '관심 있는 글 검색',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.primaryColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // 탭 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildTabFilterButton('실시간 뉴스', true),
                    const SizedBox(width: 8),
                    _buildTabFilterButton('논쟁 이슈', false),
                  ],
                ),
              ),

              // 카테고리 필터
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategory == category['name'];

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(category['icon']),
                            const SizedBox(width: 4),
                            Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.primaryColor,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryColor
                              : Colors.grey.shade300,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category['name'];
                          });
                          _loadNews();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      )
          : _buildNewsList(),
    );
  }

  Widget _buildTabFilterButton(String label, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNewsList() {
    if (_newsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.newspaper_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              '뉴스가 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
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
      color: AppColors.primaryColor,
      child: Container(
        color: Colors.grey.shade50,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _newsList.length,
          itemBuilder: (context, index) {
            return _buildNewsCard(_newsList[index]);
          },
        ),
      ),
    );
  }

  Widget _buildNewsCard(AutoCollectedNews news) {
    final newsId = news.url;
    final isFavorite = _favoriteNewsIds.contains(newsId);
    final newsCommentProvider = context.watch<NewsCommentProvider>();
    final commentCount = newsCommentProvider.getCommentCount(news.url);
    final participantCount = newsCommentProvider.getParticipantCount(news.url);

    return GestureDetector(
      onTap: () => _showNewsDetailWithDiscussion(news),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 정보 (카테고리, 시간, 북마크)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        news.autoCategory,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (news.autoTags.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
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
                Text(
                  _formatDateTime(news.publishedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 제목
            Text(
              news.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 설명
            if (news.description.isNotEmpty)
              Text(
                news.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            // 이미지 (있는 경우)
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  news.imageUrl!,
                  width: double.infinity,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 하단 통계
            Row(
              children: [
                Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_outline,
                  size: 16,
                  color: isFavorite ? AppColors.primaryColor : Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  participantCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFavorite ? AppColors.primaryColor : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  commentCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${participantCount * 10}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                    size: 20,
                    color: isFavorite ? AppColors.primaryColor : Colors.grey.shade400,
                  ),
                  onPressed: () => _toggleFavorite(newsId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(String newsUrl) async {
    try {
      if (_favoriteNewsIds.contains(newsUrl)) {
        await _firestoreService.removeFavorite(newsUrl);
        setState(() => _favoriteNewsIds.remove(newsUrl));
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
        await _firestoreService.addFavorite(newsUrl);
        setState(() => _favoriteNewsIds.add(newsUrl));
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
    _tabController.dispose();
    _searchController.dispose();
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
    final newsCommentProvider = context.read<NewsCommentProvider>();
    await newsCommentProvider.loadComments(widget.news.url);

    setState(() {
      _comments = newsCommentProvider.getComments(widget.news.url);
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
                      _buildNewsContent(),
                      const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.news.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
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
          Text(
            widget.news.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 뉴스에 대한 토론',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildCommentInput(),
          const SizedBox(height: 20),
          if (_comments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '첫 번째 의견을 남겨보세요!',
                  style: TextStyle(color: AppColors.textSecondary),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('찬성', style: TextStyle(fontSize: 14)),
                  value: 'pro',
                  groupValue: _selectedStance,
                  activeColor: AppColors.primaryColor,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _selectedStance = value!);
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('반대', style: TextStyle(fontSize: 14)),
                  value: 'con',
                  groupValue: _selectedStance,
                  activeColor: Colors.grey,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setState(() => _selectedStance = value!);
                  },
                ),
              ),
            ],
          ),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '의견을 작성해주세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: _isSubmittingComment
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_selectedStance == 'pro' ? '찬성 의견 작성' : '반대 의견 작성'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(NewsComment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: comment.isPro
              ? AppColors.primaryColor.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: comment.isPro
                      ? AppColors.primaryColor.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  comment.isPro ? '찬성' : '반대',
                  style: TextStyle(
                    fontSize: 12,
                    color: comment.isPro ? AppColors.primaryColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.nickname,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
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
          Text(
            comment.content,
            style: const TextStyle(fontSize: 14, height: 1.4),
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
        stance: _selectedStance,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await newsCommentProvider.addComment(widget.news.url, newComment);
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