// lib/providers/news_comment_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../screens/news_explorer_screen.dart';

class NewsCommentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // 로컬 캐시
  final Map<String, List<NewsComment>> _commentsByNewsUrl = {};
  final Map<String, int> _participantCounts = {};
  List<String> _participatedNewsUrls = [];

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

  // 참여한 뉴스 URL 목록
  List<String> get participatedNewsUrls => List.unmodifiable(_participatedNewsUrls);

  // 인기 토론 가져오기
  List<String> getPopularNewsUrls() {
    final entries = _participantCounts.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map((e) => e.key).toList();
  }

  // Firestore에서 댓글 로드
  Future<void> loadComments(String newsUrl) async {
    try {
      final comments = await _firestoreService.getComments(newsUrl);
      _commentsByNewsUrl[newsUrl] = comments.map((data) {
        final createdAt = data['createdAt'];
        return NewsComment(
          id: data['id'].hashCode,
          newsUrl: newsUrl,
          nickname: data['nickname'] ?? '익명',
          stance: data['stance'] ?? 'pro',
          content: data['content'] ?? '',
          createdAt: createdAt is Timestamp
              ? createdAt.toDate()
              : DateTime.now(),
        );
      }).toList();

      final participantCount = await _firestoreService.getParticipantCount(newsUrl);
      _participantCounts[newsUrl] = participantCount;

      notifyListeners();
    } catch (e) {
      print('댓글 로드 실패: $e');
    }
  }

  // 댓글 추가 (Firestore에 저장)
  Future<void> addComment(String newsUrl, NewsComment comment) async {
    try {
      await _firestoreService.addComment(
        newsUrl: newsUrl,
        content: comment.content,
        stance: comment.stance,
      );

      // 로컬 캐시 업데이트
      if (!_commentsByNewsUrl.containsKey(newsUrl)) {
        _commentsByNewsUrl[newsUrl] = [];
      }
      _commentsByNewsUrl[newsUrl]!.insert(0, comment);

      // 참여 기록 추가
      _participatedNewsUrls.remove(newsUrl);
      _participatedNewsUrls.insert(0, newsUrl);

      // 참여 인원수 업데이트
      await loadComments(newsUrl);

      notifyListeners();
    } catch (e) {
      print('댓글 추가 실패: $e');
      rethrow;
    }
  }

  // 댓글 개수
  int getCommentCount(String newsUrl) {
    return _commentsByNewsUrl[newsUrl]?.length ?? 0;
  }

  // 참여한 토론 로드
  Future<void> loadParticipatedDiscussions() async {
    try {
      _participatedNewsUrls = await _firestoreService.getParticipatedDiscussions();
      notifyListeners();
    } catch (e) {
      print('참여 토론 로드 실패: $e');
    }
  }

  // 전체 초기화
  void clear() {
    _commentsByNewsUrl.clear();
    _participatedNewsUrls.clear();
    _participantCounts.clear();
    notifyListeners();
  }
}