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

class UpdatedHomeScreen extends StatefulWidget {
  const UpdatedHomeScreen({super.key});

  @override
  State<UpdatedHomeScreen> createState() => _UpdatedHomeScreenState();
}

class _UpdatedHomeScreenState extends State<UpdatedHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  String _sortBy = 'debate_score';
  bool _showOnlyMyDebates = true; // 내가 참여한 토론만 보기 필터

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 다음 프레임에서 실행되도록 수정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIssues();
    });
  }

  Future<void> _loadIssues() async {
    await context.read<IssueProvider>().loadIssues(sortBy: _sortBy);
  }

  // _buildNewsExplorerContent 메서드를 _UpdatedHomeScreenState 클래스 안으로 이동
  Widget _buildNewsExplorerContent() {
    return Column(
      children: [
        // 뉴스 탐색 안내
        Container(
          margin: const EdgeInsets.all(AppDimensions.padding),
          padding: const EdgeInsets.all(AppDimensions.padding),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.explore,
                size: 48,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 12),
              const Text(
                '실시간 한국 뉴스 탐색',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '카테고리별로 분류된 최신 뉴스를 확인하고\n논쟁적인 이슈를 토론 주제로 만들어보세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewsExplorerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.newspaper),
                label: const Text('뉴스 탐색하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),

        // 카테고리 미리보기
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.padding),
            itemCount: 4, // 인기 카테고리 4개만 미리보기
            itemBuilder: (context, index) {
              final categories = ['🔥 인기', '🏛️ 정치', '💰 경제', '🏭 산업'];
              final descriptions = [
                '가장 많이 읽히는 뜨거운 이슈들',
                '정치, 정책, 선거 관련 최신 소식',
                '경제, 금융, 투자 트렌드',
                '기업, 제조업, 반도체 소식'
              ];

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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppDimensions.padding),
                  title: Text(
                    categories[index],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    descriptions[index],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewsExplorerScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
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
                  builder: (context) => const NewsExplorerScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '정렬',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _loadIssues();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'debate_score',
                child: Row(
                  children: [
                    Icon(Icons.whatshot, size: 20),
                    SizedBox(width: 8),
                    Text('논쟁도 순'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 8),
                    Text('최신 순'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'votes',
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text('투표 많은 순'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '토론 이슈', icon: Icon(Icons.forum)),
            Tab(text: '뉴스 둘러보기', icon: Icon(Icons.explore)),
          ],
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryColor,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIssuesTab(),
          _buildNewsExplorerContent(),
        ],
      ),
    );
  }

  Widget _buildIssuesTab() {
    return Column(
      children: [
        // 내가 참여한 토론만 보기 필터
        Container(
          padding: const EdgeInsets.all(AppDimensions.padding),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '내가 참여한 토론만 보기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: _showOnlyMyDebates,
                onChanged: (value) {
                  setState(() {
                    _showOnlyMyDebates = value;
                  });
                },
                activeColor: AppColors.primaryColor,
              ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<IssueProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(AppStrings.loading),
                    ],
                  ),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.errorColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadIssues,
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                );
              }

              // 필터링 로직: 내가 참여한 토론만 보기
              List<Issue> displayIssues = provider.issues;
              if (_showOnlyMyDebates) {
                final userId = context.read<AuthProvider>().userId;
                displayIssues = provider.issues.where((issue) {
                  // 여기서는 실제로 투표했는지 확인하는 로직이 필요합니다
                  // 현재는 임시로 모든 이슈를 표시하도록 설정
                  // 실제 구현 시에는 provider에서 사용자의 투표 여부를 확인해야 합니다
                  return provider.hasUserVoted(issue.id, userId);
                }).toList();
              }

              if (displayIssues.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showOnlyMyDebates
                            ? '참여한 토론이 없습니다'
                            : '등록된 이슈가 없습니다',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _showOnlyMyDebates
                            ? '토론에 참여해보세요!'
                            : '뉴스 둘러보기에서 논쟁 이슈를 찾아보세요!',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_showOnlyMyDebates)
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showOnlyMyDebates = false;
                                });
                              },
                              icon: const Icon(Icons.list),
                              label: const Text('전체 토론 보기'),
                            ),
                          if (!_showOnlyMyDebates) ...[
                            ElevatedButton.icon(
                              onPressed: _loadIssues,
                              icon: const Icon(Icons.refresh),
                              label: const Text('새로고침'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                _tabController.animateTo(1);
                              },
                              icon: const Icon(Icons.explore),
                              label: const Text('뉴스 탐색'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadIssues,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppDimensions.padding),
                  itemCount: displayIssues.length,
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.margin),
                  itemBuilder: (context, index) {
                    final issue = displayIssues[index];
                    return IssueCard(
                      issue: issue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IssueDetailScreen(issue: issue),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}