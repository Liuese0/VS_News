// lib/services/ad_service.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  BannerAd? _exploreBannerAd;  // ExploreScreen 전용 배너
  BannerAd? _newsDetailBannerAd;  // NewsDetail 전용 배너
  bool _isAdLoaded = false;
  bool _isBannerAdLoaded = false;
  bool _isExploreBannerAdLoaded = false;
  bool _isNewsDetailBannerAdLoaded = false;
  int _dailyAdCount = 0;
  static const int _maxDailyAds = 5;
  static const int _tokensPerAd = 10;

  // 광고 ID (테스트용과 실제용 분리)
  static String get _rewardedAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Android 테스트 보상형 광고
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // iOS 테스트 보상형 광고
      }
    } else {
      // 실제 광고 ID (여기에 실제 AdMob ID를 입력하세요)
      if (Platform.isAndroid) {
        return 'ca-app-pub-6396556471310927/XXXXXXXXXX'; // TODO: 실제 Android 보상형 광고 ID로 변경
      } else if (Platform.isIOS) {
        return 'ca-app-pub-6396556471310927/XXXXXXXXXX'; // TODO: 실제 iOS 보상형 광고 ID로 변경
      }
    }
    return '';
  }

  // 배너 광고 ID
  static String get _bannerAdUnitId {
    if (kDebugMode) {
      // 테스트 광고 ID
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Android 테스트 배너 광고
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // iOS 테스트 배너 광고
      }
    } else {
      // 실제 광고 ID (여기에 실제 AdMob ID를 입력하세요)
      if (Platform.isAndroid) {
        return 'ca-app-pub-6396556471310927/XXXXXXXXXX'; // TODO: 실제 Android 배너 광고 ID로 변경
      } else if (Platform.isIOS) {
        return 'ca-app-pub-6396556471310927/XXXXXXXXXX'; // TODO: 실제 iOS 배너 광고 ID로 변경
      }
    }
    return '';
  }

  /// AdMob 초기화
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _loadDailyAdCount();
    _loadRewardedAd();
    _loadBannerAd();
    _loadExploreBannerAd();
    _loadNewsDetailBannerAd();
  }

  /// 오늘 시청한 광고 개수 로드
  Future<void> _loadDailyAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdDate = prefs.getString('last_ad_date') ?? '';
    final today = DateTime.now().toString().substring(0, 10);

    if (lastAdDate != today) {
      // 날짜가 바뀌면 카운트 초기화
      _dailyAdCount = 0;
      await prefs.setString('last_ad_date', today);
      await prefs.setInt('daily_ad_count', 0);
    } else {
      _dailyAdCount = prefs.getInt('daily_ad_count') ?? 0;
    }
  }

  /// 광고 시청 횟수 증가
  Future<void> _incrementAdCount() async {
    _dailyAdCount++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_ad_count', _dailyAdCount);
  }

  /// 오늘 남은 광고 시청 횟수
  int get remainingAds => _maxDailyAds - _dailyAdCount;

  /// 광고 시청 가능 여부
  bool get canWatchAd => _dailyAdCount < _maxDailyAds;

  /// 광고당 토큰
  int get tokensPerAd => _tokensPerAd;

  /// 배너 광고 로드 여부
  bool get isBannerAdLoaded => _isBannerAdLoaded;

  /// 배너 광고 가져오기
  BannerAd? get bannerAd => _bannerAd;

  /// ExploreScreen 전용 배너 광고 로드 여부
  bool get isExploreBannerAdLoaded => _isExploreBannerAdLoaded;

  /// ExploreScreen 전용 배너 광고 가져오기
  BannerAd? get exploreBannerAd => _exploreBannerAd;

  /// NewsDetail 전용 배너 광고 로드 여부
  bool get isNewsDetailBannerAdLoaded => _isNewsDetailBannerAdLoaded;

  /// NewsDetail 전용 배너 광고 가져오기
  BannerAd? get newsDetailBannerAd => _newsDetailBannerAd;

  /// 배너 광고 로드
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner, // 320x50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdLoaded = true;
          print('배너 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('배너 광고 로드 실패: $error');
          _isBannerAdLoaded = false;
          ad.dispose();
          _bannerAd = null;

          // 30초 후 재시도
          Future.delayed(const Duration(seconds: 30), () {
            _loadBannerAd();
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  /// ExploreScreen 전용 배너 광고 로드
  void _loadExploreBannerAd() {
    _exploreBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner, // 320x50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isExploreBannerAdLoaded = true;
          print('ExploreScreen 배너 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('ExploreScreen 배너 광고 로드 실패: $error');
          _isExploreBannerAdLoaded = false;
          ad.dispose();
          _exploreBannerAd = null;

          // 30초 후 재시도
          Future.delayed(const Duration(seconds: 30), () {
            _loadExploreBannerAd();
          });
        },
      ),
    );

    _exploreBannerAd!.load();
  }

  /// NewsDetail 전용 배너 광고 로드
  void _loadNewsDetailBannerAd() {
    _newsDetailBannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner, // 320x50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isNewsDetailBannerAdLoaded = true;
          print('NewsDetail 배너 광고 로드 성공');
        },
        onAdFailedToLoad: (ad, error) {
          print('NewsDetail 배너 광고 로드 실패: $error');
          _isNewsDetailBannerAdLoaded = false;
          ad.dispose();
          _newsDetailBannerAd = null;

          // 30초 후 재시도
          Future.delayed(const Duration(seconds: 30), () {
            _loadNewsDetailBannerAd();
          });
        },
      ),
    );

    _newsDetailBannerAd!.load();
  }

  /// 보상형 광고 로드
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoaded = true;
          print('보상형 광고 로드 성공');

          // 광고가 닫혔을 때 다시 로드
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              _loadRewardedAd(); // 다음 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('광고 표시 실패: $error');
              ad.dispose();
              _rewardedAd = null;
              _isAdLoaded = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('보상형 광고 로드 실패: $error');
          _isAdLoaded = false;
          _rewardedAd = null;

          // 5초 후 재시도
          Future.delayed(const Duration(seconds: 5), () {
            _loadRewardedAd();
          });
        },
      ),
    );
  }

  /// 광고 보여주기
  Future<bool> showRewardedAd({
    required Function(int tokens) onRewarded,
    required Function(String error) onError,
  }) async {
    try {
      // 일일 제한 확인
      if (!canWatchAd) {
        onError('하루 광고 시청 제한(5회)에 도달했습니다');
        return false;
      }

      // 광고 로드 확인
      if (!_isAdLoaded || _rewardedAd == null) {
        onError('광고를 불러오는 중입니다. 잠시 후 다시 시도해주세요');
        _loadRewardedAd(); // 재로드 시도
        return false;
      }

      bool rewarded = false;
      bool errorShown = false;

      // 보상 콜백 설정
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('광고 표시됨');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('광고 닫힘');
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          _loadRewardedAd(); // 다음 광고 미리 로드

          // 보상을 받지 못하고 닫은 경우
          if (!rewarded && !errorShown) {
            errorShown = true;
            onError('광고를 끝까지 시청해야 토큰을 받을 수 있습니다');
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('광고 표시 실패: $error');
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          _loadRewardedAd();

          if (!errorShown) {
            errorShown = true;
            onError('광고를 표시할 수 없습니다. 다시 시도해주세요');
          }
        },
      );

      // 광고 표시
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          rewarded = true;
          print('보상 획득: ${reward.amount} ${reward.type}');

          try {
            // 광고 카운트 증가
            await _incrementAdCount();

            // 토큰 지급
            onRewarded(_tokensPerAd);
          } catch (e) {
            print('보상 처리 중 오류: $e');
            if (!errorShown) {
              errorShown = true;
              onError('보상 처리 중 오류가 발생했습니다');
            }
          }
        },
      );

      return true;
    } catch (e) {
      print('광고 표시 중 예외 발생: $e');
      onError('광고를 표시하는 중 오류가 발생했습니다');

      // 광고 정리
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _isAdLoaded = false;
      _loadRewardedAd();

      return false;
    }
  }

  /// 광고 미리 로드 (앱 시작 시 호출)
  void preloadAd() {
    if (!_isAdLoaded) {
      _loadRewardedAd();
    }
    if (!_isBannerAdLoaded) {
      _loadBannerAd();
    }
    if (!_isExploreBannerAdLoaded) {
      _loadExploreBannerAd();
    }
    if (!_isNewsDetailBannerAdLoaded) {
      _loadNewsDetailBannerAd();
    }
  }

  /// 리소스 정리
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;

    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdLoaded = false;

    _exploreBannerAd?.dispose();
    _exploreBannerAd = null;
    _isExploreBannerAdLoaded = false;

    _newsDetailBannerAd?.dispose();
    _newsDetailBannerAd = null;
    _isNewsDetailBannerAdLoaded = false;
  }

  /// 광고 통계 정보
  Map<String, dynamic> getAdStats() {
    return {
      'dailyAdCount': _dailyAdCount,
      'remainingAds': remainingAds,
      'maxDailyAds': _maxDailyAds,
      'tokensPerAd': _tokensPerAd,
      'isAdLoaded': _isAdLoaded,
      'canWatchAd': canWatchAd,
      'isBannerAdLoaded': _isBannerAdLoaded,
      'isExploreBannerAdLoaded': _isExploreBannerAdLoaded,
      'isNewsDetailBannerAdLoaded': _isNewsDetailBannerAdLoaded,
    };
  }
}