// lib/screens/improved_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/issue_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/issue_card.dart';
import '../widgets/custom_app_bar.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/news_explorer_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _ImprovedHomeScreenState();
}

class _ImprovedHomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  List<Issue> _popularIssues = [];
  List<Issue> _participatedIssues = [];
  List<Issue> _favoriteIssues = [];
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
      final issueProvider = context.read<IssueProvider>();
      final authProvider = context.read<AuthProvider>();

      // 인기 토론 (10개)
      await issueProvider.loadIssues(sortBy: 'debate_score');
      _popularIssues = issueProvider.issues.take(10).toList();

      // 참여한 토론 (최신 5개)
      _participatedIssues = issueProvider.issues.where((issue) {
        return issueProvider.hasUserVoted(issue.id, authProvider.userId);
      }).take(5).toList();

      // 즐겨찾기 토론 (임시 데이터 - 실제로는 로컬 저장소에서 불러와야 함)
      _favoriteIssues = await _loadFavoriteIssues();

    } catch (e) {
      print('데이터 로딩 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Issue>> _loadFavoriteIssues() async {
    // 실제로는 SharedPreferences 또는 로컬 DB에서 불러와야 함
    // 여기서는 임시로 빈 리스트 반환
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppStrings.appName,
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: '뉴스 탐색',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImprovedNewsExplorerScreen(),
                ),
              );
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
            Tab(
              icon: Icon(Icons.whatshot),
              text: '인기 토론',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: '참여한 토론',
            ),
            Tab(
              icon: Icon(Icons.favorite),
              text: '즐겨찾기',
            ),
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
    if (_popularIssues.isEmpty) {
      return _buildEmptyState(
        icon: Icons.whatshot_outlined,
        title: '인기 토론이 없습니다',
        subtitle: '뉴스를 둘러보고 새로운 토론을 시작해보세요!',
        actionLabel: '뉴스 탐색하기',
        onAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImprovedNewsExplorerScreen(),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _popularIssues.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '🔥 인기 토론 TOP 10',
              subtitle: '가장 뜨거운 논쟁들을 확인해보세요',
            );
          }

          final issue = _popularIssues[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildRankingIssueCard(issue, index),
          );
        },
      ),
    );
  }

  Widget _buildParticipatedTab() {
    if (_participatedIssues.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_outlined,
        title: '참여한 토론이 없습니다',
        subtitle: '토론에 참여하고 다양한 의견을 나눠보세요!',
        actionLabel: '토론 참여하기',
        onAction: () {
          _tabController.animateTo(0); // 인기 토론 탭으로 이동
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.padding),
        itemCount: _participatedIssues.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '📝 최근 참여한 토론',
              subtitle: '내가 의견을 남긴 토론들',
            );
          }

          final issue = _participatedIssues[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildParticipatedIssueCard(issue),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteTab() {
    if (_favoriteIssues.isEmpty) {
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
        itemCount: _favoriteIssues.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(
              title: '⭐ 즐겨찾기 토론',
              subtitle: '내가 관심있어 하는 토론들 (최대 100개)',
            );
          }

          final issue = _favoriteIssues[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.margin),
            child: _buildFavoriteIssueCard(issue),
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

  Widget _buildRankingIssueCard(Issue issue, int rank) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IssueDetailScreen(issue: issue),
          ),
        );
      },
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
            // 순위 표시
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
            // 이슈 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '논쟁도 ${issue.debateScore.toInt()}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '찬성 ${issue.positivePercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '반대 ${issue.negativePercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${issue.totalVotes}명 참여',
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
          ],
        ),
      ),
    );
  }

  Widget _buildParticipatedIssueCard(Issue issue) {
    // 사용자의 투표 정보 가져오기 (임시로 찬성으로 설정)
    String userVote = 'pro'; // 실제로는 provider에서 가져와야 함

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IssueDetailScreen(issue: issue),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.padding),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          border: Border.all(
            color: userVote == 'pro'
                ? Colors.blue.withOpacity(0.3)
                : Colors.red.withOpacity(0.3),
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
                    color: userVote == 'pro'
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        userVote == 'pro' ? Icons.thumb_up : Icons.thumb_down,
                        size: 16,
                        color: userVote == 'pro' ? Colors.blue : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        userVote == 'pro' ? '찬성' : '반대',
                        style: TextStyle(
                          fontSize: 12,
                          color: userVote == 'pro' ? Colors.blue : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(issue.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              issue.title,
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
                Text(
                  '찬성 ${issue.positivePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '반대 ${issue.negativePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${issue.totalVotes}명 참여',
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

  Widget _buildFavoriteIssueCard(Issue issue) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IssueDetailScreen(issue: issue),
          ),
        );
      },
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
                    issue.title,
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
                    // 즐겨찾기 해제 로직
                    _removeFavorite(issue);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              issue.summary,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '찬성 ${issue.positivePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '반대 ${issue.negativePercent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${issue.totalVotes}명 참여',
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

  void _removeFavorite(Issue issue) {
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
                _favoriteIssues.removeWhere((i) => i.id == issue.id);
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

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}