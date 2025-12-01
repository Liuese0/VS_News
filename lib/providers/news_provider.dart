// lib/providers/news_provider.dart
import 'package:flutter/material.dart';
import '../models/auto_collected_news.dart';
import '../services/news_auto_service.dart';

class NewsProvider extends ChangeNotifier {
  final NewsAutoService _newsService = NewsAutoService();

  // 뉴스 캐시 (URL을 키로 사용)
  final Map<String, AutoCollectedNews> _newsCache = {};

  // 카테고리별 뉴스 목록
  final Map<String, List<AutoCollectedNews>> _newsByCategory = {};

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

  // 뉴스 로드 및 캐싱
  Future<List<AutoCollectedNews>> loadNews({String category = '전체'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      List<AutoCollectedNews> newsList;

      if (category == '전체') {
        newsList = await _newsService.collectKoreanNews();
      } else {
        newsList = await _newsService.searchNewsByCategory(category);
      }

      // 캐시에 저장 (URL을 키로)
      for (var news in newsList) {
        _newsCache[news.url] = news;
      }

      // 카테고리별로도 저장
      _newsByCategory[category] = newsList;

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