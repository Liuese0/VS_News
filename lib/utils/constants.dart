// lib/utils/constants.dart
import 'package:flutter/material.dart';

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
  // 개발 환경
  static const String baseUrl = 'http://localhost:3000/api';

  // 프로덕션 환경 (배포시 변경)
  // static const String baseUrl = 'https://your-backend-url.com/api';

  // News API 키 (https://newsapi.org에서 발급)
  static const String newsApiKey = '4298913bb759467bbf9d04dbdddb9749';

  // GPT API (선택사항)
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';
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