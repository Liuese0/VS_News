// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/issue_provider.dart';
import '../widgets/issue_card.dart';
import '../widgets/custom_app_bar.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/admin_screen.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String _sortBy = 'debate_score';

  @override
  void initState() {
    super.initState();
    // 다음 프레임에서 실행되도록 수정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIssues();
    });
  }

  Future<void> _loadIssues() async {
    await context.read<IssueProvider>().loadIssues(sortBy: _sortBy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: AppStrings.appName,
        actions: [
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
      ),
      body: Consumer<IssueProvider>(
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

          if (provider.issues.isEmpty) {
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
                  const Text(
                    '아직 등록된 이슈가 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadIssues,
                    child: const Text('새로고침'),
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
              itemCount: provider.issues.length,
              separatorBuilder: (context, index) =>
              const SizedBox(height: AppDimensions.margin),
              itemBuilder: (context, index) {
                final issue = provider.issues[index];
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAdminDialog,
        backgroundColor: AppColors.primaryColor,
        tooltip: '이슈 등록',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAdminDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        ),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primaryColor),
            SizedBox(width: 8),
            Text('관리자 기능'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('관리자 비밀번호를 입력하세요'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              passwordController.dispose();
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // 간단한 비밀번호 체크 (실제로는 더 안전한 방법 사용)
              if (passwordController.text == 'admin123') {
                passwordController.dispose();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('비밀번호가 틀렸습니다'),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}