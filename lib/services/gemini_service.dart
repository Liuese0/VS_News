import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyCB4cs2DUP4waKVtKt_5rRh2dCE7rC-imE';
  static DateTime? _lastRequestTime;
  static const _minDelayBetweenRequests = Duration(milliseconds: 4000); // 15 RPM

  static const String _systemPrompt = '''당신은 한국어 뉴스 요약 전문가입니다.

**핵심 원칙:**
1. 최대 2-3문장으로 요약 (80자 이내 목표)
2. 5W1H 중 가장 중요한 정보만 추출
3. 불필요한 수식어, 배경 설명 제거
4. 객관적이고 중립적인 톤 유지
5. 한국어 자연스러운 문체

**요약 우선순위:**
- 핵심 사건/결과
- 주요 인물/기관
- 수치/날짜 (중요한 경우만)
- 영향/의미 (필수적인 경우만)

**제외 사항:**
- 기자 의견, 추측성 내용
- 과거 배경 설명
- 인용문 전체 (핵심 단어만)
- 부가 정보, 상세 설명

**출력 형식:**
간결한 평서문으로 핵심만 전달. 불필요한 접속사 최소화.''';

  static String _getCategoryGuide(String category) {
    final guides = {
      '정치': '정책 결정, 주요 발언, 정치적 영향에 집중',
      '경제': '수치, 변동률, 시장 영향에 집중',
      '산업': '기업 동향, 산업 변화, 경제적 영향에 집중',
      '사회': '사건 발생 경위, 피해 규모, 조치 사항에 집중',
      '문화': '문화 트렌드, 주요 작품/인물, 대중 반응에 집중',
      '과학': '기술/발견 내용, 혁신성, 실용화 시점에 집중',
      '스포츠': '경기 결과, 주요 선수/팀, 기록에 집중',
      '연예': '주요 인물/작품, 화제성, 영향력에 집중',
    };
    return guides[category] ?? '핵심 사건과 결과에 집중';
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
        model: 'gemini-1.5',  // 이걸로 변경
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 200,
        ),
      );

      final categoryGuide = _getCategoryGuide(category);
      final newsContent = '$title\n\n$description';

      final prompt = '''$_systemPrompt

**이 뉴스는 '$category' 카테고리입니다.**
$categoryGuide

**원문:**
$newsContent

**요약 (2-3문장, 80자 이내):**''';

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
        model: 'gemini-1.5-flash',  // 이걸로 변경
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3,
          maxOutputTokens: 200,
        ),
      );

      final categoryGuide = _getCategoryGuide(category);

      final prompt = '''$_systemPrompt

**이 뉴스는 '$category' 카테고리입니다.**
$categoryGuide

**원문:**
$content

**요약 (2-3문장, 80자 이내):**''';

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
}