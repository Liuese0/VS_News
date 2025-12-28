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

  // 댓글 반응 상태 캐시 (commentId -> 'like' | 'dislike' | null)
  final Map<String, String?> _commentReactions = {};

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

        // 대댓글 목록 변환
        final repliesData = data['replies'] as List<dynamic>? ?? [];
        final replies = repliesData.map((replyData) {
          final replyCreatedAt = replyData['createdAt'];
          return NewsComment(
            id: replyData['id'],  // 실제 문서 ID
            newsUrl: newsUrl,
            nickname: replyData['nickname'] ?? '익명',
            stance: replyData['stance'] ?? 'pro',
            content: replyData['content'] ?? '',
            createdAt: replyCreatedAt is Timestamp
                ? replyCreatedAt.toDate()
                : DateTime.now(),
            parentId: replyData['parentId'],
            depth: replyData['depth'] ?? 1,
            replyCount: 0,
            likeCount: replyData['likeCount'] ?? 0,
            dislikeCount: replyData['dislikeCount'] ?? 0,
          );
        }).toList();

        return NewsComment(
          id: data['id'],  // 실제 문서 ID 사용
          newsUrl: newsUrl,
          nickname: data['nickname'] ?? '익명',
          stance: data['stance'] ?? 'pro',
          content: data['content'] ?? '',
          createdAt: createdAt is Timestamp
              ? createdAt.toDate()
              : DateTime.now(),
          parentId: data['parentId'],
          depth: data['depth'] ?? 0,
          replyCount: data['replyCount'] ?? 0,
          replies: replies,
          likeCount: data['likeCount'] ?? 0,
          dislikeCount: data['dislikeCount'] ?? 0,
        );
      }).toList();

      final participantCount = await _firestoreService.getParticipantCount(newsUrl);
      _participantCounts[newsUrl] = participantCount;

      // 댓글 반응 상태 로드
      await _loadCommentReactions(newsUrl);

      notifyListeners();
    } catch (e) {
      print('댓글 로드 실패: $e');
    }
  }

  // 댓글 반응 상태 로드
  Future<void> _loadCommentReactions(String newsUrl) async {
    final comments = _commentsByNewsUrl[newsUrl] ?? [];
    final allCommentIds = <String>[];

    for (var comment in comments) {
      allCommentIds.add(comment.id);
      for (var reply in comment.replies) {
        allCommentIds.add(reply.id);
      }
    }

    if (allCommentIds.isNotEmpty) {
      final reactions = await _firestoreService.getCommentReactionsBatch(allCommentIds);
      _commentReactions.addAll(reactions);
    }
  }

  // 특정 댓글의 반응 상태 가져오기
  String? getCommentReaction(String commentId) {
    return _commentReactions[commentId];
  }

  // 특정 댓글의 좋아요/싫어요 수 가져오기
  Map<String, int> getCommentCounts(String newsUrl, String commentId) {
    final comments = _commentsByNewsUrl[newsUrl] ?? [];

    // 일반 댓글 확인
    for (var comment in comments) {
      if (comment.id == commentId) {
        return {
          'likeCount': comment.likeCount,
          'dislikeCount': comment.dislikeCount,
        };
      }

      // 대댓글 확인
      for (var reply in comment.replies) {
        if (reply.id == commentId) {
          return {
            'likeCount': reply.likeCount,
            'dislikeCount': reply.dislikeCount,
          };
        }
      }
    }

    return {'likeCount': 0, 'dislikeCount': 0};
  }

  // 댓글 추가 (Firestore에 저장)
  Future<void> addComment(
      String newsUrl,
      NewsComment comment, {
        String? newsTitle,
        String? newsDescription,
        String? newsImageUrl,
        String? newsSource,
      }) async {
    try {
      await _firestoreService.addComment(
        newsUrl: newsUrl,
        content: comment.content,
        stance: comment.stance,
        newsTitle: newsTitle,
        newsDescription: newsDescription,
        newsImageUrl: newsImageUrl,
        newsSource: newsSource,
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

  // 댓글 개수 (대댓글 포함)
  int getCommentCount(String newsUrl) {
    final comments = _commentsByNewsUrl[newsUrl] ?? [];
    int total = comments.length;

    // 대댓글 개수 추가
    for (var comment in comments) {
      total += comment.replies.length;
    }

    return total;
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
    _commentReactions.clear();
    notifyListeners();
  }

  // 댓글 좋아요 토글
  Future<void> toggleCommentLike(String newsUrl, String commentId) async {
    try {
      final currentReaction = _commentReactions[commentId];

      // 1. 로컬 상태 즉시 업데이트 (낙관적 업데이트)
      if (currentReaction == null) {
        _commentReactions[commentId] = 'like';
        _updateCommentCount(newsUrl, commentId, likeIncrement: 1);
      } else if (currentReaction == 'like') {
        _commentReactions.remove(commentId);
        _updateCommentCount(newsUrl, commentId, likeIncrement: -1);
      } else if (currentReaction == 'dislike') {
        _commentReactions[commentId] = 'like';
        _updateCommentCount(newsUrl, commentId, likeIncrement: 1, dislikeIncrement: -1);
      }

      // 즉시 UI 업데이트
      notifyListeners();

      // 2. 서버 업데이트 (백그라운드)
      await _firestoreService.toggleCommentLike(commentId);

      // 3. 서버와 동기화 (백그라운드에서 실제 데이터 확인)
      await loadComments(newsUrl);
    } catch (e) {
      print('댓글 좋아요 토글 실패: $e');
      // 실패 시 원래 상태로 복원
      await loadComments(newsUrl);
      rethrow;
    }
  }

  // 댓글 싫어요 토글
  Future<void> toggleCommentDislike(String newsUrl, String commentId) async {
    try {
      final currentReaction = _commentReactions[commentId];

      // 1. 로컬 상태 즉시 업데이트 (낙관적 업데이트)
      if (currentReaction == null) {
        _commentReactions[commentId] = 'dislike';
        _updateCommentCount(newsUrl, commentId, dislikeIncrement: 1);
      } else if (currentReaction == 'dislike') {
        _commentReactions.remove(commentId);
        _updateCommentCount(newsUrl, commentId, dislikeIncrement: -1);
      } else if (currentReaction == 'like') {
        _commentReactions[commentId] = 'dislike';
        _updateCommentCount(newsUrl, commentId, likeIncrement: -1, dislikeIncrement: 1);
      }

      // 즉시 UI 업데이트
      notifyListeners();

      // 2. 서버 업데이트 (백그라운드)
      await _firestoreService.toggleCommentDislike(commentId);

      // 3. 서버와 동기화 (백그라운드에서 실제 데이터 확인)
      await loadComments(newsUrl);
    } catch (e) {
      print('댓글 싫어요 토글 실패: $e');
      // 실패 시 원래 상태로 복원
      await loadComments(newsUrl);
      rethrow;
    }
  }

  // 로컬 캐시에서 댓글 카운트 업데이트
  void _updateCommentCount(
      String newsUrl,
      String commentId, {
        int likeIncrement = 0,
        int dislikeIncrement = 0,
      }) {
    final comments = _commentsByNewsUrl[newsUrl];
    if (comments == null) return;

    for (int i = 0; i < comments.length; i++) {
      final comment = comments[i];

      // 일반 댓글 확인
      if (comment.id == commentId) {
        _commentsByNewsUrl[newsUrl]![i] = NewsComment(
          id: comment.id,
          newsUrl: comment.newsUrl,
          nickname: comment.nickname,
          stance: comment.stance,
          content: comment.content,
          createdAt: comment.createdAt,
          parentId: comment.parentId,
          depth: comment.depth,
          replyCount: comment.replyCount,
          replies: comment.replies,
          likeCount: (comment.likeCount + likeIncrement).clamp(0, 999999),
          dislikeCount: (comment.dislikeCount + dislikeIncrement).clamp(0, 999999),
        );
        return;
      }

      // 대댓글 확인
      for (int j = 0; j < comment.replies.length; j++) {
        final reply = comment.replies[j];
        if (reply.id == commentId) {
          final updatedReply = NewsComment(
            id: reply.id,
            newsUrl: reply.newsUrl,
            nickname: reply.nickname,
            stance: reply.stance,
            content: reply.content,
            createdAt: reply.createdAt,
            parentId: reply.parentId,
            depth: reply.depth,
            replyCount: reply.replyCount,
            likeCount: (reply.likeCount + likeIncrement).clamp(0, 999999),
            dislikeCount: (reply.dislikeCount + dislikeIncrement).clamp(0, 999999),
          );

          final updatedReplies = List<NewsComment>.from(comment.replies);
          updatedReplies[j] = updatedReply;

          _commentsByNewsUrl[newsUrl]![i] = NewsComment(
            id: comment.id,
            newsUrl: comment.newsUrl,
            nickname: comment.nickname,
            stance: comment.stance,
            content: comment.content,
            createdAt: comment.createdAt,
            parentId: comment.parentId,
            depth: comment.depth,
            replyCount: comment.replyCount,
            replies: updatedReplies,
            likeCount: comment.likeCount,
            dislikeCount: comment.dislikeCount,
          );
          return;
        }
      }
    }
  }
}