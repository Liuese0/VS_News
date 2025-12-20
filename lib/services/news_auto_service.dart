// lib/services/news_auto_service.dart (페이지 번호 방식)
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import '../models/auto_collected_news.dart';

class NewsAutoService {
  static final NewsAutoService _instance = NewsAutoService._internal();
  factory NewsAutoService() => _instance;
  NewsAutoService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // 카테고리별 키워드 매핑
  static const Map<String, List<String>> categoryKeywords = {
    '정치': ['국정감사', '국회', '대통령', '정부', '여당', '야당', '선거', '정책', '법안', '의원'],
    '경제': ['경제', '금리', '환율', '주가', '증시', '코스피', '코스닥', 'GDP', '인플레이션', '물가'],
    '산업': ['삼성', 'LG', '현대', '기업', '산업', '제조업', '반도체', '자동차', '조선', '건설'],
    '사회': ['사회', '교육', '의료', '복지', '범죄', '사고', '재해', '안전', '환경', '교통'],
    '문화': ['문화', '예술', '영화', '드라마', '음악', '전시', '공연', '축제', '관광', '여행'],
    '과학기술': ['과학', '기술', 'IT', 'AI', '인공지능', '연구', '개발', '혁신', '디지털', '바이오'],
    '스포츠': ['스포츠', '축구', '야구', '농구', '배구', '골프', '테니스', '올림픽', '월드컵', '선수'],
    '연예': ['연예', '아이돌', '가수', '배우', '방송', 'K-POP', '드라마', '예능', '엔터테인먼트', '셀럽'],
  };

  // 태그별 키워드 매핑
  static const Map<String, Map<String, List<String>>> tagKeywords = {
    '정치': {
      '국내': ['국내정치', '한국정치', '내정', '국정'],
      '글로벌': ['국제정치', '외교', '국제관계', '해외'],
      '미국': ['미국', '바이든', '트럼프', '백악관', '워싱턴'],
      '북한': ['북한', '김정은', '평양', '핵', '미사일'],
      '일본': ['일본', '기시다', '도쿄', '독도', '위안부'],
      '중국': ['중국', '시진핑', '베이징', '사드', '무역전쟁'],
    },
    '경제': {
      '주식': ['주식', '증권', '투자', '상장', '배당'],
      '코인': ['비트코인', '암호화폐', '가상화폐', '블록체인', '이더리움'],
      '부동산': ['부동산', '아파트', '집값', '전세', '매매'],
      '금융': ['은행', '금융', '대출', '예금', '보험'],
      '무역': ['수출', '수입', '무역', '관세', '무역수지'],
    },
    '산업': {
      '반도체': ['반도체', '칩', '메모리', '삼성전자', 'SK하이닉스'],
      '자동차': ['자동차', '현대차', '기아', '전기차', 'EV'],
      '조선': ['조선', '선박', '현대중공업', '대우조선해양'],
      '철강': ['철강', '포스코', '제철', '스테인리스'],
      '화학': ['화학', '석유화학', 'LG화학', 'SK케미칼'],
    },
    '사회': {
      '교육': ['교육', '학교', '대학', '입시', '수능'],
      '의료': ['의료', '병원', '코로나', '백신', '질병'],
      '환경': ['환경', '기후변화', '탄소중립', '미세먼지'],
      '안전': ['안전', '사고', '재해', '화재', '교통사고'],
    },
    '문화': {
      'K-컬처': ['한류', 'K-POP', 'K-드라마', '한국문화'],
      '영화': ['영화', '시네마', '영화제', '박스오피스'],
      '드라마': ['드라마', 'TV', '방송', 'OTT'],
      '관광': ['관광', '여행', '축제', '문화재'],
    },
    '과학기술': {
      'IT': ['IT', '정보기술', '소프트웨어', '앱'],
      'AI': ['AI', '인공지능', '머신러닝', '딥러닝'],
      '바이오': ['바이오', '생명과학', '의학', '신약'],
      '우주': ['우주', '항공', '위성', '로켓'],
    },
    '스포츠': {
      '축구': ['축구', '월드컵', '손흥민', '국가대표'],
      '야구': ['야구', 'KBO', '프로야구', '월드베이스볼클래식'],
      '올림픽': ['올림픽', '패럴림픽', '아시안게임'],
      'e스포츠': ['e스포츠', '게임', 'LoL', '프로게이머'],
    },
    '연예': {
      'K-POP': ['K-POP', '아이돌', 'BTS', '블랙핑크'],
      '드라마': ['드라마', 'K-드라마', '넷플릭스'],
      '예능': ['예능', '버라이어티', '토크쇼'],
      '영화': ['영화배우', '한국영화', '칸영화제'],
    },
  };

  // 한국 뉴스 소스 리스트
  static const List<String> koreanNewsSources = [
    'yonhap-news-agency',
  ];

  // 뉴스 자동 수집
  Future<List<AutoCollectedNews>> collectKoreanNews({
    String category = 'general',
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      List<AutoCollectedNews> allNews = [];

      // 1. News API에서 한국 뉴스 가져오기
      final newsApiResults = await _fetchFromNewsAPI(category, page, pageSize);
      allNews.addAll(newsApiResults);

      // 2. 카테고리와 태그 자동 분류
      for (var news in allNews) {
        news.autoCategory = _classifyCategory(news.title + ' ' + news.description);
        news.autoTags = _classifyTags(news.title + ' ' + news.description, news.autoCategory);
      }

      return allNews;
    } catch (e) {
      print('뉴스 수집 오류: $e');
      return [];
    }
  }

  // News API에서 뉴스 가져오기
  Future<List<AutoCollectedNews>> _fetchFromNewsAPI(String category, int page, int pageSize) async {
    try {
      final response = await _dio.get(
        'https://newsapi.org/v2/top-headlines',
        queryParameters: {
          'country': 'kr',
          'category': category == 'general' ? null : category,
          'page': page,
          'pageSize': pageSize,
          'apiKey': ApiConstants.newsApiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> articles = response.data['articles'] ?? [];
        return articles.map((article) => AutoCollectedNews.fromNewsAPI(article)).toList();
      }
      return [];
    } catch (e) {
      print('News API 오류: $e');
      return [];
    }
  }

  // 카테고리 자동 분류
  String _classifyCategory(String text) {
    String normalizedText = text.toLowerCase();
    Map<String, int> categoryScores = {};

    for (String category in categoryKeywords.keys) {
      int score = 0;
      for (String keyword in categoryKeywords[category]!) {
        if (normalizedText.contains(keyword.toLowerCase())) {
          score += 1;
        }
      }
      if (score > 0) {
        categoryScores[category] = score;
      }
    }

    if (categoryScores.isEmpty) return '인기';

    // 가장 높은 점수를 가진 카테고리 반환
    return categoryScores.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  // 태그 자동 분류
  List<String> _classifyTags(String text, String category) {
    String normalizedText = text.toLowerCase();
    List<String> tags = [];

    if (tagKeywords.containsKey(category)) {
      Map<String, List<String>> categoryTags = tagKeywords[category]!;

      for (String tag in categoryTags.keys) {
        for (String keyword in categoryTags[tag]!) {
          if (normalizedText.contains(keyword.toLowerCase())) {
            if (!tags.contains(tag)) {
              tags.add(tag);
            }
            break;
          }
        }
      }
    }

    return tags;
  }

  // 카테고리별 뉴스 검색 (페이지 번호 방식)
  Future<List<AutoCollectedNews>> searchNewsByCategory(
      String category, {
        int page = 1,
        int pageSize = 20,
      }) async {
    try {
      String query = categoryKeywords[category]?.join(' OR ') ?? category;

      final response = await _dio.get(
        'https://newsapi.org/v2/everything',
        queryParameters: {
          'q': query,
          'language': 'ko',
          'sortBy': 'publishedAt',
          'page': page,
          'pageSize': pageSize,
          'apiKey': ApiConstants.newsApiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> articles = response.data['articles'] ?? [];
        List<AutoCollectedNews> news = articles
            .map((article) => AutoCollectedNews.fromNewsAPI(article))
            .toList();

        // 카테고리와 태그 분류
        for (var item in news) {
          item.autoCategory = category;
          item.autoTags = _classifyTags(item.title + ' ' + item.description, category);
        }

        return news;
      }
      return [];
    } catch (e) {
      print('카테고리별 뉴스 검색 오류: $e');
      return [];
    }
  }

  // 태그별 뉴스 검색
  Future<List<AutoCollectedNews>> searchNewsByTag(String category, String tag) async {
    try {
      List<String> keywords = tagKeywords[category]?[tag] ?? [tag];
      String query = keywords.join(' OR ');

      final response = await _dio.get(
        'https://newsapi.org/v2/everything',
        queryParameters: {
          'q': query,
          'language': 'ko',
          'sortBy': 'publishedAt',
          'pageSize': 15,
          'apiKey': ApiConstants.newsApiKey,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> articles = response.data['articles'] ?? [];
        List<AutoCollectedNews> news = articles
            .map((article) => AutoCollectedNews.fromNewsAPI(article))
            .toList();

        // 카테고리와 태그 분류
        for (var item in news) {
          item.autoCategory = category;
          item.autoTags = [tag];
        }

        return news;
      }
      return [];
    } catch (e) {
      print('태그별 뉴스 검색 오류: $e');
      return [];
    }
  }

  // 논쟁적인 이슈 자동 생성
  Future<List<DebatableIssue>> generateDebatableIssues() async {
    List<DebatableIssue> issues = [];

    try {
      // 정치, 경제, 사회 카테고리에서 논쟁적인 뉴스 찾기
      List<String> debatableCategories = ['정치', '경제', '사회'];

      for (String category in debatableCategories) {
        List<AutoCollectedNews> categoryNews = await searchNewsByCategory(category);

        // 논쟁적인 키워드가 포함된 뉴스 필터링
        List<String> controversialKeywords = [
          '논란', '반대', '찬성', '갈등', '대립', '비판', '우려', '환영',
          '반발', '항의', '토론', '논쟁', '의견', '입장', '견해'
        ];

        List<AutoCollectedNews> controversialNews = categoryNews.where((news) {
          String text = (news.title + ' ' + news.description).toLowerCase();
          return controversialKeywords.any((keyword) => text.contains(keyword));
        }).toList();

        // 유사한 주제끼리 그룹화하여 이슈 생성
        Map<String, List<AutoCollectedNews>> groupedNews = _groupSimilarNews(controversialNews);

        for (String topic in groupedNews.keys) {
          if (groupedNews[topic]!.length >= 2) { // 최소 2개 이상의 뉴스가 있어야 이슈 생성
            DebatableIssue issue = DebatableIssue(
              title: topic,
              category: category,
              relatedNews: groupedNews[topic]!,
              createdAt: DateTime.now(),
            );
            issues.add(issue);
          }
        }
      }

      return issues.take(10).toList(); // 최대 10개 이슈만 반환
    } catch (e) {
      print('논쟁적 이슈 생성 오류: $e');
      return [];
    }
  }

  // 유사한 뉴스 그룹화
  Map<String, List<AutoCollectedNews>> _groupSimilarNews(List<AutoCollectedNews> newsList) {
    Map<String, List<AutoCollectedNews>> groups = {};

    for (AutoCollectedNews news in newsList) {
      String topic = _extractMainTopic(news.title);

      if (groups.containsKey(topic)) {
        groups[topic]!.add(news);
      } else {
        groups[topic] = [news];
      }
    }

    return groups;
  }

  // 메인 토픽 추출 (간단한 키워드 기반)
  String _extractMainTopic(String title) {
    List<String> commonTopics = [
      '최저임금', '부동산', '세금', '교육', '의료', '환경', '에너지',
      '교통', '복지', '연금', '일자리', '임대료', '전세', '주택'
    ];

    for (String topic in commonTopics) {
      if (title.contains(topic)) {
        return topic + ' 정책';
      }
    }

    // 특정 토픽을 찾지 못하면 첫 번째 명사구 추출 시도
    List<String> words = title.split(' ');
    if (words.length >= 2) {
      return words.take(2).join(' ');
    }

    return title.length > 20 ? title.substring(0, 20) + '...' : title;
  }
}