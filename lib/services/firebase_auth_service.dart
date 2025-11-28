// lib/services/firebase_auth_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // 서버 시크릿 키 (실제로는 Firebase Functions에서 관리)
  static const String _serverSecret = 'AIzaSyDgFLiCHnwaYv2YSw1zf42LLtXjb99-QuM';

  String? _cachedUid;

  /// 기기의 고유 ID 가져오기
  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // ANDROID_ID
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      print('기기 ID 가져오기 실패: $e');
      return 'unknown';
    }
  }

  /// 기기 해시 생성 (서버와 동일한 방식)
  String _generateDeviceHash(String deviceId) {
    final input = '$deviceId$_serverSecret';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 로컬에 저장된 UID 가져오기
  Future<String?> _getStoredUid() async {
    try {
      return await _secureStorage.read(key: 'user_uid');
    } catch (e) {
      print('저장된 UID 읽기 실패: $e');
      return null;
    }
  }

  /// UID를 로컬에 안전하게 저장
  Future<void> _storeUid(String uid) async {
    try {
      await _secureStorage.write(key: 'user_uid', value: uid);
      _cachedUid = uid;
    } catch (e) {
      print('UID 저장 실패: $e');
    }
  }

  /// 사용자 인증 및 UID 반환 (앱 시작 시 1회 호출)
  Future<String> authenticateDevice() async {
    // 1. 캐시된 UID가 있으면 바로 반환
    if (_cachedUid != null) {
      return _cachedUid!;
    }

    // 2. 로컬 저장소에서 UID 확인
    String? storedUid = await _getStoredUid();
    if (storedUid != null) {
      // Firebase에서 유효성 검증
      final userDoc = await _firestore.collection('users').doc(storedUid).get();
      if (userDoc.exists) {
        _cachedUid = storedUid;
        return storedUid;
      }
    }

    // 3. 새 기기 → 서버에 등록
    final deviceId = await _getDeviceId();
    final deviceHash = _generateDeviceHash(deviceId);

    // 4. 기존에 이 기기가 등록되어 있는지 확인
    final existingUser = await _firestore
        .collection('users')
        .where('deviceHash', isEqualTo: deviceHash)
        .limit(1)
        .get();

    if (existingUser.docs.isNotEmpty) {
      // 기존 사용자
      final uid = existingUser.docs.first.id;
      await _storeUid(uid);
      return uid;
    }

    // 5. 완전히 새로운 기기 → Firestore에 자동 ID로 등록
    final newUserRef = _firestore.collection('users').doc();
    final uid = newUserRef.id;

    await newUserRef.set({
      'deviceHash': deviceHash,
      'createdAt': FieldValue.serverTimestamp(),
      'tokenCount': 0,
      'favoriteCount': 0,
      'commentCount': 0,
      'lastActive': FieldValue.serverTimestamp(),
    });

    await _storeUid(uid);
    return uid;
  }

  /// 현재 UID 반환 (이미 인증된 상태에서만 호출)
  String getCurrentUid() {
    if (_cachedUid == null) {
      throw Exception('사용자가 인증되지 않았습니다. authenticateDevice()를 먼저 호출하세요.');
    }
    return _cachedUid!;
  }

  /// 로그아웃 (앱 데이터 초기화)
  Future<void> logout() async {
    await _secureStorage.delete(key: 'user_uid');
    _cachedUid = null;
  }

  /// 사용자 정보 업데이트
  Future<void> updateUserInfo(Map<String, dynamic> data) async {
    final uid = getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      ...data,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// 사용자 통계 증가
  Future<void> incrementCounter(String counterName) async {
    final uid = getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      counterName: FieldValue.increment(1),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// 사용자 통계 감소
  Future<void> decrementCounter(String counterName) async {
    final uid = getCurrentUid();
    await _firestore.collection('users').doc(uid).update({
      counterName: FieldValue.increment(-1),
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  /// 사용자 데이터 가져오기
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final uid = getCurrentUid();
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('사용자 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 사용자 데이터 스트림
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserDataStream() {
    final uid = getCurrentUid();
    return _firestore.collection('users').doc(uid).snapshots();
  }
}