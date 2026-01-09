# VS News - 뉴스 토론 앱

뜨거운 이슈에 대한 여론을 확인하고 토론할 수 있는 Flutter 앱입니다.

## 환경 설정

### 1. API 키 설정

이 프로젝트는 API 키를 환경 변수로 관리합니다. 앱을 실행하기 전에 반드시 설정해야 합니다.

#### 단계:

1. 프로젝트 루트 디렉토리에 `.env` 파일을 생성합니다:
   ```bash
   cp .env .env
   ```

2. `.env` 파일을 열고 실제 API 키로 교체합니다:
   ```env
   GEMINI_API_KEY=실제_Gemini_API_키
   NEWS_API_KEY=실제_News_API_키
   ```

3. **API 키 발급 방법**:
    - **Gemini API**: https://ai.google.dev/ 에서 발급
    - **News API**: https://newsapi.org/ 에서 발급

####  보안 주의사항

- `.env` 파일은 절대 Git에 커밋하지 마세요! (이미 `.gitignore`에 추가되어 있음)
- API 키가 GitHub에 노출되면 즉시 폐기하고 새로 발급받으세요
- 팀원들과 API 키를 공유할 때는 안전한 방법(암호화된 채널)을 사용하세요

### 2. 의존성 설치

```bash
flutter pub get
```

### 3. Firebase 설정

Firebase 프로젝트를 생성하고 `google-services.json` (Android) 및 `GoogleService-Info.plist` (iOS) 파일을 추가해야 합니다.

### 4. 앱 실행

```bash
flutter run
```

## 주요 기능

- 실시간 뉴스 탐색
- AI 기반 뉴스 요약 (Gemini API)
- 논쟁 이슈 토론
- 출석 체크 및 리워드 시스템

## 기술 스택

- **Flutter**: 크로스 플랫폼 앱 개발
- **Firebase**: 인증, 데이터베이스
- **Gemini API**: AI 뉴스 요약
- **News API**: 뉴스 데이터 제공

## 문제 해결

### "API 키가 없습니다" 오류가 발생하는 경우

1. `.env` 파일이 프로젝트 루트에 있는지 확인
2. `.env` 파일에 API 키가 올바르게 입력되었는지 확인
3. 앱을 재시작 (hot reload가 아닌 완전 재시작)

### API 키 노출로 GitHub에서 차단된 경우

1. 노출된 API 키를 즉시 폐기 (API 제공업체 콘솔에서)
2. 새 API 키를 발급받아 `.env` 파일에 추가
3. 이 가이드에 따라 환경 변수 설정 완료
4. Git 히스토리에서 API 키 제거 (필요시 BFG Repo-Cleaner 사용)

## 더 알아보기

Flutter 개발에 대한 도움말:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [온라인 문서](https://docs.flutter.dev/)