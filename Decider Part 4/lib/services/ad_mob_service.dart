import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  Future<InitializationStatus> initialization;

  AdMobService(this.initialization);

  String? get bannerAdUnitId {
    if (kReleaseMode) {
      if (Platform.isIOS) {
        return "ca-app-pub-2334510780816542/3582696488";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-2334510780816542/3426428591";
      }
    } else {
      if (Platform.isIOS) {
        return "ca-app-pub-3940256099942544/2934735716";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-3940256099942544/6300978111";
      }
    }
    return null;
  }

  String? get interstitialAdUnitId {
    if (kReleaseMode) {
      if (Platform.isIOS) {
        return "ca-app-pub-2334510780816542/9956533145";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-2334510780816542/6655227163";
      }
    } else {
      if (Platform.isIOS) {
        return "ca-app-pub-3940256099942544/4411468910";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-3940256099942544/1033173712";
      }
    }
    return null;
  }

  String? get rewardAdUnitId {
    if (kReleaseMode) {
      if (Platform.isIOS) {
        return "ca-app-pub-2334510780816542/7330369802";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-2334510780816542/4704206465";
      }
    } else {
      if (Platform.isIOS) {
        return "ca-app-pub-3940256099942544/1712485313";
      } else if (Platform.isAndroid) {
        return "ca-app-pub-3940256099942544/5224354917";
      }
    }
    return null;
  }

  final BannerAdListener bannerListener = BannerAdListener(
    onAdLoaded: (Ad ad) => print('Ad loaded.'),
    onAdFailedToLoad: (Ad ad, LoadAdError error) {
      ad.dispose();
      print('Ad failed to load: $error');
    },
    onAdOpened: (Ad ad) => print('Ad opened.'),
    onAdClosed: (Ad ad) => print('Ad closed.'),
  );

}