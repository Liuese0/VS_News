// lib/screens/news_explorer_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/news_auto_service.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/constants.dart';

// CategoryChip 위젯을 직접 정의
class CategoryChip extends StatelessWidget {
  final NewsCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor
              : AppColors.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : Colors.grey.withOpacity(0.3),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category.icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TagChip 위젯을 직접 정의
class TagChip extends StatelessWidget {
  final String tag;
  final bool isSelected;
  final VoidCallback onTap;

  const TagChip({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected
                ? AppColors.primaryColor
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// NewsCard 위젯을 직접 정의
class NewsCard extends StatelessWidget {
  final AutoCollectedNews news;
  final VoidCallback onTap;

  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                  // 카테고리와 태그
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
                  const SizedBox(height: 8),

                  // 소스
                  Row(
                    children: [
                      const Icon(
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
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppColors.textSecondary,
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
}

class NewsExplorerScreen extends StatefulWidget {
  const NewsExplorerScreen({super.key});

  @override
  State<NewsExplorerScreen> createState() => _NewsExplorerScreenState();
}

class _NewsExplorerScreenState extends State<NewsExplorerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NewsAutoService _newsService = NewsAutoService();

  String _selectedCategory = '인기';
  String? _selectedTag;
  List<AutoCollectedNews> _newsList = [];
  List<DebatableIssue> _debatableIssues = [];
  bool _isLoading = false;
  bool _isLoadingIssues = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNews();
    _loadDebatableIssues();
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
          return NewsCard(
            news: _newsList[index],
            onTap: () => _showNewsDetail(_newsList[index]),
          );
        },
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

  void _showNewsDetail(AutoCollectedNews news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
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
                              label: Text(news.autoCategory),
                              backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                              labelStyle: const TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            ...news.autoTags.map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              labelStyle: const TextStyle(fontSize: 12),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 제목
                        Text(
                          news.title,
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
                              news.source,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateTime(news.publishedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 이미지 (있는 경우)
                        if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              news.imageUrl!,
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
                        if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
                          const SizedBox(height: 16),

                        // 내용
                        Text(
                          news.description,
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
                            onPressed: () => _launchUrl(news.url),
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
            Text('다음 이슈를 토론 주제로 등록하시겠습니까?'),
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
    // 실제로는 API를 호출하여 이슈를 등록
    // 여기서는 시뮬레이션
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
    _tabController.dispose();
    super.dispose();
  }
}