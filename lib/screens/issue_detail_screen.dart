import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/news_comparison_card.dart';
import '../widgets/comment_widget.dart';
import '../widgets/vote_dialog.dart';
import '../utils/constants.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;

  const IssueDetailScreen({super.key, required this.issue});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final ApiService _apiService = ApiService();
  List<News> _newsList = [];
  List<Comment> _comments = [];
  Vote? _userVote;
  bool _isLoading = true;
  String _commentSort = 'recent';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = context.read<AuthProvider>().userId;

      final results = await Future.wait([
        _apiService.getIssueNews(widget.issue.id),
        _apiService.getComments(widget.issue.id, sort: _commentSort),
        _apiService.getUserVote(widget.issue.id, userId),
      ]);

      setState(() {
        _newsList = results[0] as List<News>;
        _comments = results[1] as List<Comment>;
        _userVote = results[2] as Vote?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로딩 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          // 커스텀 앱바
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.issue.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryColor,
                      AppColors.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        widget.issue.summary,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 투표 현황 차트
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '투표 현황',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '총 ${widget.issue.totalVotes}표',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildVoteChart(),
                  const SizedBox(height: 20),
                  if (_userVote == null)
                    ElevatedButton(
                      onPressed: _showVoteDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('투표하기'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _userVote!.vote == 'pro'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _userVote!.vote == 'pro'
                                ? Colors.blue
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _userVote!.vote == 'pro'
                                ? '찬성에 투표하셨습니다'
                                : '반대에 투표하셨습니다',
                            style: TextStyle(
                              color: _userVote!.vote == 'pro'
                                  ? Colors.blue
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 뉴스 비교
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '관련 뉴스',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NewsComparisonCard(newsList: _newsList),
                ],
              ),
            ),
          ),

          // 댓글 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '댓글',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _commentSort,
                        items: const [
                          DropdownMenuItem(
                            value: 'recent',
                            child: Text('최신순'),
                          ),
                          DropdownMenuItem(
                            value: 'popular',
                            child: Text('공감순'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _commentSort = value!;
                          });
                          _loadData();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_userVote != null)
                    _buildCommentInput()
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '투표 후 댓글을 작성할 수 있습니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 댓글 목록
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: CommentWidget(comment: _comments[index]),
                );
              },
              childCount: _comments.length,
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }

  Widget _buildVoteChart() {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSection(
              value: widget.issue.positivePercent,
              title: '찬성\n${widget.issue.positivePercent.toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSection(
              value: widget.issue.negativePercent,
              title: '반대\n${widget.issue.negativePercent.toStringAsFixed(1)}%',
              color: Colors.red,
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    final TextEditingController controller = TextEditingController();
    String selectedStance = 'pro';

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('찬성'),
                      value: 'pro',
                      groupValue: selectedStance,
                      onChanged: (value) {
                        setState(() {
                          selectedStance = value!;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('반대'),
                      value: 'con',
                      groupValue: selectedStance,
                      onChanged: (value) {
                        setState(() {
                          selectedStance = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '의견을 작성해주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _submitComment(controller.text, selectedStance),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('댓글 작성'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVoteDialog() {
    showDialog(
      context: context,
      builder: (context) => VoteDialog(
        issue: widget.issue,
        onVote: (stance) async {
          try {
            final userId = context.read<AuthProvider>().userId;
            final success = await _apiService.vote(
              widget.issue.id,
              userId,
              stance,
            );

            if (success) {
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('투표가 완료되었습니다')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
      ),
    );
  }

  Future<void> _submitComment(String content, String stance) async {
    if (content.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 내용을 입력해주세요')),
      );
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final comment = Comment(
        id: 0,
        issueId: widget.issue.id,
        userId: authProvider.userId,
        nickname: authProvider.nickname,
        stance: stance,
        content: content,
        createdAt: DateTime.now(),
      );

      final success = await _apiService.postComment(comment);
      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 등록되었습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패: $e')),
      );
    }
  }
}
),
),
PieChartSection(
value: widget.issue.negativePercent,
title: '반대\n${widget.issue.negativePercent.toStringAsFixed(1)}%',
color: Colors.red,
radius: 80,
titleStyle: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.bold,
color: Colors.white,