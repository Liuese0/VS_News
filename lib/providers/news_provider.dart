// lib/providers/news_provider.dart (페이지 번호 방식)
import 'package:flutter/material.dart';
import '../models/auto_collected_news.dart';
import '../services/news_auto_service.dart';

class NewsProvider extends ChangeNotifier {
  final NewsAutoService _newsService = NewsAutoService();

  // 뉴스 캐시 (URL을 키로 사용)
  final Map<String, AutoCollectedNews> _newsCache = {};

  // 카테고리별 뉴스 목록과 페이지 정보
  final Map<String, _CategoryNewsData> _newsByCategory = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // URL로 뉴스 가져오기
  AutoCollectedNews? getNewsByUrl(String url) {
    return _newsCache[url];
  }

  // 여러 URL로 뉴스들 가져오기
  List<AutoCollectedNews> getNewsByUrls(List<String> urls) {
    return urls
        .map((url) => _newsCache[url])
        .where((news) => news != null)
        .cast<AutoCollectedNews>()
        .toList();
  }

  // 초기 뉴스 로드 (페이지 1)
  Future<List<AutoCollectedNews>> loadNews({String category = '전체'}) async {
    return loadNewsPage(category: category, page: 1);
  }

  // 특정 페이지 뉴스 로드
  Future<List<AutoCollectedNews>> loadNewsPage({
    required String category,
    required int page,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 카테고리 데이터 초기화 (페이지 1일 때만)
      if (page == 1) {
        if (!_newsByCategory.containsKey(category)) {
          _newsByCategory[category] = _CategoryNewsData();
        } else {
          _newsByCategory[category]!.reset();
        }
      }

      final categoryData = _newsByCategory[category]!;

      List<AutoCollectedNews> newsList;

      if (category == '전체') {
        newsList = await _newsService.collectKoreanNews(
          page: page,
          pageSize: 20,
        );
      } else {
        newsList = await _newsService.searchNewsByCategory(
          category,
          page: page,
          pageSize: 20,
        );
      }

      // 캐시에 저장
      for (var news in newsList) {
        _newsCache[news.url] = news;
      }

      // 페이지 1이면 교체, 아니면 추가
      if (page == 1) {
        categoryData.newsList = newsList;
      } else {
        categoryData.newsList.addAll(newsList);
      }

      categoryData.currentPage = page;
      categoryData.totalPages = 5; // News API는 보통 5페이지 정도까지 제공

      _isLoading = false;
      notifyListeners();

      return newsList;
    } catch (e) {
      print('뉴스 로드 실패: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // 특정 카테고리 뉴스 목록 가져오기
  List<AutoCollectedNews> getCategoryNews(String category) {
    return _newsByCategory[category]?.newsList ?? [];
  }

  // 현재 페이지 가져오기
  int getCurrentPage(String category) {
    return _newsByCategory[category]?.currentPage ?? 1;
  }

  // 총 페이지 수 가져오기
  int getTotalPages(String category) {
    return _newsByCategory[category]?.totalPages ?? 5;
  }

  // 특정 뉴스를 캐시에 추가
  void addToCache(AutoCollectedNews news) {
    _newsCache[news.url] = news;
    notifyListeners();
  }

  // 캐시 클리어
  void clearCache() {
    _newsCache.clear();
    _newsByCategory.clear();
    notifyListeners();
  }

  // 캐시된 뉴스 개수
  int get cachedNewsCount => _newsCache.length;

  // 하위 호환성을 위한 메서드들
  bool hasMore(String category) {
    final data = _newsByCategory[category];
    if (data == null) return true;
    return data.currentPage < data.totalPages;
  }

  bool isLoadingMore(String category) {
    return false; // 페이지 방식에서는 사용 안 함
  }

  Future<List<AutoCollectedNews>> loadMoreNews(String category) async {
    final data = _newsByCategory[category];
    if (data == null) return [];

    final nextPage = data.currentPage + 1;
    if (nextPage > data.totalPages) return [];

    return loadNewsPage(category: category, page: nextPage);
  }
}

// 카테고리별 뉴스 데이터 관리 클래스
class _CategoryNewsData {
  List<AutoCollectedNews> newsList = [];
  int currentPage = 1;
  int totalPages = 5; // News API 기본값

  void reset() {
    newsList.clear();
    currentPage = 1;
  }
}