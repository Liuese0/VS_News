// lib/widgets/news_comparison_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../utils/constants.dart';

class NewsComparisonCard extends StatelessWidget {
  final List<News> newsList;

  const NewsComparisonCard({
    super.key,
    required this.newsList,
  });

  @override
  Widget build(BuildContext context) {
    final proNews = newsList.where((n) => n.isPro).toList();
    final conNews = newsList.where((n) => !n.isPro).toList();

    return Container(
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
          // 헤더
          Container(
            padding: const EdgeInsets.all(AppDimensions.padding),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.borderRadius),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article, color: AppColors.primaryColor),
                SizedBox(width: 8),
                Text(
                  '관련 뉴스',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // 뉴스 내용
          if (newsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                '관련 뉴스가 없습니다',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppDimensions.padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 찬성 뉴스
                  Expanded(
                    child: _buildNewsSection(
                      title: '찬성',
                      color: Colors.blue,
                      icon: Icons.thumb_up,
                      newsList: proNews,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 반대 뉴스
                  Expanded(
                    child: _buildNewsSection(
                      title: '반대',
                      color: Colors.red,
                      icon: Icons.thumb_down,
                      newsList: conNews,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNewsSection({
    required String title,
    required Color color,
    required IconData icon,
    required List<News> newsList,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 뉴스 목록
        if (newsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '관련 뉴스가 없습니다',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...newsList.map((news) => _buildNewsItem(news, color)),
      ],
    );
  }

  Widget _buildNewsItem(News news, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            news.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            news.summary,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _launchUrl(news.url),
            child: Text(
              '원문 보기 →',
              style: TextStyle(
                fontSize: 12,
                color: color,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('URL 실행 오류: $e');
    }
  }
}