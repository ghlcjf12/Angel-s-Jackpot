import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  // Test Ad Unit IDs
  final String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  final String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  final String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  String get bannerAdUnitId => Platform.isAndroid ? _androidBannerId : _iosBannerId;
  String get rewardedAdUnitId => Platform.isAndroid ? _androidRewardedId : _iosRewardedId;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
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
      // Optionally try to load again if not ready
      _loadRewardedAd();
    }
  }
}
