// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // 캐시 충전 (테스트용)
  Future<void> addCash(int amount) async {
    final uid = await getCurrentUid();

    // Firestore에 직접 업데이트 (실제로는 Cloud Function 사용해야 함)
    await _firestore.collection('users').doc(uid).update({
      'cashBalance': FieldValue.increment(amount),
    });

    // 캐시 히스토리 기록
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('cashHistory')
        .add({
      'type': 'purchase',
      'amount': amount,
      'description': '캐시 충전 $amount원',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 캐시로 토큰 구매
  Future<Map<String, dynamic>> purchaseTokensWithCash(String packageType) async {
    final uid = await getCurrentUid();

    // 패키지 정의
    final packages = {
      'small': {'tokens': 100, 'cost': 200},
      'medium': {'tokens': 500, 'cost': 800},
      'large': {'tokens': 1000, 'cost': 1500},
    };

    final pkg = packages[packageType];
    if (pkg == null) {
      throw Exception('Invalid package type');
    }

    // Firestore 트랜잭션으로 처리
    return await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final currentCash = userDoc.data()?['cashBalance'] ?? 0;
      final currentTokens = userDoc.data()?['tokenCount'] ?? 0;
      final cost = pkg['cost'] as int;
      final tokens = pkg['tokens'] as int;

      if (currentCash < cost) {
        throw Exception('캐시가 부족합니다');
      }

      final newCashBalance = currentCash - cost;
      final newTokenBalance = currentTokens + tokens;

      // 캐시 차감 및 토큰 지급
      transaction.update(userRef, {
        'cashBalance': newCashBalance,
        'tokenCount': newTokenBalance,
      });

      return {
        'cashBalance': newCashBalance,
        'tokenCount': newTokenBalance,
      };
    }).then((result) async {
      // 트랜잭션 외부에서 히스토리 기록
      final userRef = _firestore.collection('users').doc(uid);
      final tokens = pkg['tokens'] as int;
      final cost = pkg['cost'] as int;

      // 토큰 히스토리
      await userRef.collection('tokenHistory').add({
        'type': 'purchase_with_cash',
        'amount': tokens,
        'cashSpent': cost,
        'description': '캐시로 $tokens 토큰 구매',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 캐시 히스토리
      await userRef.collection('cashHistory').add({
        'type': 'token_purchase',
        'amount': -cost,
        'tokensReceived': tokens,
        'description': '$tokens 토큰 구매',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result;
    });
  }

  // 상점 아이템 구매
  Future<Map<String, dynamic>> purchaseShopItem(String itemType) async {
    final uid = await getCurrentUid();

    // 상점 아이템 정의
    final items = {
      'comment_ticket': {
        'name': '발언권 (댓글추가권)',
        'cost': 25,
        'field': 'commentTickets',
        'description': '하루 댓글 제한을 1회 추가합니다'
      },
      'text_extension': {
        'name': '발언연장권 (50글자 추가권)',
        'cost': 30,
        'field': 'textExtensions',
        'description': '댓글 글자 수 제한을 50자 추가합니다'
      },
      'favorite_permanent': {
        'name': '즐겨찾기 영구 추가권',
        'cost': 100,
        'field': 'favoritePermanent',
        'description': '즐겨찾기 최대 개수를 영구적으로 1개 추가합니다'
      },
    };

    final item = items[itemType];
    if (item == null) {
      throw Exception('Invalid item type');
    }

    // Firestore 트랜잭션으로 처리
    return await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final currentTokens = userDoc.data()?['tokenCount'] ?? 0;
      final currentItemCount = userDoc.data()?[item['field']] ?? 0;
      final cost = item['cost'] as int;

      if (currentTokens < cost) {
        throw Exception('토큰이 부족합니다');
      }

      final newTokenBalance = currentTokens - cost;
      final newItemCount = currentItemCount + 1;

      // 토큰 차감 및 아이템 지급
      transaction.update(userRef, {
        'tokenCount': newTokenBalance,
        item['field'] as String: newItemCount,
      });

      return {
        'tokenCount': newTokenBalance,
        'itemCount': newItemCount,
        'itemName': item['name'],
      };
    }).then((result) async {
      // 트랜잭션 외부에서 히스토리 기록
      final userRef = _firestore.collection('users').doc(uid);
      final cost = item['cost'] as int;
      final name = item['name'] as String;

      // 토큰 히스토리
      await userRef.collection('tokenHistory').add({
        'type': 'shop_purchase',
        'amount': -cost,
        'itemPurchased': itemType,
        'description': '$name 구매',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 구매 히스토리
      await userRef.collection('purchaseHistory').add({
        'itemType': itemType,
        'itemName': name,
        'cost': cost,
        'description': item['description'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result;
    });
  }

  // 로그아웃
  Future<void> logout() async {
    await _secureStorage.delete(key: _uidKey);
    _cachedUid = null;
  }
}