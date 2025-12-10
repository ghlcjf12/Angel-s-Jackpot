import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'iap_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  
  // Game counter for interstitial ad frequency
  int _gamePlayCount = 0;
  DateTime? _lastInterstitialAdTime;
  static const int _gamesPerInterstitial = 8; // Show ad every 8-10 games (random)
  static const Duration _minTimeBetweenAds = Duration(minutes: 5);

  // Test Ad Unit IDs
  final String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  final String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  final String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  final String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  final String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  String get bannerAdUnitId => Platform.isAndroid ? _androidBannerId : _iosBannerId;
  String get rewardedAdUnitId => Platform.isAndroid ? _androidRewardedId : _iosRewardedId;
  String get interstitialAdUnitId => Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedAdReady = false;
        },
      ),
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('InterstitialAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void showRewardedAd({required Function(int amount) onReward, required VoidCallback onDismissed}) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd(); // Load the next one
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
          onDismissed();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onReward(reward.amount.toInt());
        },
      );
      _rewardedAd = null;
      _isRewardedAdReady = false;
    } else {
      debugPrint('Rewarded Ad not ready yet');
      _loadRewardedAd();
    }
  }

  // Increment game counter
  void incrementGameCount() {
    _gamePlayCount++;
    debugPrint('Game count: $_gamePlayCount');
  }

  // Check if interstitial ad should be shown
  bool shouldShowInterstitialAd() {
    // Check if enough games have been played (8-10 random)
    final randomThreshold = _gamesPerInterstitial + (DateTime.now().millisecond % 3); // 8-10
    if (_gamePlayCount < randomThreshold) {
      return false;
    }

    // Check if enough time has passed since last ad
    if (_lastInterstitialAdTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialAdTime!);
      if (timeSinceLastAd < _minTimeBetweenAds) {
        return false;
      }
    }

    return _isInterstitialAdReady;
  }

  // Show interstitial ad when returning to lobby
  void showInterstitialAd({VoidCallback? onDismissed}) {
    // Check if user purchased ad removal
    if (InAppPurchaseService().adRemovalPurchased) {
      debugPrint('Ad removal purchased, skipping interstitial ad');
      onDismissed?.call();
      return;
    }

    if (!shouldShowInterstitialAd()) {
      onDismissed?.call();
      return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _gamePlayCount = 0; // Reset counter
          _lastInterstitialAdTime = DateTime.now();
          _loadInterstitialAd(); // Load the next one
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('InterstitialAd failed to show: $error');
          ad.dispose();
          _loadInterstitialAd();
          onDismissed?.call();
        },
      );

      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    } else {
      debugPrint('InterstitialAd not ready yet');
      _loadInterstitialAd();
      onDismissed?.call();
    }
  }
}
