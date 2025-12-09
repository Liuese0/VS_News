// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // ========== 로컬 캐시 ==========
  final Map<String, _NewsStats> _statsCache = {};
  final Duration _cacheDuration = const Duration(minutes: 5);

  // ========== 즐겨찾기 관리 ==========

  /// 즐겨찾기 추가 (뉴스 메타데이터 포함)
  Future<void> addFavorite(String newsUrl, {
    String? title,
    String? description,
    String? imageUrl,
    String? source,
    DateTime? publishedAt,
  }) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = _generateFavoriteId(uid, newsUrl);

    final batch = _firestore.batch();

    // 1. favorites 문서 생성
    batch.set(
      _firestore.collection('favorites').doc(favoriteId),
      {
        'userId': uid,
        'newsUrl': newsUrl,
        'title': title ?? '제목 없음',
        'description': description ?? '',
        'imageUrl': imageUrl,
        'source': source ?? '알 수 없음',
        'publishedAt': publishedAt != null
            ? Timestamp.fromDate(publishedAt)
            : FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    // 2. 유저 favoriteCount 증가
    batch.update(
      _firestore.collection('users').doc(uid),
      {'favoriteCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  /// 즐겨찾기 제거
  Future<void> removeFavorite(String newsUrl) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = _generateFavoriteId(uid, newsUrl);

    final batch = _firestore.batch();

    batch.delete(_firestore.collection('favorites').doc(favoriteId));
    batch.update(
      _firestore.collection('users').doc(uid),
      {'favoriteCount': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  /// 즐겨찾기 여부 확인
  Future<bool> isFavorite(String newsUrl) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = _generateFavoriteId(uid, newsUrl);
    final doc = await _firestore.collection('favorites').doc(favoriteId).get();
    return doc.exists;
  }

  /// 사용자의 모든 즐겨찾기 URL만 가져오기
  Future<List<String>> getUserFavorites() async {
    final uid = await _authService.getCurrentUid();

    final snapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) => doc.data()['newsUrl'] as String).toList();
  }

  /// 사용자의 즐겨찾기 + 통계 한 번에 가져오기 (최적화)
  Future<List<Map<String, dynamic>>> getUserFavoritesWithStats() async {
    final uid = await _authService.getCurrentUid();

    // 1. 즐겨찾기 목록 가져오기 (1회 쿼리)
    final favoritesSnapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    if (favoritesSnapshot.docs.isEmpty) return [];

    final newsUrls = favoritesSnapshot.docs
        .map((doc) => doc.data()['newsUrl'] as String)
        .toList();

    // 2. 뉴스 통계 배치로 가져오기 (1회 쿼리)
    final statsMap = await _getNewsStatsBatch(newsUrls);

    // 3. 결과 조합
    return favoritesSnapshot.docs.map((doc) {
      final data = doc.data();
      final newsUrl = data['newsUrl'] as String;
      final stats = statsMap[newsUrl];

      return {
        'newsUrl': newsUrl,
        'title': data['title'] ?? '제목 없음',
        'description': data['description'] ?? '',
        'imageUrl': data['imageUrl'],
        'source': data['source'] ?? '알 수 없음',
        'publishedAt': data['publishedAt'],
        'createdAt': data['createdAt'],
        'commentCount': stats?.commentCount ?? 0,
        'participantCount': stats?.participantCount ?? 0,
      };
    }).toList();
  }

  // 기존 메서드 호환성 유지
  Future<List<Map<String, dynamic>>> getUserFavoritesWithDetails() async {
    return getUserFavoritesWithStats();
  }

  // ========== 투표 관리 ==========

  /// 투표하기 (찬성/반대)
  Future<void> vote({
    required String newsUrl,
    required String stance, // 'pro' or 'con'
    String? newsTitle,
    String? newsDescription,
    String? newsImageUrl,
    String? newsSource,
  }) async {
    final uid = await _authService.getCurrentUid();
    final newsStatsId = _generateNewsStatsId(newsUrl);
    final voteId = _generateVoteId(uid, newsUrl);

    await _firestore.runTransaction((transaction) async {
      // 1. 기존 투표 확인
      final voteRef = _firestore.collection('votes').doc(voteId);
      final voteDoc = await transaction.get(voteRef);

      final statsRef = _firestore.collection('newsStats').doc(newsStatsId);
      final statsDoc = await transaction.get(statsRef);

      if (voteDoc.exists) {
        // 이미 투표한 경우 - 입장 변경
        final oldStance = voteDoc.data()!['stance'] as String;

        if (oldStance != stance) {
          // 입장이 바뀐 경우에만 업데이트
          transaction.update(voteRef, {
            'stance': stance,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 통계 업데이트
          if (statsDoc.exists) {
            final data = statsDoc.data()!;
            final proVotes = (data['proVotes'] ?? 0) as int;
            final conVotes = (data['conVotes'] ?? 0) as int;

            transaction.update(statsRef, {
              'proVotes': stance == 'pro' ? proVotes + 1 : proVotes - 1,
              'conVotes': stance == 'con' ? conVotes + 1 : conVotes - 1,
            });
          }
        }
      } else {
        // 새로운 투표
        transaction.set(voteRef, {
          'userId': uid,
          'newsUrl': newsUrl,
          'stance': stance,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 통계 업데이트
        if (statsDoc.exists) {
          final data = statsDoc.data()!;
          final participants = List<String>.from(data['participants'] ?? []);
          final isNewParticipant = !participants.contains(uid);

          transaction.update(statsRef, {
            if (stance == 'pro') 'proVotes': FieldValue.increment(1),
            if (stance == 'con') 'conVotes': FieldValue.increment(1),
            if (isNewParticipant) 'participants': FieldValue.arrayUnion([uid]),
            if (isNewParticipant) 'participantCount': FieldValue.increment(1),
            if (newsTitle != null && (data['title'] == null || data['title'] == '뉴스 제목'))
              'title': newsTitle,
            if (newsDescription != null && (data['description'] == null || data['description'] == ''))
              'description': newsDescription,
            if (newsImageUrl != null && data['imageUrl'] == null)
              'imageUrl': newsImageUrl,
            if (newsSource != null && (data['source'] == null || data['source'] == '알 수 없음'))
              'source': newsSource,
          });
        } else {
          // 새로운 뉴스 통계 생성
          transaction.set(statsRef, {
            'newsUrl': newsUrl,
            'proVotes': stance == 'pro' ? 1 : 0,
            'conVotes': stance == 'con' ? 1 : 0,
            'commentCount': 0,
            'participantCount': 1,
            'participants': [uid],
            'createdAt': FieldValue.serverTimestamp(),
            'title': newsTitle ?? '뉴스 제목',
            'description': newsDescription ?? '',
            'imageUrl': newsImageUrl,
            'source': newsSource ?? '알 수 없음',
          });
        }
      }
    });

    // 로컬 캐시 무효화
    _statsCache.remove(newsUrl);
  }

  /// 사용자의 투표 가져오기
  Future<String?> getUserVote(String newsUrl) async {
    final uid = await _authService.getCurrentUid();
    final voteId = _generateVoteId(uid, newsUrl);

    final doc = await _firestore.collection('votes').doc(voteId).get();

    if (doc.exists) {
      return doc.data()!['stance'] as String;
    }
    return null;
  }

  /// 투표 통계 가져오기
  Future<Map<String, int>> getVoteStats(String newsUrl) async {
    final statsId = _generateNewsStatsId(newsUrl);
    final doc = await _firestore.collection('newsStats').doc(statsId).get();

    if (doc.exists) {
      final data = doc.data()!;
      return {
        'pro': data['proVotes'] ?? 0,
        'con': data['conVotes'] ?? 0,
      };
    }

    return {'pro': 0, 'con': 0};
  }

  String _generateVoteId(String uid, String newsUrl) {
    return '${uid}_${newsUrl.hashCode.abs()}';
  }

  // ========== 댓글 관리 ==========

  /// 댓글 작성 (통계 비정규화 포함)
  Future<void> addComment({
    required String newsUrl,
    required String content,
    required String stance,
    String? newsTitle,
    String? newsDescription,
    String? newsImageUrl,
    String? newsSource,
  }) async {
    final uid = await _authService.getCurrentUid();
    final userInfo = await _authService.getUserInfo();
    final newsStatsId = _generateNewsStatsId(newsUrl);

    await _firestore.runTransaction((transaction) async {
      // 1. 기존 뉴스 통계 확인
      final statsRef = _firestore.collection('newsStats').doc(newsStatsId);
      final statsDoc = await transaction.get(statsRef);

      // 2. 댓글 문서 생성
      final commentRef = _firestore.collection('comments').doc();
      transaction.set(commentRef, {
        'userId': uid,
        'nickname': userInfo?['nickname'] ?? '익명',
        'newsUrl': newsUrl,
        'content': content,
        'stance': stance,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. 뉴스 통계 업데이트 (비정규화)
      if (statsDoc.exists) {
        final data = statsDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        final isNewParticipant = !participants.contains(uid);

        transaction.update(statsRef, {
          'commentCount': FieldValue.increment(1),
          'lastCommentAt': FieldValue.serverTimestamp(),
          if (isNewParticipant) 'participants': FieldValue.arrayUnion([uid]),
          if (isNewParticipant) 'participantCount': FieldValue.increment(1),
          // 뉴스 메타데이터가 제공되면 업데이트 (누락된 경우 보완)
          if (newsTitle != null && (data['title'] == null || data['title'] == '뉴스 제목'))
            'title': newsTitle,
          if (newsDescription != null && (data['description'] == null || data['description'] == ''))
            'description': newsDescription,
          if (newsImageUrl != null && data['imageUrl'] == null)
            'imageUrl': newsImageUrl,
          if (newsSource != null && (data['source'] == null || data['source'] == '알 수 없음'))
            'source': newsSource,
        });
      } else {
        // 새로운 뉴스 통계 생성 시 메타데이터 포함
        transaction.set(statsRef, {
          'newsUrl': newsUrl,
          'commentCount': 1,
          'participantCount': 1,
          'participants': [uid],
          'lastCommentAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'title': newsTitle ?? '뉴스 제목',
          'description': newsDescription ?? '',
          'imageUrl': newsImageUrl,
          'source': newsSource ?? '알 수 없음',
        });
      }

      // 4. 유저 commentCount 증가
      final userRef = _firestore.collection('users').doc(uid);
      transaction.update(userRef, {
        'commentCount': FieldValue.increment(1),
      });

      // 5. 참여한 토론에 추가
      final participatedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('participatedDiscussions')
          .doc(newsStatsId);

      transaction.set(participatedRef, {
        'newsUrl': newsUrl,
        'lastCommentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // 로컬 캐시 무효화
    _statsCache.remove(newsUrl);
  }

  /// 특정 뉴스의 댓글 가져오기
  Future<List<Map<String, dynamic>>> getComments(String newsUrl) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('newsUrl', isEqualTo: newsUrl)
        .orderBy('createdAt', descending: true)
        .limit(50) // 페이지네이션 적용
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// 댓글 개수 가져오기 (비정규화된 데이터 사용)
  Future<int> getCommentCount(String newsUrl) async {
    final stats = await _getNewsStats(newsUrl);
    return stats?.commentCount ?? 0;
  }

  /// 참여자 수 가져오기 (비정규화된 데이터 사용)
  Future<int> getParticipantCount(String newsUrl) async {
    final stats = await _getNewsStats(newsUrl);
    return stats?.participantCount ?? 0;
  }

  // ========== 뉴스 통계 (비정규화 + 캐싱) ==========

  /// 단일 뉴스 통계 가져오기 (캐시 사용)
  Future<_NewsStats?> _getNewsStats(String newsUrl) async {
    // 캐시 확인
    final cached = _statsCache[newsUrl];
    if (cached != null && !cached.isExpired) {
      return cached;
    }

    // Firestore에서 가져오기
    final statsId = _generateNewsStatsId(newsUrl);
    final doc = await _firestore.collection('newsStats').doc(statsId).get();

    if (!doc.exists) return null;

    final data = doc.data()!;
    final stats = _NewsStats(
      commentCount: data['commentCount'] ?? 0,
      participantCount: data['participantCount'] ?? 0,
      lastCommentAt: (data['lastCommentAt'] as Timestamp?)?.toDate(),
      fetchedAt: DateTime.now(),
    );

    // 캐시에 저장
    _statsCache[newsUrl] = stats;
    return stats;
  }

  /// 여러 뉴스 통계 배치로 가져오기
  Future<Map<String, _NewsStats>> _getNewsStatsBatch(List<String> newsUrls) async {
    if (newsUrls.isEmpty) return {};

    final Map<String, _NewsStats> result = {};
    final List<String> uncachedUrls = [];

    // 1. 캐시에서 먼저 확인
    for (final url in newsUrls) {
      final cached = _statsCache[url];
      if (cached != null && !cached.isExpired) {
        result[url] = cached;
      } else {
        uncachedUrls.add(url);
      }
    }

    // 2. 캐시에 없는 것들만 Firestore에서 가져오기
    if (uncachedUrls.isNotEmpty) {
      // Firestore는 in 쿼리에 최대 30개까지만 지원
      final chunks = _chunkList(uncachedUrls, 30);

      for (final chunk in chunks) {
        final statsIds = chunk.map(_generateNewsStatsId).toList();

        final snapshot = await _firestore
            .collection('newsStats')
            .where(FieldPath.documentId, whereIn: statsIds)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final newsUrl = data['newsUrl'] as String;

          final stats = _NewsStats(
            commentCount: data['commentCount'] ?? 0,
            participantCount: data['participantCount'] ?? 0,
            lastCommentAt: (data['lastCommentAt'] as Timestamp?)?.toDate(),
            fetchedAt: DateTime.now(),
          );

          result[newsUrl] = stats;
          _statsCache[newsUrl] = stats;
        }
      }
    }

    return result;
  }

  // ========== 인기 토론 ==========

  /// 인기 토론 가져오기 (commentCount 기준 정렬)
  Future<List<Map<String, dynamic>>> getPopularDiscussions({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('newsStats')
        .orderBy('commentCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'newsUrl': data['newsUrl'] ?? '',
        'commentCount': data['commentCount'] ?? 0,
        'participantCount': data['participantCount'] ?? 0,
        'lastCommentTime': data['lastCommentAt'],
        'title': data['title'] ?? '제목 없음',
        'description': data['description'] ?? '',
        'imageUrl': data['imageUrl'],
        'source': data['source'] ?? '뉴스',
      };
    }).toList();
  }

  /// 사용자가 참여한 토론 가져오기
  Future<List<String>> getParticipatedDiscussions({int limit = 10}) async {
    final uid = await _authService.getCurrentUid();

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('participatedDiscussions')
        .orderBy('lastCommentAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) => doc.data()['newsUrl'] as String).toList();
  }

  // ========== 유틸리티 ==========

  String _generateFavoriteId(String uid, String newsUrl) {
    return '${uid}_${newsUrl.hashCode.abs()}';
  }

  String _generateNewsStatsId(String newsUrl) {
    return newsUrl.hashCode.abs().toString();
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// 캐시 초기화
  void clearCache() {
    _statsCache.clear();
  }
}

/// 뉴스 통계 캐시 모델
class _NewsStats {
  final int commentCount;
  final int participantCount;
  final DateTime? lastCommentAt;
  final DateTime fetchedAt;

  _NewsStats({
    required this.commentCount,
    required this.participantCount,
    this.lastCommentAt,
    required this.fetchedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 5);
}