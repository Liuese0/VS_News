// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'dart:io';

class AppColors {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class ApiConstants {
  // 플랫폼별 기본 URL
  static String get baseUrl {
    if (Platform.isAndroid) {
      // 안드로이드 에뮬레이터는 10.0.2.2를 사용
      return 'http://localhost:3000/api';
    } else {
      // iOS 시뮬레이터와 기타 플랫폼은 localhost 사용
      return 'http://localhost:3000/api';
    }
  }

  // 연결 시도할 URL 목록 (우선순위순)
  static List<String> get possibleUrls {
    if (Platform.isAndroid) {
      return [
        'http://10.0.2.2:3000/api',    // 안드로이드 에뮬레이터
        'http://192.168.1.100:3000/api', // WiFi IP (예시)
        'http://localhost:3000/api',
        'http://127.0.0.1:3000/api',
      ];
    } else {
      return [
        'http://localhost:3000/api',
        'http://127.0.0.1:3000/api',
        'http://10.0.2.2:3000/api',
      ];
    }
  }

  // News API 키
  static const String newsApiKey = '4298913bb759467bbf9d04dbdddb9749';
}

class AppStrings {
  static const String appName = '뉴스 디베이터';
  static const String errorNetwork = '네트워크 연결을 확인해주세요';
  static const String errorGeneral = '오류가 발생했습니다';
  static const String loading = '로딩 중...';
  static const String noData = '데이터가 없습니다';
  static const String retry = '다시 시도';
}

class AppDimensions {
  static const double padding = 16.0;
  static const double margin = 8.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 2.0;
}