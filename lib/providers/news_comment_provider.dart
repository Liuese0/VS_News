// lib/providers/news_comment_provider.dart
import 'package:flutter/material.dart';
import '../screens/news_explorer_screen.dart';

class NewsCommentProvider extends ChangeNotifier {
  // 뉴스 URL별 댓글 저장
  final Map<String, List<NewsComment>> _commentsByNewsUrl = {};

  // 사용자가 참여한 뉴스 URL 목록 (최신순)
  final List<String> _participatedNewsUrls = [];

  // 뉴스 URL별 참여 인원수
  final Map<String, int> _participantCounts = {};

  // 특정 뉴스의 댓글 가져오기
  List<NewsComment> getComments(String newsUrl) {
    return _commentsByNewsUrl[newsUrl] ?? [];
  }

  // 특정 뉴스의 참여 인원수 가져오기
  int getParticipantCount(String newsUrl) {
    return _participantCounts[newsUrl] ?? 0;
  }

  // 사용자가 특정 뉴스에 참여했는지 확인
  bool hasParticipated(String newsUrl) {
    return _participatedNewsUrls.contains(newsUrl);
  }

  // 참여한 뉴스 URL 목록 (최신순)
  List<String> get participatedNewsUrls => List.unmodifiable(_participatedNewsUrls);

  // 인기 토론 (참여 인원수 상위 10개)
  List<String> getPopularNewsUrls() {
    final entries = _participantCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map((e) => e.key).toList();
  }

  // 댓글 추가
  void addComment(String newsUrl, NewsComment comment) {
    if (!_commentsByNewsUrl.containsKey(newsUrl)) {
      _commentsByNewsUrl[newsUrl] = [];
    }

    _commentsByNewsUrl[newsUrl]!.insert(0, comment); // 최신 댓글을 맨 위에

    // 참여 기록 추가 (중복 제거 후 맨 앞에 추가)
    _participatedNewsUrls.remove(newsUrl);
    _participatedNewsUrls.insert(0, newsUrl);

    // 참여 인원수 업데이트 (댓글 작성자 수 기준)
    final uniqueUsers = _commentsByNewsUrl[newsUrl]!
        .map((c) => c.nickname)
        .toSet()
        .length;
    _participantCounts[newsUrl] = uniqueUsers;

    notifyListeners();
  }

  // 댓글 삭제
  void removeComment(String newsUrl, int commentId) {
    if (_commentsByNewsUrl.containsKey(newsUrl)) {
      _commentsByNewsUrl[newsUrl]!.removeWhere((c) => c.id == commentId);

      // 참여 인원수 재계산
      final uniqueUsers = _commentsByNewsUrl[newsUrl]!
          .map((c) => c.nickname)
          .toSet()
          .length;
      _participantCounts[newsUrl] = uniqueUsers;

      notifyListeners();
    }
  }

  // 전체 초기화
  void clear() {
    _commentsByNewsUrl.clear();
    _participatedNewsUrls.clear();
    _participantCounts.clear();
    notifyListeners();
  }

  // 특정 뉴스의 댓글 개수
  int getCommentCount(String newsUrl) {
    return _commentsByNewsUrl[newsUrl]?.length ?? 0;
  }
}