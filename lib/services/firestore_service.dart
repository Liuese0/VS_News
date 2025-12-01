// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // ========== 즐겨찾기 관리 ==========

  // 즐겨찾기 추가 (뉴스 메타데이터 포함)
  Future<void> addFavorite(String newsUrl, {
    String? title,
    String? description,
    String? imageUrl,
    String? source,
    DateTime? publishedAt,
  }) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = '${uid}_${newsUrl.hashCode.abs()}';

    final batch = _firestore.batch();

    // 1. favorites 문서 생성 (뉴스 메타데이터 포함)
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

  // 즐겨찾기 제거
  Future<void> removeFavorite(String newsUrl) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = '${uid}_${newsUrl.hashCode.abs()}';

    final batch = _firestore.batch();

    // 1. favorites 문서 삭제
    batch.delete(_firestore.collection('favorites').doc(favoriteId));

    // 2. 유저 favoriteCount 감소
    batch.update(
      _firestore.collection('users').doc(uid),
      {'favoriteCount': FieldValue.increment(-1)},
    );

    await batch.commit();
  }

  // 즐겨찾기 여부 확인
  Future<bool> isFavorite(String newsUrl) async {
    final uid = await _authService.getCurrentUid();
    final favoriteId = '${uid}_${newsUrl.hashCode.abs()}';

    final doc = await _firestore.collection('favorites').doc(favoriteId).get();
    return doc.exists;
  }

  // 사용자의 모든 즐겨찾기 URL만 가져오기
  Future<List<String>> getUserFavorites() async {
    final uid = await _authService.getCurrentUid();

    final snapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .get();

    return snapshot.docs.map((doc) => doc.data()['newsUrl'] as String).toList();
  }

  // 사용자의 모든 즐겨찾기 가져오기 (메타데이터 포함)
  Future<List<Map<String, dynamic>>> getUserFavoritesWithDetails() async {
    final uid = await _authService.getCurrentUid();

    final snapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'newsUrl': data['newsUrl'] as String,
        'title': data['title'] ?? '제목 없음',
        'description': data['description'] ?? '',
        'imageUrl': data['imageUrl'],
        'source': data['source'] ?? '알 수 없음',
        'publishedAt': data['publishedAt'],
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  // ========== 댓글 관리 ==========

  // 댓글 작성 (트랜잭션)
  Future<void> addComment({
    required String newsUrl,
    required String content,
    required String stance,
  }) async {
    final uid = await _authService.getCurrentUid();
    final userInfo = await _authService.getUserInfo();

    await _firestore.runTransaction((transaction) async {
      // 1. 댓글 문서 생성
      final commentRef = _firestore.collection('comments').doc();
      transaction.set(commentRef, {
        'userId': uid,
        'nickname': userInfo?['nickname'] ?? '익명',
        'newsUrl': newsUrl,
        'content': content,
        'stance': stance,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. 유저 commentCount 증가
      final userRef = _firestore.collection('users').doc(uid);
      transaction.update(userRef, {
        'commentCount': FieldValue.increment(1),
      });

      // 3. 참여한 토론에 추가
      final participatedRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('participatedDiscussions')
          .doc(newsUrl.hashCode.abs().toString());

      transaction.set(participatedRef, {
        'newsUrl': newsUrl,
        'lastCommentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // 특정 뉴스의 댓글 가져오기
  Future<List<Map<String, dynamic>>> getComments(String newsUrl) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('newsUrl', isEqualTo: newsUrl)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // 댓글 개수 가져오기
  Future<int> getCommentCount(String newsUrl) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('newsUrl', isEqualTo: newsUrl)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  // 참여자 수 가져오기
  Future<int> getParticipantCount(String newsUrl) async {
    final snapshot = await _firestore
        .collection('comments')
        .where('newsUrl', isEqualTo: newsUrl)
        .get();

    final uniqueUsers = snapshot.docs
        .map((doc) => doc.data()['userId'])
        .toSet()
        .length;

    return uniqueUsers;
  }

  // ========== 인기 토론 ==========

  // 인기 토론 캐시 가져오기
  Future<List<Map<String, dynamic>>> getPopularDiscussions() async {
    try {
      final doc = await _firestore
          .collection('cache')
          .doc('popularDiscussions')
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      return List<Map<String, dynamic>>.from(data?['items'] ?? []);
    } catch (e) {
      print('인기 토론 로드 실패: $e');
      return [];
    }
  }

  // 사용자가 참여한 토론 가져오기
  Future<List<String>> getParticipatedDiscussions() async {
    final uid = await _authService.getCurrentUid();

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('participatedDiscussions')
        .orderBy('lastCommentAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => doc.data()['newsUrl'] as String).toList();
  }

  // ========== 뉴스 정보 가져오기 ==========

  // 특정 뉴스 URL들의 정보 가져오기
  Future<Map<String, Map<String, dynamic>>> getNewsInfoByUrls(List<String> newsUrls) async {
    if (newsUrls.isEmpty) return {};

    try {
      final Map<String, Map<String, dynamic>> newsInfo = {};

      for (final url in newsUrls) {
        final commentsSnapshot = await _firestore
            .collection('comments')
            .where('newsUrl', isEqualTo: url)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        final commentCountSnapshot = await _firestore
            .collection('comments')
            .where('newsUrl', isEqualTo: url)
            .count()
            .get();

        final participantSnapshot = await _firestore
            .collection('comments')
            .where('newsUrl', isEqualTo: url)
            .get();

        final uniqueUsers = participantSnapshot.docs
            .map((doc) => doc.data()['userId'])
            .toSet()
            .length;

        String title = '뉴스 제목';
        DateTime lastCommentTime = DateTime.now();

        if (commentsSnapshot.docs.isNotEmpty) {
          final firstComment = commentsSnapshot.docs.first.data();
          lastCommentTime = (firstComment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        }

        newsInfo[url] = {
          'newsUrl': url,
          'title': title,
          'commentCount': commentCountSnapshot.count ?? 0,
          'participantCount': uniqueUsers,
          'lastCommentTime': lastCommentTime,
        };
      }

      return newsInfo;
    } catch (e) {
      print('뉴스 정보 로드 실패: $e');
      return {};
    }
  }

  // 즐겨찾기한 뉴스의 상세 정보 가져오기
  Future<List<Map<String, dynamic>>> getFavoriteNewsDetails() async {
    try {
      final uid = await _authService.getCurrentUid();

      final favoritesSnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: uid)
          .get();

      final newsUrls = favoritesSnapshot.docs
          .map((doc) => doc.data()['newsUrl'] as String)
          .toList();

      if (newsUrls.isEmpty) return [];

      final List<Map<String, dynamic>> newsDetails = [];

      for (final url in newsUrls) {
        final commentCountSnapshot = await _firestore
            .collection('comments')
            .where('newsUrl', isEqualTo: url)
            .count()
            .get();

        final commentsSnapshot = await _firestore
            .collection('comments')
            .where('newsUrl', isEqualTo: url)
            .get();

        final uniqueUsers = commentsSnapshot.docs
            .map((doc) => doc.data()['userId'])
            .toSet()
            .length;

        DateTime lastCommentTime = DateTime.now();
        if (commentsSnapshot.docs.isNotEmpty) {
          final latestComment = commentsSnapshot.docs
              .map((doc) => doc.data())
              .reduce((a, b) {
            final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return aTime.isAfter(bTime) ? a : b;
          });
          lastCommentTime = (latestComment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        }

        newsDetails.add({
          'newsUrl': url,
          'title': '즐겨찾기한 뉴스',
          'commentCount': commentCountSnapshot.count ?? 0,
          'participantCount': uniqueUsers,
          'lastCommentTime': lastCommentTime,
        });
      }

      return newsDetails;
    } catch (e) {
      print('즐겨찾기 뉴스 상세 정보 로드 실패: $e');
      return [];
    }
  }
}