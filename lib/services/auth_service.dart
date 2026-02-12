// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
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
  static const AndroidId _androidIdPlugin = AndroidId();

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
        // android_id 패키지로 Settings.Secure.ANDROID_ID 가져오기
        // 이 값은 기기마다 고유하며, 공장 초기화 시에만 변경됨
        final String? androidId = await _androidIdPlugin.getId();
        return androidId ?? '';
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

    // 2. 디바이스 ID 가져오기
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

    // 4. Cloud Function을 통해 새 계정 생성
    // (Firestore 보안 규칙에서 users 컬렉션 직접 쓰기가 차단되어 있으므로)
    try {
      final result = await _functions.httpsCallable('registerDevice').call({
        'deviceId': deviceId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': '1.0.0',
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final uid = data['uid'] as String;
        await _secureStorage.write(key: _uidKey, value: uid);
        _cachedUid = uid;
        return uid;
      } else {
        throw Exception('계정 생성에 실패했습니다');
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw Exception(e.message ?? '계정 생성 횟수가 초과되었습니다');
      }
      throw Exception('계정 생성 실패: ${e.message}');
    }
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

  // 출석체크 상태 조회
  Future<Map<String, dynamic>> getAttendanceStatus() async {
    final uid = await getCurrentUid();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 오늘 출석 여부 확인
    final todayDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .doc(todayStr)
        .get();

    final hasCheckedToday = todayDoc.exists;

    // 연속 출석 일수 계산
    int consecutiveDays = 0;
    if (hasCheckedToday) {
      consecutiveDays = todayDoc.data()?['consecutiveDays'] ?? 0;
    } else {
      // 어제까지의 연속 출석 일수 확인
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final yesterdayDoc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .doc(yesterdayStr)
          .get();

      if (yesterdayDoc.exists) {
        consecutiveDays = yesterdayDoc.data()?['consecutiveDays'] ?? 0;
      }
    }

    return {
      'hasCheckedToday': hasCheckedToday,
      'consecutiveDays': consecutiveDays,
      'date': todayStr,
    };
  }

  // 출석체크 및 보상 지급
  Future<Map<String, dynamic>> claimDailyAttendance() async {
    final uid = await getCurrentUid();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 이미 오늘 출석했는지 확인
    final todayDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .doc(todayStr)
        .get();

    if (todayDoc.exists) {
      throw Exception('이미 오늘 출석체크를 완료했습니다');
    }

    // 연속 출석 일수 계산
    int consecutiveDays = 1;
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final yesterdayDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .doc(yesterdayStr)
        .get();

    if (yesterdayDoc.exists) {
      consecutiveDays = (yesterdayDoc.data()?['consecutiveDays'] ?? 0) + 1;
    }

    // 주말 여부 확인 (토요일=6, 일요일=7)
    final isWeekend = today.weekday == DateTime.saturday || today.weekday == DateTime.sunday;

    // 보상 계산
    int baseReward = isWeekend ? 30 : 10; // 주말 30토큰, 평일 10토큰
    int bonusReward = 0;
    String bonusMessage = '';

    // 연속 출석 보너스 (제거 - 평일/주말 차등 지급만 유지)
    final totalReward = baseReward + bonusReward;

    // 트랜잭션으로 출석 기록 및 토큰 지급
    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final attendanceRef = userRef.collection('attendance').doc(todayStr);

      // 출석 기록 저장
      transaction.set(attendanceRef, {
        'checkedAt': FieldValue.serverTimestamp(),
        'consecutiveDays': consecutiveDays,
        'reward': totalReward,
        'bonusReward': bonusReward,
      });

      // 토큰 지급
      transaction.update(userRef, {
        'tokenCount': FieldValue.increment(totalReward),
      });
    });

    return {
      'success': true,
      'consecutiveDays': consecutiveDays,
      'totalReward': totalReward,
      'baseReward': baseReward,
      'bonusReward': bonusReward,
      'bonusMessage': bonusMessage,
      'isWeekend': isWeekend,
    };
  }

  // 이번 달 출석 기록 가져오기
  Future<List<String>> getMonthlyAttendance() async {
    final uid = await getCurrentUid();
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    final firstDayStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
    final lastDayStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: firstDayStr)
        .where(FieldPath.documentId, isLessThanOrEqualTo: lastDayStr)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // ============================================================================
  // 복구 코드 관련 메서드 (Cloud Functions 없이 클라이언트에서 직접 처리)
  // ============================================================================

  /// 복구 코드 생성 (읽기 쉬운 형식: XXXX-XXXX-XXXX-XXXX)
  String _generateRecoveryCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 혼동 가능한 문자 제외
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';

    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        code += '-';
      }
      final index = (random + i * 7) % chars.length;
      code += chars[index];
    }

    // 더 랜덤하게 만들기 위해 현재 시간과 해시 결합
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = sha256.convert(utf8.encode(timestamp)).toString();

    code = '';
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        code += '-';
      }
      final charIndex = hash.codeUnitAt(i) % chars.length;
      code += chars[charIndex];
    }

    return code;
  }

  /// 복구 코드 조회 또는 생성
  /// 반환값: { 'recoveryCode': String, 'isNew': bool }
  Future<Map<String, dynamic>> getOrCreateRecoveryCode() async {
    try {
      final uid = await getCurrentUid();
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      final userData = userDoc.data()!;

      // 이미 복구 코드가 있으면 반환
      if (userData['recoveryCode'] != null) {
        return {
          'recoveryCode': userData['recoveryCode'] as String,
          'isNew': false,
        };
      }

      // 새 복구 코드 생성 (중복 체크)
      String recoveryCode;
      int attempts = 0;
      const maxAttempts = 10;

      while (attempts < maxAttempts) {
        recoveryCode = _generateRecoveryCode();

        // 중복 확인
        final existingQuery = await _firestore
            .collection('users')
            .where('recoveryCode', isEqualTo: recoveryCode)
            .limit(1)
            .get();

        if (existingQuery.docs.isEmpty) {
          // 중복 없음 - 저장
          await _firestore.collection('users').doc(uid).update({
            'recoveryCode': recoveryCode,
            'recoveryCodeCreatedAt': FieldValue.serverTimestamp(),
          });

          return {
            'recoveryCode': recoveryCode,
            'isNew': true,
          };
        }

        attempts++;
      }

      throw Exception('복구 코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요.');
    } catch (e) {
      print('복구 코드 조회/생성 실패: $e');
      rethrow;
    }
  }

  /// 복구 코드로 계정 데이터 이전
  /// Cloud Function을 통해 기존 계정의 데이터를 새 기기로 이전
  Future<Map<String, dynamic>> transferDataWithRecoveryCode(String recoveryCode) async {
    try {
      final cleanCode = recoveryCode.toUpperCase().replaceAll(' ', '').replaceAll('-', '');
      final codeWithDash = '${cleanCode.substring(0, 4)}-${cleanCode.substring(4, 8)}-${cleanCode.substring(8, 12)}-${cleanCode.substring(12, 16)}';

      final deviceId = await _getDeviceId();
      if (deviceId.isEmpty) {
        throw Exception('디바이스 ID를 가져올 수 없습니다');
      }

      // Cloud Function을 통해 계정 이전 처리
      final result = await _functions.httpsCallable('transferAccountData').call({
        'recoveryCode': codeWithDash,
        'newDeviceId': deviceId,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'appVersion': '1.0.0',
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final newUid = data['newUid'] as String;
        await _secureStorage.write(key: _uidKey, value: newUid);
        _cachedUid = newUid;

        return {
          'success': true,
          'uid': newUid,
          'nickname': data['nickname'] ?? '익명',
          'tokenCount': data['tokenCount'] ?? 0,
          'transferredData': data['transferredData'] ?? {},
        };
      } else {
        throw Exception('계정 데이터 이전에 실패했습니다');
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        throw Exception('올바르지 않은 복구 코드입니다');
      } else if (e.code == 'already-exists') {
        throw Exception('이 기기에 이미 계정이 있습니다. 먼저 로그아웃해주세요');
      }
      throw Exception('계정 데이터 이전 실패: ${e.message}');
    } catch (e) {
      print('계정 데이터 이전 실패: $e');
      if (e.toString().contains('이 기기에 이미 계정이') ||
          e.toString().contains('올바르지 않은 복구 코드')) {
        rethrow;
      }
      throw Exception('계정 데이터 이전에 실패했습니다: $e');
    }
  }

  /// 현재 계정이 이전된 계정인지 확인
  Future<bool> isTransferredAccount() async {
    try {
      final userInfo = await getUserInfo();
      return userInfo?['transferredFrom'] != null;
    } catch (e) {
      return false;
    }
  }
}