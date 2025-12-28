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
  static const Duration _cacheDuration = Duration(hours: 1); // 5분 → 1시간으로 연장

  // ========== 댓글 제한 확인 (서버 시간 기반) ==========

  /// 오늘 작성한 댓글 수 확인 (UTC 기준, 서버 타임스탬프 사용)
  Future<int> getTodayCommentCount() async {
    final uid = await _authService.getCurrentUid();

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyComments')
        .doc('current')  // 고정 문서 ID 사용
        .get();

    if (!doc.exists) return 0;

    final data = doc.data()!;
    final lastReset = (data['lastReset'] as Timestamp).toDate().toUtc();
    final now = DateTime.now().toUtc();

    // UTC 날짜 비교 (년-월-일만 비교)
    if (lastReset.year != now.year ||
        lastReset.month != now.month ||
        lastReset.day != now.day) {
      return 0;  // 날짜가 바뀌었으면 0 반환
    }

    return data['count'] ?? 0;
  }

  /// 일일 댓글 카운트 증가 (UTC 기준, 서버 타임스탬프 사용)
  Future<void> _incrementDailyCommentCount() async {
    final uid = await _authService.getCurrentUid();
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyComments')
        .doc('current');  // 고정 문서 ID 사용

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);

      if (!doc.exists) {
        // 첫 댓글 작성
        transaction.set(docRef, {
          'count': 1,
          'lastReset': FieldValue.serverTimestamp(),
        });
      } else {
        final data = doc.data()!;
        final lastReset = (data['lastReset'] as Timestamp).toDate().toUtc();
        final now = DateTime.now().toUtc();

        // UTC 날짜가 바뀌었는지 확인 (년-월-일 비교)
        if (lastReset.year != now.year ||
            lastReset.month != now.month ||
            lastReset.day != now.day) {
          // 날짜가 바뀌었으면 카운트 리셋
          transaction.update(docRef, {
            'count': 1,
            'lastReset': FieldValue.serverTimestamp(),
          });
        } else {
          // 같은 날이면 카운트 증가
          transaction.update(docRef, {
            'count': FieldValue.increment(1),
            'lastReset': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  // ========== 즐겨찾기 관리 (최대 10개 제한 + 영구 슬롯) ==========

  /// 즐겨찾기 추가 (뉴스 메타데이터 포함, 최대 10개 제한 + 영구 슬롯)
  Future<void> addFavorite(String newsUrl, {
    String? title,
    String? description,
    String? imageUrl,
    String? source,
    DateTime? publishedAt,
    bool usePermanentSlot = false, // 영구 슬롯 사용 여부 (하위 호환성 유지)
  }) async {
    final uid = await _authService.getCurrentUid();
    final userInfo = await _authService.getUserInfo();
    final permanentSlots = userInfo?['permanentBookmarkSlots'] ?? 0;

    // 현재 즐겨찾기 개수 확인
    final currentFavorites = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .get();

    final currentCount = currentFavorites.docs.length;

    // 영구 슬롯을 고려한 최대 한도 계산
    final maxLimit = 10 + permanentSlots;

    // 최대 한도 초과 확인
    if (currentCount >= maxLimit) {
      throw Exception('즐겨찾기는 최대 $maxLimit개까지 가능합니다${permanentSlots > 0 ? ' (영구 슬롯 $permanentSlots개 포함)' : ''}');
    }

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

  /// 투표하기 (찬성/중립/반대)
  Future<void> vote({
    required String newsUrl,
    required String stance, // 'pro', 'neutral', or 'con'
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
            final neutralVotes = (data['neutralVotes'] ?? 0) as int;
            final conVotes = (data['conVotes'] ?? 0) as int;

            // 이전 입장에서 -1
            final updateData = <String, dynamic>{};
            if (oldStance == 'pro') updateData['proVotes'] = proVotes - 1;
            if (oldStance == 'neutral') updateData['neutralVotes'] = neutralVotes - 1;
            if (oldStance == 'con') updateData['conVotes'] = conVotes - 1;

            // 새로운 입장에 +1
            if (stance == 'pro') updateData['proVotes'] = proVotes + (oldStance == 'pro' ? 0 : 1);
            if (stance == 'neutral') updateData['neutralVotes'] = neutralVotes + (oldStance == 'neutral' ? 0 : 1);
            if (stance == 'con') updateData['conVotes'] = conVotes + (oldStance == 'con' ? 0 : 1);

            transaction.update(statsRef, updateData);
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
            if (stance == 'neutral') 'neutralVotes': FieldValue.increment(1),
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
            'neutralVotes': stance == 'neutral' ? 1 : 0,
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
        'neutral': data['neutralVotes'] ?? 0,
        'con': data['conVotes'] ?? 0,
      };
    }

    return {'pro': 0, 'neutral': 0, 'con': 0};
  }

  String _generateVoteId(String uid, String newsUrl) {
    return '${uid}_${newsUrl.hashCode.abs()}';
  }

  // ========== 댓글 관리 (대댓글 지원) ==========

  /// 댓글 작성 (대댓글 지원, 일일 제한, 글자 수 제한, 아이템 사용)
  Future<String> addComment({
    required String newsUrl,
    required String content,
    required String stance,
    String? parentId,  // 대댓글인 경우 부모 댓글 ID
    String? newsTitle,
    String? newsDescription,
    String? newsImageUrl,
    String? newsSource,
    bool useSpeakingRight = false, // 발언권 사용 여부
    bool useSpeakingExtension = false, // 발언연장권 사용 여부
  }) async {
    // 글자 수 제한
    final contentLength = content.trim().length;
    if (contentLength > 100) {
      throw Exception('댓글은 최대 100자까지 작성 가능합니다');
    }

    // 대댓글 깊이 제한 (1단계만 허용)
    if (parentId != null) {
      final parentDoc = await _firestore.collection('comments').doc(parentId).get();
      if (!parentDoc.exists) {
        throw Exception('부모 댓글을 찾을 수 없습니다');
      }
      final parentDepth = parentDoc.data()!['depth'] ?? 0;
      if (parentDepth >= 1) {
        throw Exception('대댓글에는 답글을 달 수 없습니다');
      }
    }

    final uid = await _authService.getCurrentUid();
    final userInfo = await _authService.getUserInfo();
    final newsStatsId = _generateNewsStatsId(newsUrl);

    String? newCommentId;

    await _firestore.runTransaction((transaction) async {
      // 1. 기존 뉴스 통계 확인
      final statsRef = _firestore.collection('newsStats').doc(newsStatsId);
      final statsDoc = await transaction.get(statsRef);

      // 2. 댓글 문서 생성
      final commentRef = _firestore.collection('comments').doc();
      newCommentId = commentRef.id;

      transaction.set(commentRef, {
        'userId': uid,
        'nickname': userInfo?['nickname'] ?? '익명',
        'newsUrl': newsUrl,
        'content': content.trim(),
        'stance': stance,
        'parentId': parentId,
        'depth': parentId != null ? 1 : 0,
        'replyCount': 0,
        'likeCount': 0,
        'dislikeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. 부모 댓글의 replyCount 증가 (대댓글인 경우)
      if (parentId != null) {
        final parentRef = _firestore.collection('comments').doc(parentId);
        transaction.update(parentRef, {
          'replyCount': FieldValue.increment(1),
        });
      }

      // 4. 뉴스 통계 업데이트 (비정규화)
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

      // 5. 유저 commentCount 증가
      final userRef = _firestore.collection('users').doc(uid);
      transaction.update(userRef, {
        'commentCount': FieldValue.increment(1),
      });

      // 6. 참여한 토론에 추가
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

    // 7. 일일 댓글 카운트 증가 (트랜잭션 외부에서)
    await _incrementDailyCommentCount();

    // 8. 아이템 사용 처리
    if (useSpeakingRight) {
      await _authService.useSpeakingRight();
    }
    if (useSpeakingExtension) {
      await _authService.useSpeakingExtension();
    }

    // 로컬 캐시 무효화
    _statsCache.remove(newsUrl);

    return newCommentId!;
  }

  /// 특정 뉴스의 댓글 가져오기 (대댓글 포함, 계층 구조)
  Future<List<Map<String, dynamic>>> getComments(String newsUrl) async {
    // 1. 모든 댓글 가져오기
    final snapshot = await _firestore
        .collection('comments')
        .where('newsUrl', isEqualTo: newsUrl)
        .orderBy('createdAt', descending: false) // 시간순 정렬 (오래된 것부터)
        .limit(200) // 최대 200개
        .get();

    final allComments = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // 2. 댓글과 대댓글 분리
    final parentComments = allComments.where((c) => c['parentId'] == null).toList();
    final replies = allComments.where((c) => c['parentId'] != null).toList();

    // 3. 각 댓글에 대댓글 매핑
    for (var comment in parentComments) {
      final commentReplies = replies
          .where((r) => r['parentId'] == comment['id'])
          .toList();
      comment['replies'] = commentReplies;
    }

    // 최신 댓글이 위로 오도록 역순 정렬
    parentComments.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return parentComments;
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

  // ========== 인기 토론 (페이지네이션 추가) ==========

  /// 인기 토론 가져오기 (최근 24시간 투표+댓글 수 기준 정렬, 페이지네이션 지원)
  Future<Map<String, dynamic>> getPopularDiscussions({
    int limit = 10, // 페이지당 10개로 변경
    DocumentSnapshot? lastDocument,
  }) async {
    // 최근 24시간 기준 시간 계산
    final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));

    // 최근 24시간 활동이 있는 뉴스를 가져오기 (충분히 많은 수를 가져옴)
    Query query = _firestore
        .collection('newsStats')
        .where('lastCommentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneDayAgo))
        .orderBy('lastCommentAt', descending: true)
        .limit(100); // 충분한 데이터를 가져와서 클라이언트에서 정렬

    final snapshot = await query.get();

    // 투표 수 + 댓글 수 기준으로 정렬
    final discussions = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final commentCount = data['commentCount'] ?? 0;
      final proVotes = data['proVotes'] ?? 0;
      final conVotes = data['conVotes'] ?? 0;
      final totalEngagement = commentCount + proVotes + conVotes;

      return {
        'newsUrl': data['newsUrl'] ?? '',
        'commentCount': commentCount,
        'participantCount': data['participantCount'] ?? 0,
        'proVotes': proVotes,
        'conVotes': conVotes,
        'totalEngagement': totalEngagement,
        'lastCommentTime': data['lastCommentAt'],
        'title': data['title'] ?? '제목 없음',
        'description': data['description'] ?? '',
        'imageUrl': data['imageUrl'],
        'source': data['source'] ?? '뉴스',
        'doc': doc,
      };
    }).toList();

    // 투표+댓글 총합 기준으로 내림차순 정렬
    discussions.sort((a, b) {
      final aEngagement = a['totalEngagement'] as int;
      final bEngagement = b['totalEngagement'] as int;
      return bEngagement.compareTo(aEngagement);
    });

    // 페이지네이션 처리
    final startIndex = lastDocument != null
        ? discussions.indexWhere((d) => (d['doc'] as DocumentSnapshot).id == lastDocument.id) + 1
        : 0;

    final endIndex = (startIndex + limit).clamp(0, discussions.length);
    final paginatedDiscussions = discussions.sublist(
        startIndex.clamp(0, discussions.length),
        endIndex
    );

    // doc 필드 제거 (반환용)
    final result = paginatedDiscussions.map((d) {
      d.remove('doc');
      return d;
    }).toList();

    return {
      'discussions': result,
      'lastDocument': paginatedDiscussions.isNotEmpty
          ? paginatedDiscussions.last['doc']
          : null,
      'hasMore': endIndex < discussions.length,
    };
  }

  /// 논쟁 이슈 가져오기 (최근 1달간 투표+댓글 수 기준 정렬, 상위 10개만)
  Future<List<Map<String, dynamic>>> getControversialIssues() async {
    // 최근 1달 기준 시간 계산
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

    // 최근 1달간 활동이 있는 뉴스를 가져오기
    Query query = _firestore
        .collection('newsStats')
        .where('lastCommentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneMonthAgo))
        .orderBy('lastCommentAt', descending: true)
        .limit(200); // 충분한 데이터를 가져와서 클라이언트에서 정렬

    final snapshot = await query.get();

    // 투표 수 + 댓글 수 기준으로 정렬
    final discussions = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final commentCount = data['commentCount'] ?? 0;
      final proVotes = data['proVotes'] ?? 0;
      final conVotes = data['conVotes'] ?? 0;
      final totalEngagement = commentCount + proVotes + conVotes;

      return {
        'newsUrl': data['newsUrl'] ?? '',
        'commentCount': commentCount,
        'participantCount': data['participantCount'] ?? 0,
        'proVotes': proVotes,
        'conVotes': conVotes,
        'totalEngagement': totalEngagement,
        'lastCommentTime': data['lastCommentAt'],
        'title': data['title'] ?? '제목 없음',
        'description': data['description'] ?? '',
        'imageUrl': data['imageUrl'],
        'source': data['source'] ?? '뉴스',
      };
    }).toList();

    // 투표+댓글 총합 기준으로 내림차순 정렬
    discussions.sort((a, b) {
      final aEngagement = a['totalEngagement'] as int;
      final bEngagement = b['totalEngagement'] as int;
      return bEngagement.compareTo(aEngagement);
    });

    // 상위 10개만 반환
    return discussions.take(10).toList();
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

  /// 여러 뉴스의 통계를 배치로 가져오기
  Future<Map<String, Map<String, dynamic>>> getBatchNewsStats(List<String> newsUrls) async {
    if (newsUrls.isEmpty) return {};

    final Map<String, Map<String, dynamic>> result = {};

    // 최대 10개씩 나눠서 조회 (Firestore in 쿼리 제한)
    final chunks = _chunkList(newsUrls, 10);

    for (final chunk in chunks) {
      final newsStatsIds = chunk.map((url) => _generateNewsStatsId(url)).toList();

      final snapshot = await _firestore
          .collection('newsStats')
          .where(FieldPath.documentId, whereIn: newsStatsIds)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final newsUrl = data['newsUrl'] as String;
        result[newsUrl] = {
          'commentCount': data['commentCount'] ?? 0,
          'participantCount': data['participantCount'] ?? 0,
          'proVotes': data['proVotes'] ?? 0,
          'conVotes': data['conVotes'] ?? 0,
          'lastCommentAt': data['lastCommentAt'],
        };
      }
    }

    // 통계가 없는 뉴스는 기본값 설정
    for (final url in newsUrls) {
      result.putIfAbsent(url, () => {
        'commentCount': 0,
        'participantCount': 0,
        'proVotes': 0,
        'conVotes': 0,
        'lastCommentAt': null,
      });
    }

    return result;
  }

  // ========== 댓글 좋아요/싫어요 ==========

  /// 사용자의 댓글 반응 상태 가져오기 ('like', 'dislike', null)
  Future<String?> getCommentReaction(String commentId) async {
    final uid = await _authService.getCurrentUid();
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('commentReactions')
        .doc(commentId)
        .get();

    if (doc.exists) {
      return doc.data()?['type'] as String?;
    }
    return null;
  }

  /// 댓글 좋아요 토글 (좋아요 <-> 없음, 싫어요 -> 좋아요)
  Future<void> toggleCommentLike(String commentId) async {
    final uid = await _authService.getCurrentUid();
    final reactionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('commentReactions')
        .doc(commentId);

    final commentRef = _firestore.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final reactionDoc = await transaction.get(reactionRef);
      final currentReaction = reactionDoc.exists
          ? (reactionDoc.data()!['type'] as String?)
          : null;

      if (currentReaction == null) {
        // 반응 없음 -> 좋아요
        transaction.set(reactionRef, {
          'type': 'like',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, {
          'likeCount': FieldValue.increment(1),
        });
      } else if (currentReaction == 'like') {
        // 좋아요 -> 반응 없음
        transaction.delete(reactionRef);
        transaction.update(commentRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else if (currentReaction == 'dislike') {
        // 싫어요 -> 좋아요
        transaction.update(reactionRef, {
          'type': 'like',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, {
          'dislikeCount': FieldValue.increment(-1),
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// 댓글 싫어요 토글 (싫어요 <-> 없음, 좋아요 -> 싫어요)
  Future<void> toggleCommentDislike(String commentId) async {
    final uid = await _authService.getCurrentUid();
    final reactionRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('commentReactions')
        .doc(commentId);

    final commentRef = _firestore.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final reactionDoc = await transaction.get(reactionRef);
      final currentReaction = reactionDoc.exists
          ? (reactionDoc.data()!['type'] as String?)
          : null;

      if (currentReaction == null) {
        // 반응 없음 -> 싫어요
        transaction.set(reactionRef, {
          'type': 'dislike',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, {
          'dislikeCount': FieldValue.increment(1),
        });
      } else if (currentReaction == 'dislike') {
        // 싫어요 -> 반응 없음
        transaction.delete(reactionRef);
        transaction.update(commentRef, {
          'dislikeCount': FieldValue.increment(-1),
        });
      } else if (currentReaction == 'like') {
        // 좋아요 -> 싫어요
        transaction.update(reactionRef, {
          'type': 'dislike',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, {
          'likeCount': FieldValue.increment(-1),
          'dislikeCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// 여러 댓글의 반응 상태 일괄 조회
  Future<Map<String, String>> getCommentReactionsBatch(List<String> commentIds) async {
    if (commentIds.isEmpty) return {};

    final uid = await _authService.getCurrentUid();
    final Map<String, String> reactions = {};

    // Firestore는 in 쿼리에 최대 30개까지만 지원
    final chunks = _chunkList(commentIds, 30);

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('commentReactions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        reactions[doc.id] = doc.data()['type'] as String;
      }
    }

    return reactions;
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
      DateTime.now().difference(fetchedAt) > FirestoreService._cacheDuration;
}