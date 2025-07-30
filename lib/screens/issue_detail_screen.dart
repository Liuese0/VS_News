// lib/screens/issue_detail_screen.dart
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
  final TextEditingController _commentController = TextEditingController();

  List<News> _newsList = [];
  List<Comment> _comments = [];
  Vote? _userVote;
  bool _isLoading = true;
  bool _isSubmittingComment = false;
  String _commentSort = 'recent';
  String _selectedStance = 'pro';

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
          SnackBar(
            content: Text('데이터 로딩 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
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
          : CustomScrollView(
        slivers: [
          // 커스텀 앱바
          _buildSliverAppBar(),

          // 투표 현황 차트
          SliverToBoxAdapter(child: _buildVoteSection()),

          // 뉴스 비교
          SliverToBoxAdapter(child: _buildNewsSection()),

          // 댓글 섹션 헤더
          SliverToBoxAdapter(child: _buildCommentHeader()),

          // 댓글 입력
          if (_userVote != null)
            SliverToBoxAdapter(child: _buildCommentInput()),

          // 댓글 목록
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.padding,
                    vertical: AppDimensions.margin / 2,
                  ),
                  child: CommentWidget(comment: _comments[index]),
                );
              },
              childCount: _comments.length,
            ),
          ),

          // 여백
          const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primaryColor,
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
            padding: const EdgeInsets.all(AppDimensions.padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  widget.issue.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoteSection() {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.padding),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '투표 현황',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '총 ${widget.issue.totalVotes}표',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildVoteChart(),
          const SizedBox(height: 20),
          _buildVoteButton(),
        ],
      ),
    );
  }

  Widget _buildVoteChart() {
    if (widget.issue.totalVotes == 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: const Center(
          child: Text(
            '아직 투표가 없습니다',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
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
            PieChartSectionData(
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

  Widget _buildVoteButton() {
    if (_userVote == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _showVoteDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.how_to_vote, color: Colors.white),
              SizedBox(width: 8),
              Text('투표하기', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _userVote!.vote == 'pro'
            ? Colors.blue.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _userVote!.vote == 'pro' ? Colors.blue : Colors.red,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: _userVote!.vote == 'pro' ? Colors.blue : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            _userVote!.vote == 'pro' ? '찬성에 투표하셨습니다' : '반대에 투표하셨습니다',
            style: TextStyle(
              color: _userVote!.vote == 'pro' ? Colors.blue : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.padding),
      child: NewsComparisonCard(newsList: _newsList),
    );
  }

  Widget _buildCommentHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.padding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '댓글 (${_comments.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          DropdownButton<String>(
            value: _commentSort,
            underline: Container(),
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
    );
  }

  Widget _buildCommentInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.padding),
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
          const Text(
            '댓글 작성',
            style: TextStyle(
              fontSize: 16,
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
                  title: const Text('찬성'),
                  value: 'pro',
                  groupValue: _selectedStance,
                  activeColor: Colors.blue,
                  onChanged: (value) {
                    setState(() {
                      _selectedStance = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('반대'),
                  value: 'con',
                  groupValue: _selectedStance,
                  activeColor: Colors.red,
                  onChanged: (value) {
                    setState(() {
                      _selectedStance = value!;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 댓글 입력
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '의견을 작성해주세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 작성 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingComment ? null : _submitComment,
              child: _isSubmittingComment
                  ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
                  : const Text('댓글 작성'),
            ),
          ),
        ],
      ),
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
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('투표가 완료되었습니다'),
                    backgroundColor: AppColors.successColor,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: AppColors.errorColor,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 내용을 입력해주세요')),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final comment = Comment(
        id: 0,
        issueId: widget.issue.id,
        userId: authProvider.userId,
        nickname: authProvider.nickname,
        stance: _selectedStance,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success = await _apiService.postComment(comment);
      if (success) {
        _commentController.clear();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('댓글이 등록되었습니다'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('댓글 등록 실패: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}