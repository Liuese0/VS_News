// lib/models/auto_collected_news.dart
class AutoCollectedNews {
  final String title;
  final String description;
  final String url;
  final String? imageUrl;
  final String source;
  final DateTime publishedAt;
  String autoCategory;
  List<String> autoTags;

  AutoCollectedNews({
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
    required this.source,
    required this.publishedAt,
    this.autoCategory = '인기',
    this.autoTags = const [],
  });

  factory AutoCollectedNews.fromNewsAPI(Map<String, dynamic> json) {
    return AutoCollectedNews(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'],
      source: json['source']?['name'] ?? '알 수 없음',
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'url': url,
      'image_url': imageUrl,
      'source': source,
      'published_at': publishedAt.toIso8601String(),
      'auto_category': autoCategory,
      'auto_tags': autoTags,
    };
  }
}

// lib/models/debatable_issue.dart
class DebatableIssue {
  final String title;
  final String category;
  final List<AutoCollectedNews> relatedNews;
  final DateTime createdAt;
  final String summary;

  DebatableIssue({
    required this.title,
    required this.category,
    required this.relatedNews,
    required this.createdAt,
    String? summary,
  }) : summary = summary ?? _generateSummary(relatedNews);

  static String _generateSummary(List<AutoCollectedNews> newsList) {
    if (newsList.isEmpty) return '';

    // 관련 뉴스들의 제목과 설명을 기반으로 요약 생성
    List<String> keyPoints = [];
    for (var news in newsList.take(3)) {
      if (news.description.isNotEmpty) {
        keyPoints.add(news.description);
      }
    }

    if (keyPoints.isEmpty) {
      return '${newsList.length}개의 관련 뉴스가 있는 주요 이슈입니다.';
    }

    String combinedText = keyPoints.join(' ');
    if (combinedText.length > 200) {
      return combinedText.substring(0, 200) + '...';
    }

    return combinedText;
  }

  // 찬성/반대 뉴스 분리
  List<AutoCollectedNews> get proNews {
    List<String> proKeywords = ['환영', '찬성', '긍정', '지지', '호응', '추진'];
    return relatedNews.where((news) {
      String text = (news.title + ' ' + news.description).toLowerCase();
      return proKeywords.any((keyword) => text.contains(keyword));
    }).toList();
  }

  List<AutoCollectedNews> get conNews {
    List<String> conKeywords = ['반대', '우려', '비판', '논란', '반발', '문제'];
    return relatedNews.where((news) {
      String text = (news.title + ' ' + news.description).toLowerCase();
      return conKeywords.any((keyword) => text.contains(keyword));
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'summary': summary,
      'related_news': relatedNews.map((news) => news.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// lib/models/news_category.dart
class NewsCategory {
  final String name;
  final String icon;
  final List<String> tags;
  final int newsCount;

  const NewsCategory({
    required this.name,
    required this.icon,
    required this.tags,
    this.newsCount = 0,
  });

  static const List<NewsCategory> allCategories = [
    NewsCategory(
      name: '인기',
      icon: '🔥',
      tags: [],
    ),
    NewsCategory(
      name: '정치',
      icon: '🏛️',
      tags: ['국내', '글로벌', '미국', '북한', '일본', '중국'],
    ),
    NewsCategory(
      name: '경제',
      icon: '💰',
      tags: ['주식', '코인', '부동산', '금융', '무역'],
    ),
    NewsCategory(
      name: '산업',
      icon: '🏭',
      tags: ['반도체', '자동차', '조선', '철강', '화학'],
    ),
    NewsCategory(
      name: '사회',
      icon: '👥',
      tags: ['교육', '의료', '환경', '안전'],
    ),
    NewsCategory(
      name: '문화',
      icon: '🎭',
      tags: ['K-컬처', '영화', '드라마', '관광'],
    ),
    NewsCategory(
      name: '과학',
      icon: '🔬',
      tags: ['IT', 'AI', '바이오', '우주'],
    ),
    NewsCategory(
      name: '스포츠',
      icon: '⚽',
      tags: ['축구', '야구', '올림픽', 'e스포츠'],
    ),
    NewsCategory(
      name: '연예',
      icon: '🎬',
      tags: ['K-POP', '드라마', '예능', '영화'],
    ),
  ];

  static NewsCategory? findByName(String name) {
    try {
      return allCategories.firstWhere((category) => category.name == name);
    } catch (e) {
      return null;
    }
  }
}