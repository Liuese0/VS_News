import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/auto_collected_news.dart';
import '../utils/constants.dart';
import '../services/gemini_service.dart';
import '../screens/news_explorer_screen.dart';

class NewsWebViewScreen extends StatefulWidget {
  final AutoCollectedNews news;

  const NewsWebViewScreen({
    Key? key,
    required this.news,
  }) : super(key: key);

  @override
  State<NewsWebViewScreen> createState() => _NewsWebViewScreenState();
}

class _NewsWebViewScreenState extends State<NewsWebViewScreen> {
  final GeminiService _geminiService = GeminiService();

  WebViewController? _controller;
  bool _showSummary = true; // true: 요약 보기, false: WebView 보기
  bool _isLoadingSummary = true;
  bool _isLoadingWebView = false;
  String _summary = '';
  String? _summaryError;
  String? _webViewError;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });

    try {
      final summary = await _geminiService.summarizeNews(
        newsUrl: widget.news.url,
        title: widget.news.title,
        description: widget.news.description,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = 'AI 요약을 생성하지 못했습니다';
          _summary = widget.news.description; // 폴백: 원본 설명
          _isLoadingSummary = false;
        });
      }
    }
  }

  void _initializeWebView() {
    String url = widget.news.url;

    // URL 유효성 검사 및 프로토콜 추가
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingWebView = true;
                _webViewError = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoadingWebView = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoadingWebView = false;
                _webViewError = '페이지를 불러올 수 없습니다';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _switchToWebView() {
    setState(() {
      _showSummary = false;
      if (_controller == null) {
        _initializeWebView();
      }
    });
  }

  void _switchToSummary() {
    setState(() {
      _showSummary = true;
    });
  }

  void _showDiscussionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 제목
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '토론 참여',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // NewsDetailWithDiscussion 사용
              Expanded(
                child: NewsDetailWithDiscussion(
                  news: widget.news,
                  hideNewsContent: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.news.source,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade200,
            height: 1,
          ),
        ),
        actions: [
          if (!_showSummary)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _controller?.reload();
              },
              tooltip: '새로고침',
            ),
          IconButton(
            icon: Icon(_showSummary ? Icons.article : Icons.summarize),
            onPressed: _showSummary ? _switchToWebView : _switchToSummary,
            tooltip: _showSummary ? '전문 보기' : '요약 보기',
          ),
        ],
      ),
      body: _showSummary ? _buildSummaryView() : _buildWebView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDiscussionModal,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.comment_outlined),
        label: const Text(
          '토론 참여',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoadingSummary) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'AI가 뉴스를 요약하고 있습니다...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 뱃지
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

            // 제목
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

            // 출처 및 시간
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

            // AI 요약 라벨
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: screenWidth * 0.04,
                  color: const Color(0xD66B7280),
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  'AI 요약',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xD66B7280),
                  ),
                ),
                if (_summaryError != null) ...[
                  SizedBox(width: screenWidth * 0.02),
                  Icon(
                    Icons.info_outline,
                    size: screenWidth * 0.035,
                    color: Colors.orange.shade700,
                  ),
                ],
              ],
            ),
            SizedBox(height: screenWidth * 0.03),

            // 요약 내용
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                _summary,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  height: 1.7,
                  color: const Color(0xFF444444),
                ),
              ),
            ),

            if (_summaryError != null) ...[
              SizedBox(height: screenWidth * 0.02),
              Text(
                '※ $_summaryError. 원본 설명을 표시합니다.',
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            SizedBox(height: screenWidth * 0.06),

            // 전문 보기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _switchToWebView,
                icon: Icon(Icons.article, size: screenWidth * 0.045),
                label: Text(
                  '전문 보기',
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xD66B7280),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }

    return Stack(
      children: [
        if (_webViewError != null)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _webViewError!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _controller?.reload();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          WebViewWidget(controller: _controller!),

        // 로딩 인디케이터
        if (_isLoadingWebView)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
              ),
            ),
          ),
      ],
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
}