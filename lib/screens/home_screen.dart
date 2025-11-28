// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/news_comment_provider.dart';
import '../screens/news_explorer_screen.dart';
import '../utils/constants.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();

  List<NewsDiscussionItem> _popularDiscussions = [];
  List<NewsDiscussionItem> _participatedDiscussions = [];
  List<NewsDiscussionItem> _favoriteDiscussions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      final newsCommentProvider = context.read<NewsCommentProvider>();

      // 참여한 토론 로드
      await newsCommentProvider.loadParticipatedDiscussions();

      // 인기 토론 (캐시에서 가져오기)
      final popularCache = await _firestoreService.getPopularDiscussions();
      _popularDiscussions = popularCache.map((data) {
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

      // 참여한 토론
      final participatedUrls = newsCommentProvider.participatedNewsUrls;
      _participatedDiscussions = [];

      for (String url in participatedUrls.take(10)) {
        final commentCount = await _firestoreService.getCommentCount(url);
        final participantCount = await _firestoreService.getParticipantCount(url);

        _participatedDiscussions.add(NewsDiscussionItem(
          newsUrl: url,
          title: _extractTitleFromUrl(url),
          participantCount: participantCount,
          commentCount: commentCount,
          lastCommentTime: DateTime.now(),
        ));
      }

      // 즐겨찾기 토론 (추후 구현)
      _favoriteDiscussions = [];

    } catch (e) {
      print('데이터 로딩 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      return url.split('/').last
          .replaceAll('-', ' ')
          .replaceAll('.html', '')
          .replaceAll('%20', ' ');
    } catch (e) {
      return '뉴스 토론';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: '뉴스 탐색',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImprovedNewsExplorerScreen(),
                ),
              );
              _loadAllData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _loadAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.whatshot), text: '인기 토론'),
            Tab(icon: Icon(Icons.history), text: '참여한 토론'),
            Tab(icon: Icon(Icons.favorite), text: '즐겨찾기'),
          ],
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryColor,
        ),
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppStrings.loading),
          ],
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: [
          _buildPopularTab(),
          _buildParticipatedTab(),
          _buildFavoriteTab(),
        ],
      ),
    );
  }

  Widget _buildPopularTab() {
    if (_popularDiscussions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.whatshot_outlined,
        title: '인기 토론이 없습니다',
        subtitle: '뉴스를 둘러보고 새로운 토론을 시작해보세요!',
        actionLabel: '뉴스 탐색하기',
        onAction: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImprovedNewsExplorerScreen(),
            ),
          );
          _loadAllData();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _popularDiscussions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '🔥 인기 토론 TOP 10',
              subtitle: '가장 많은 사람들이 참여한 토론',
            );
          }

          final discussion = _popularDiscussions[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildRankingDiscussionCard(discussion, index),
          );
        },
      ),
    );
  }

  Widget _buildParticipatedTab() {
    if (_participatedDiscussions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        title: '참여한 토론이 없습니다',
        subtitle: '토론에 참여하고 다양한 의견을 나눠보세요!',
        actionLabel: '토론 참여하기',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _participatedDiscussions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '📝 최근 참여한 토론',
              subtitle: '내가 의견을 남긴 토론들',
            );
          }

          final discussion = _participatedDiscussions[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildParticipatedDiscussionCard(discussion),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteTab() {
    if (_favoriteDiscussions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_outline,
        title: '즐겨찾기한 토론이 없습니다',
        subtitle: '관심있는 토론을 즐겨찾기에 추가해보세요!',
        actionLabel: '토론 둘러보기',
        onAction: () {
          _tabController.animateTo(0);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _favoriteDiscussions.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '⭐ 즐겨찾기 토론',
              subtitle: '내가 관심있어 하는 토론들',
            );
          }

          final discussion = _favoriteDiscussions[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildFavoriteDiscussionCard(discussion),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.margin * 2),
      padding: const EdgeInsets.all(AppDimensions.padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.1),
            AppColors.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingDiscussionCard(NewsDiscussionItem discussion, int rank) {
    return GestureDetector(
      onTap: () => _openNewsExplorer(discussion.newsUrl),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.padding),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discussion.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 16,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${discussion.participantCount}명 참여',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.comment,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${discussion.commentCount}개',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipatedDiscussionCard(NewsDiscussionItem discussion) {
    return GestureDetector(
      onTap: () => _openNewsExplorer(discussion.newsUrl),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.padding),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.3),
            width: 2,
          ),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '참여함',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryColor,
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
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              discussion.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${discussion.participantCount}명',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.comment,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${discussion.commentCount}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteDiscussionCard(NewsDiscussionItem discussion) {
    return GestureDetector(
      onTap: () => _openNewsExplorer(discussion.newsUrl),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.padding),
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
            Row(
              children: [
                const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    discussion.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () {
                    _removeFavorite(discussion);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.people,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${discussion.participantCount}명 참여',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.comment,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${discussion.commentCount}개 댓글',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.padding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.explore),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.brown[400]!;
      default:
        return AppColors.primaryColor;
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

  void _removeFavorite(NewsDiscussionItem discussion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('즐겨찾기 해제'),
        content: const Text('이 토론을 즐겨찾기에서 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _favoriteDiscussions.removeWhere((d) => d.newsUrl == discussion.newsUrl);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('즐겨찾기에서 제거되었습니다'),
                  backgroundColor: AppColors.successColor,
                ),
              );
            },
            child: const Text('제거'),
          ),
        ],
      ),
    );
  }

  void _openNewsExplorer(String newsUrl) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ImprovedNewsExplorerScreen(),
      ),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// 뉴스 토론 아이템 모델
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