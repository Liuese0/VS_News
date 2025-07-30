// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _keywordController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: '이슈 등록 (관리자)',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이슈 정보 입력 섹션
              _buildSectionCard(
                title: '이슈 정보',
                icon: Icons.info_outline,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '이슈 제목',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '제목을 입력해주세요';
                        }
                        return null;
                      },
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _summaryController,
                      decoration: const InputDecoration(
                        labelText: '이슈 요약',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '요약을 입력해주세요';
                        }
                        return null;
                      },
                      maxLines: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 뉴스 검색 섹션
              _buildSectionCard(
                title: '관련 뉴스 검색',
                icon: Icons.search,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keywordController,
                            decoration: const InputDecoration(
                              labelText: '뉴스 검색 키워드',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.newspaper),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSearching ? null : _searchNews,
                          child: _isSearching
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text('검색'),
                        ),
                      ],
                    ),

                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '검색 결과',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final article = _searchResults[index];
                            return ListTile(
                              title: Text(
                                article['title'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                article['description'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () {
                                // 뉴스 선택 처리
                                _showNewsDetailDialog(article);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 등록 버튼
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerIssue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : const Text(
                    '이슈 등록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _searchNews() async {
    if (_keywordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색 키워드를 입력해주세요')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _apiService.searchNews(_keywordController.text.trim());
      setState(() {
        _searchResults = results.take(10).toList(); // 최대 10개만 표시
      });

      if (_searchResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검색 결과가 없습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('뉴스 검색 실패: $e')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _showNewsDetailDialog(Map<String, dynamic> article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          article['title'] ?? '',
          style: const TextStyle(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Text(article['description'] ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerIssue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 실제 API 호출로 이슈 등록
      // 여기서는 시뮬레이션만 수행
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이슈가 성공적으로 등록되었습니다'),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context);
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _keywordController.dispose();
    super.dispose();
  }
}