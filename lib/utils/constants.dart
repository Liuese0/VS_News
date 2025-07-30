// lib/utils/constants.dart
import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
}

class ApiConstants {
  // 무료 Node.js 백엔드 호스팅 (Render, Railway, Vercel 등 사용)
  static const String baseUrl = 'http://localhost:3000/api'; // 개발용

  // News API 무료 키 (https://newsapi.org)
  static const String newsApiKey = '4298913bb759467bbf9d04dbdddb9749'; //new api

  // GPT API (선택사항)
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';
}

class AppStrings {
  static const String appName = '뉴스 디베이터';
  static const String errorNetwork = '네트워크 연결을 확인해주세요';
  static const String errorGeneral = '오류가 발생했습니다';
  static const String loading = '로딩 중...';
}