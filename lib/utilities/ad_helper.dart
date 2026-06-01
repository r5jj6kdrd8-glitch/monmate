import 'dart:io';

class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // The Android Ad Unit ID you provided
      return "ca-app-pub-2515394026864338/9275830181";
    } else if (Platform.isIOS) {
      // The current iOS Banner Ad Unit ID
      return "ca-app-pub-2515394026864338/4245537509";
    }
    throw UnsupportedError("Unsupported platform");
  }

  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      // Using the same Ad Unit ID for now; if you create a distinct Native Ad Unit ID
      // in AdMob for Android, replace this string with it.
      return "ca-app-pub-2515394026864338/9275830181";
    } else if (Platform.isIOS) {
      // The current iOS Native Ad Unit ID
      return "ca-app-pub-2515394026864338/7492068820";
    }
    throw UnsupportedError("Unsupported platform");
  }
}
