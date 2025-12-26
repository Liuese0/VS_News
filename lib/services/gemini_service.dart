import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyC3Gvdhls4Yxjeu7JRqdx3Ny10psVXu6RA';
  static DateTime? _lastRequestTime;
  static const _minDelayBetweenRequests = Duration(milliseconds: 4000);

  static const String _systemPrompt = '''당신은 한국어 뉴스 요약 전문가입니다.

**핵심 원칙:**
1. 3-5문장으로 요약 (150-200자 목표) (가장 중요)
2. 5W1H 핵심 정보 포함
3. 중요한 맥락과 배경 간략히 포함
4. 객관적이고 중립적인 톤 유지
5. 한국어 자연스러운 문체

**요약 우선순위:**
- 핵심 사건/결과
- 주요 인물/기관
- 중요한 수치/날짜
- 영향과 의미
- 필요한 배경 정보

**출력 형식:**
자연스러운 평서문으로 핵심을 명확하게 전달.''';

  static String _getCategoryGuide(String category) {
    final guides = {
      '정치': '정책 결정, 주요 발언, 정치적 영향을 포함하여 설명',
      '경제': '수치, 변동률, 시장 영향을 구체적으로 설명',
      '산업': '기업 동향, 산업 변화, 경제적 영향을 상세히 설명',
      '사회': '사건 발생 경위, 피해 규모, 조치 사항을 명확히 설명',
      '문화': '문화 트렌드, 주요 작품/인물, 대중 반응을 포함하여 설명',
      '과학': '기술/발견 내용, 혁신성, 실용화 시점을 구체적으로 설명',
      '스포츠': '경기 결과, 주요 선수/팀, 기록을 상세히 설명',
      '연예': '주요 인물/작품, 화제성, 영향력을 포함하여 설명',
    };
    return guides[category] ?? '핵심 사건과 결과를 상세히 설명';
  }

  static Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minDelayBetweenRequests) {
        await Future.delayed(_minDelayBetweenRequests - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  static Future<String> summarizeNews({
    required String title,
    required String description,
    required String url,
    String category = '인기',
  }) async {
    await _waitForRateLimit();

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 1600,
          topP: 0.95,
        ),
      );

      final categoryGuide = _getCategoryGuide(category);
      final newsContent = '$title\n\n$description';

      final prompt = '''$_systemPrompt

**이 뉴스는 '$category' 카테고리입니다.**
$categoryGuide

**원문:**
$newsContent

**요약 (3-5문장, 150-200자):**''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return '요약을 생성할 수 없습니다.';
      }
    } catch (e) {
      return '요약 생성 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  static Future<String> summarizeNewsFromContent(
      String content, {
        String category = '인기',
      }) async {
    await _waitForRateLimit();

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 1600,
          topP: 0.95,
        ),
      );

      final categoryGuide = _getCategoryGuide(category);

      final prompt = '''$_systemPrompt

**이 뉴스는 '$category' 카테고리입니다.**
$categoryGuide

**원문:**
$content

**요약 (3-5문장, 150-200자):**''';

      final contentList = [Content.text(prompt)];
      final response = await model.generateContent(contentList);

      if (response.text != null && response.text!.isNotEmpty) {
        return response.text!.trim();
      } else {
        return '요약을 생성할 수 없습니다.';
      }
    } catch (e) {
      return '요약 생성 중 오류가 발생했습니다: ${e.toString()}';
    }
  }

  static Stream<String> summarizeNewsStream({
    required String title,
    required String description,
    required String url,
    String category = '인기',
  }) async* {
    await _waitForRateLimit();

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 3200,
          topP: 0.95,
        ),
      );

      final categoryGuide = _getCategoryGuide(category);
      final newsContent = '$title\n\n$description';

      final prompt = '''$_systemPrompt

**이 뉴스는 '$category' 카테고리입니다.**
$categoryGuide

**원문:**
$newsContent

**요약 (3-5문장, 150-200자):**''';

      final content = [Content.text(prompt)];
      final responseStream = model.generateContentStream(content);

      String fullText = '';
      await for (final chunk in responseStream) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          fullText += chunk.text!;
          yield fullText.trim();
        }
      }
    } catch (e) {
      yield '요약 생성 중 오류가 발생했습니다: ${e.toString()}';
    }
  }
}