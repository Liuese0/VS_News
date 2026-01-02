// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const String _uidKey = 'device_registered_uid';
  static const String _secretKey = 'your_secret_key_change_this_in_production';

  String? _cachedUid;

  // 기존 계정이 있는지 확인
  Future<bool> hasExistingAccount() async {
    final savedUid = await _secureStorage.read(key: _uidKey);

    if (savedUid != null && savedUid.isNotEmpty) {
      // 서버에 해당 UID가 존재하는지 확인
      final userDoc = await _firestore.collection('users').doc(savedUid).get();
      return userDoc.exists;
    }

    return false;
  }

  // 디바이스 ID 가져오기
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
    } catch (e) {
      print('디바이스 ID 가져오기 실패: $e');
    }
    return '';
  }

  // 디바이스 해시 생성
  String _generateDeviceHash(String deviceId) {
    final bytes = utf8.encode(deviceId + _secretKey);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // UID 초기화
  Future<String> initializeUser() async {
    // 1. 로컬에 저장된 UID 확인
    String? savedUid = await _secureStorage.read(key: _uidKey);

    if (savedUid != null && savedUid.isNotEmpty) {
      final userDoc = await _firestore.collection('users').doc(savedUid).get();

      if (userDoc.exists) {
        _cachedUid = savedUid;
        return savedUid;
      }
    }

    // 2. 새 UID 생성
    final deviceId = await _getDeviceId();

    if (deviceId.isEmpty) {
      throw Exception('디바이스 ID를 가져올 수 없습니다');
    }

    final deviceHash = _generateDeviceHash(deviceId);

    // 3. 이미 등록된 디바이스인지 확인
    final existingUser = await _firestore
        .collection('users')
        .where('deviceHash', isEqualTo: deviceHash)
        .limit(1)
        .get();

    if (existingUser.docs.isNotEmpty) {
      final uid = existingUser.docs.first.id;
      await _secureStorage.write(key: _uidKey, value: uid);
      _cachedUid = uid;
      return uid;
    }

    // 4. 새 계정 생성
    final newUserRef = _firestore.collection('users').doc();
    final uid = newUserRef.id;

    await newUserRef.set({
      'deviceHash': deviceHash,
      'createdAt': FieldValue.serverTimestamp(),
      'tokenCount': 0,
      'favoriteCount': 0,
      'commentCount': 0,
      'nickname': '익명${DateTime.now().millisecondsSinceEpoch % 10000}',
      'speakingRightCount': 0, // 발언권 (댓글 추가권)
      'speakingExtensionCount': 0, // 발언연장권 (50글자 추가권)
      'permanentBookmarkSlots': 0, // 영구 즐겨찾기 슬롯
      // 패스 관련
      'modernPass': null, // 현대인패스 구독 만료일
      'intellectualPass': null, // 지식인패스 구독 만료일
      'sophistPass': null, // 소피스패스 구독 만료일
      'badge': '', // 배지 ('intellectual' 또는 'sophist')
    });

    await _secureStorage.write(key: _uidKey, value: uid);
    _cachedUid = uid;

    return uid;
  }

  // 현재 사용자 UID
  Future<String> getCurrentUid() async {
    if (_cachedUid != null) return _cachedUid!;
    return await initializeUser();
  }

  // 닉네임 업데이트
  Future<void> updateNickname(String nickname) async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 사용자 정보
  Future<Map<String, dynamic>?> getUserInfo() async {
    final uid = await getCurrentUid();
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // 토큰 증가
  Future<void> incrementTokens(int amount) async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'tokenCount': FieldValue.increment(amount),
    });
  }

  // 토큰 감소
  Future<void> decrementTokens(int amount) async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'tokenCount': FieldValue.increment(-amount),
    });
  }

  // 아이템 구매 (토큰 차감 + 아이템 증가)
  Future<void> purchaseItem(String itemType, int tokenCost) async {
    final uid = await getCurrentUid();

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      final currentTokens = userDoc.data()!['tokenCount'] ?? 0;
      if (currentTokens < tokenCost) {
        throw Exception('토큰이 부족합니다');
      }

      // 토큰 차감 및 아이템 증가
      transaction.update(userRef, {
        'tokenCount': FieldValue.increment(-tokenCost),
        itemType: FieldValue.increment(1),
      });
    });
  }

  // 발언권 사용
  Future<void> useSpeakingRight() async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'speakingRightCount': FieldValue.increment(-1),
    });
  }

  // 발언연장권 사용
  Future<void> useSpeakingExtension() async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'speakingExtensionCount': FieldValue.increment(-1),
    });
  }

  // 영구 즐겨찾기 슬롯 사용
  Future<void> usePermanentBookmarkSlot() async {
    final uid = await getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      'permanentBookmarkSlots': FieldValue.increment(-1),
    });
  }

  // 패스 구매/갱신 (토큰으로)
  Future<void> purchasePass(String passType, int tokenCost) async {
    final uid = await getCurrentUid();

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      final userData = userDoc.data()!;
      final currentTokens = userData['tokenCount'] ?? 0;
      if (currentTokens < tokenCost) {
        throw Exception('토큰이 부족합니다');
      }

      // 현재 패스 만료일 가져오기
      final currentExpiry = userData[passType] as Timestamp?;
      final now = DateTime.now();

      // 새로운 만료일 계산 (기존 만료일이 있고 아직 유효하면 거기에 추가, 없으면 현재부터)
      DateTime newExpiry;
      if (currentExpiry != null) {
        final expiryDate = currentExpiry.toDate();
        if (expiryDate.isAfter(now)) {
          newExpiry = DateTime(expiryDate.year, expiryDate.month + 1, expiryDate.day);
        } else {
          newExpiry = DateTime(now.year, now.month + 1, now.day);
        }
      } else {
        newExpiry = DateTime(now.year, now.month + 1, now.day);
      }

      // 패스별 혜택 지급
      Map<String, dynamic> updates = {
        'tokenCount': FieldValue.increment(-tokenCost),
        passType: Timestamp.fromDate(newExpiry),
      };

      // 발언연장권 지급 (최초 구매 시에만)
      if (currentExpiry == null || !currentExpiry.toDate().isAfter(now)) {
        if (passType == 'modernPass') {
          updates['speakingExtensionCount'] = FieldValue.increment(10);
        } else if (passType == 'intellectualPass') {
          updates['speakingExtensionCount'] = FieldValue.increment(30);
          updates['badge'] = 'intellectual';
        } else if (passType == 'sophistPass') {
          updates['badge'] = 'sophist';
        }
      } else {
        // 갱신 시에도 배지 유지
        if (passType == 'intellectualPass') {
          updates['badge'] = 'intellectual';
        } else if (passType == 'sophistPass') {
          updates['badge'] = 'sophist';
        }
      }

      transaction.update(userRef, updates);
    });
  }

  // 패스 활성화 (구글 플레이 결제용 - 토큰 차감 없음)
  Future<void> activatePassFromPurchase(String passType) async {
    final uid = await getCurrentUid();

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      final userData = userDoc.data()!;
      final currentExpiry = userData[passType] as Timestamp?;
      final now = DateTime.now();

      // 새로운 만료일 계산 (기존 만료일이 있고 아직 유효하면 거기에 추가, 없으면 현재부터)
      DateTime newExpiry;
      if (currentExpiry != null) {
        final expiryDate = currentExpiry.toDate();
        if (expiryDate.isAfter(now)) {
          newExpiry = DateTime(expiryDate.year, expiryDate.month + 1, expiryDate.day);
        } else {
          newExpiry = DateTime(now.year, now.month + 1, now.day);
        }
      } else {
        newExpiry = DateTime(now.year, now.month + 1, now.day);
      }

      // 패스별 혜택 지급
      Map<String, dynamic> updates = {
        passType: Timestamp.fromDate(newExpiry),
      };

      // 발언연장권 지급 (최초 구매 시에만)
      if (currentExpiry == null || !currentExpiry.toDate().isAfter(now)) {
        if (passType == 'modernPass') {
          updates['speakingExtensionCount'] = FieldValue.increment(10);
        } else if (passType == 'intellectualPass') {
          updates['speakingExtensionCount'] = FieldValue.increment(30);
          updates['badge'] = 'intellectual';
        } else if (passType == 'sophistPass') {
          updates['badge'] = 'sophist';
        }
      } else {
        // 갱신 시에도 배지 유지
        if (passType == 'intellectualPass') {
          updates['badge'] = 'intellectual';
        } else if (passType == 'sophistPass') {
          updates['badge'] = 'sophist';
        }
      }

      transaction.update(userRef, updates);
    });
  }

  // 패스 활성 여부 확인
  Future<bool> isPassActive(String passType) async {
    final userInfo = await getUserInfo();
    if (userInfo == null) return false;

    final expiry = userInfo[passType] as Timestamp?;
    if (expiry == null) return false;

    return expiry.toDate().isAfter(DateTime.now());
  }

  // 로그아웃
  Future<void> logout() async {
    await _secureStorage.delete(key: _uidKey);
    _cachedUid = null;
  }

  // ========== 출석 체크 관련 ==========

  /// 일일 출석 보상 청구
  /// 평일: 10 토큰, 주말(토/일): 30 토큰
  Future<Map<String, dynamic>> claimDailyAttendance() async {
    try {
      final uid = await getCurrentUid();

      final callable = _functions.httpsCallable('claimDailyReward');
      final result = await callable.call({'uid': uid});

      return {
        'success': true,
        'rewardTokens': result.data['rewardTokens'],
        'newBalance': result.data['newBalance'],
        'consecutiveDays': result.data['consecutiveDays'],
        'totalDays': result.data['totalDays'],
        'isWeekend': result.data['isWeekend'],
      };
    } catch (e) {
      if (e.toString().contains('already-exists')) {
        throw Exception('이미 오늘 출석체크를 완료했습니다');
      }
      throw Exception('출석체크에 실패했습니다: $e');
    }
  }

  /// 출석 현황 조회
  Future<Map<String, dynamic>> getAttendanceStatus() async {
    try {
      final uid = await getCurrentUid();

      final callable = _functions.httpsCallable('getAttendanceStatus');
      final result = await callable.call({'uid': uid});

      return {
        'success': true,
        'hasClaimedToday': result.data['hasClaimedToday'],
        'todayDate': result.data['todayDate'],
        'currentStreak': result.data['currentStreak'],
        'maxStreak': result.data['maxStreak'],
        'totalDays': result.data['totalDays'],
        'lastAttendanceDate': result.data['lastAttendanceDate'],
      };
    } catch (e) {
      throw Exception('출석 현황 조회에 실패했습니다: $e');
    }
  }
}