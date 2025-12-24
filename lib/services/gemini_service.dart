import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class GeminiService {
  late final GenerativeModel _model;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: ApiConstants.geminiApiKey,
    );
  }

  /// 뉴스 요약 생성 (Firestore 캐싱 포함)
  Future<String> summarizeNews({
    required String newsUrl,
    required String title,
    required String description,
  }) async {
    // 1. Firestore 캐시 확인
    try {
      final cached = await _firestore
          .collection('newsSummaries')
          .doc(_sanitizeDocId(newsUrl))
          .get();

      if (cached.exists && cached.data() != null) {
        final data = cached.data()!;
        if (data['summary'] != null && data['summary'].toString().isNotEmpty) {
          print('✅ 캐시에서 요약 가져옴: $newsUrl');
          return data['summary'] as String;
        }
      }
    } catch (e) {
      print('⚠️ 캐시 조회 실패 (계속 진행): $e');
    }

    // 2. Gemini API로 요약 생성
    print('🤖 Gemini API로 요약 생성 중...');

    final prompt = '''
다음 뉴스 기사를 200-300자 이내로 요약해주세요.
요약은 핵심 내용만 간결하게 작성하고, 문장은 명확하고 이해하기 쉽게 작성해주세요.

제목: $title

내용: $description

요약:''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Gemini API 응답이 비어있습니다');
      }

      final summary = response.text!.trim();
      print('✅ 요약 생성 완료 (${summary.length}자)');

      // 3. Firestore에 캐싱
      try {
        await _firestore
            .collection('newsSummaries')
            .doc(_sanitizeDocId(newsUrl))
            .set({
          'newsUrl': newsUrl,
          'title': title,
          'summary': summary,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('✅ Firestore에 요약 캐싱 완료');
      } catch (e) {
        print('⚠️ 캐싱 실패 (계속 진행): $e');
      }

      return summary;
    } catch (e) {
      print('❌ Gemini API 오류: $e');

      // API 오류 시 원본 description 반환
      return description;
    }
  }

  /// Firestore 문서 ID로 사용할 수 있도록 URL 정제
  String _sanitizeDocId(String url) {
    // Firestore 문서 ID는 슬래시(/)를 포함할 수 없으므로 인코딩
    return url.replaceAll(RegExp(r'[\/\.]'), '_');
  }

  /// 캐시된 요약 가져오기 (캐시만 확인, API 호출 없음)
  Future<String?> getCachedSummary(String newsUrl) async {
    try {
      final doc = await _firestore
          .collection('newsSummaries')
          .doc(_sanitizeDocId(newsUrl))
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['summary'] as String?;
      }
    } catch (e) {
      print('⚠️ 캐시 조회 실패: $e');
    }
    return null;
  }

  /// 캐시 삭제 (테스트/관리 용도)
  Future<void> clearCache(String newsUrl) async {
    try {
      await _firestore
          .collection('newsSummaries')
          .doc(_sanitizeDocId(newsUrl))
          .delete();
      print('✅ 캐시 삭제 완료: $newsUrl');
    } catch (e) {
      print('❌ 캐시 삭제 실패: $e');
    }
  }

  /// 모든 캐시 삭제 (관리자 기능)
  Future<void> clearAllCache() async {
    try {
      final snapshot = await _firestore.collection('newsSummaries').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ 모든 캐시 삭제 완료 (${snapshot.docs.length}개)');
    } catch (e) {
      print('❌ 전체 캐시 삭제 실패: $e');
    }
  }
}