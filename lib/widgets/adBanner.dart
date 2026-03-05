import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mongo_mate/utilities/subscription_service.dart';

class AdBanner extends StatefulWidget {
  final AdSize adSize;
  final double bottomSpacing;
  const AdBanner({
    super.key,
    this.adSize = AdSize.leaderboard,
    this.bottomSpacing = 0,
  });

  @override
  _AdBannerState createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _loading = false;
  int _lastWidth = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SubscriptionService.instance,
      builder: (context, child) {
        if (SubscriptionService.instance.isPro) {
          _bannerAd?.dispose();
          _bannerAd = null;
          _adSize = null;
          _loading = false;
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.floor();
            if (width > 0 && width != _lastWidth) {
              _lastWidth = width;
              _loadAd(width);
            }

            if (_bannerAd == null || _adSize == null) {
              return SizedBox(
                height: _loading ? 52 : 0,
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: widget.bottomSpacing),
              child: SizedBox(
                width: _adSize!.width.toDouble(),
                height: _adSize!.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd(int width) async {
    if (_loading) return;
    _loading = true;
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;

    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (adaptiveSize == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final bannerAd = BannerAd(
      size: adaptiveSize,
      adUnitId: "ca-app-pub-2515394026864338/4245537509",
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = adaptiveSize;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }
        },
      ),
    );
    bannerAd.load();
  }
}
