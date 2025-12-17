// lib/providers/news_provider.dart (페이지네이션 개선 버전)
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

  // 초기 뉴스 로드
  Future<List<AutoCollectedNews>> loadNews({String category = '전체'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 기존 데이터 초기화
      if (!_newsByCategory.containsKey(category)) {
        _newsByCategory[category] = _CategoryNewsData();
      } else {
        _newsByCategory[category]!.reset();
      }

      final categoryData = _newsByCategory[category]!;

      List<AutoCollectedNews> newsList;

      if (category == '전체') {
        newsList = await _newsService.collectKoreanNews(pageSize: 50);
      } else {
        newsList = await _newsService.searchNewsByCategory(
          category,
          page: 1,
          pageSize: 50,
        );
      }

      // 캐시에 저장
      for (var news in newsList) {
        _newsCache[news.url] = news;
      }

      // 카테고리 데이터 저장
      categoryData.newsList = newsList;
      categoryData.hasMore = newsList.length >= 50;

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

  // 추가 뉴스 로드 (페이지네이션)
  Future<List<AutoCollectedNews>> loadMoreNews(String category) async {
    if (!_newsByCategory.containsKey(category)) {
      return [];
    }

    final categoryData = _newsByCategory[category]!;

    if (categoryData.isLoadingMore || !categoryData.hasMore) {
      return [];
    }

    categoryData.isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = categoryData.currentPage + 1;

      List<AutoCollectedNews> newsList;

      if (category == '전체') {
        newsList = await _newsService.collectKoreanNews(pageSize: 50);
      } else {
        newsList = await _newsService.searchNewsByCategory(
          category,
          page: nextPage,
          pageSize: 50,
        );
      }

      // 캐시에 저장
      for (var news in newsList) {
        _newsCache[news.url] = news;
      }

      // 기존 리스트에 추가
      categoryData.newsList.addAll(newsList);
      categoryData.currentPage = nextPage;
      categoryData.hasMore = newsList.length >= 50;

      categoryData.isLoadingMore = false;
      notifyListeners();

      return newsList;
    } catch (e) {
      print('추가 뉴스 로드 실패: $e');
      categoryData.isLoadingMore = false;
      notifyListeners();
      return [];
    }
  }

  // 특정 카테고리 뉴스 목록 가져오기
  List<AutoCollectedNews> getCategoryNews(String category) {
    return _newsByCategory[category]?.newsList ?? [];
  }

  // 더 불러올 뉴스가 있는지 확인
  bool hasMore(String category) {
    return _newsByCategory[category]?.hasMore ?? true;
  }

  // 로딩 중인지 확인
  bool isLoadingMore(String category) {
    return _newsByCategory[category]?.isLoadingMore ?? false;
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
}

// 카테고리별 뉴스 데이터 관리 클래스
class _CategoryNewsData {
  List<AutoCollectedNews> newsList = [];
  int currentPage = 1;
  bool hasMore = true;
  bool isLoadingMore = false;

  void reset() {
    newsList.clear();
    currentPage = 1;
    hasMore = true;
    isLoadingMore = false;
  }
}