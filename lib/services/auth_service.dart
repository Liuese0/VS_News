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
      'speakingRightCount': 0, // 발언권 (댓글 추가권)
      'speakingExtensionCount': 0, // 발언연장권 (50글자 추가권)
      'permanentBookmarkSlots': 0, // 영구 즐겨찾기 슬롯
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

  // 로그아웃
  Future<void> logout() async {
    await _secureStorage.delete(key: _uidKey);
    _cachedUid = null;
  }
}