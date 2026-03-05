import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const String monthlyProductId = 'monmate_remove_ads_monthly';
  static const String annualProductId = 'monmate_remove_ads_annual';
  static const String _proStatusKey = 'monmate_pro_enabled';

  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _products = {};

  StreamSubscription<List<PurchaseDetails>>? _purchaseStreamSubscription;

  bool _initialized = false;
  bool _storeAvailable = false;
  bool _isPro = false;
  bool _isBusy = false;
  String? _lastError;

  Map<String, ProductDetails> get products => _products;
  bool get isPro => _isPro;
  bool get storeAvailable => _storeAvailable;
  bool get isBusy => _isBusy;
  String? get lastError => _lastError;

  ProductDetails? get monthlyProduct => _products[monthlyProductId];
  ProductDetails? get annualProduct => _products[annualProductId];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_proStatusKey) ?? false;

    _purchaseStreamSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e) {
        _lastError = e.toString();
        notifyListeners();
      },
    );

    await refreshProducts();
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    _isBusy = true;
    _lastError = null;
    notifyListeners();

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _isBusy = false;
      notifyListeners();
      return;
    }

    const ids = <String>{monthlyProductId, annualProductId};
    final response = await _iap.queryProductDetails(ids);
    if (response.error != null) {
      _lastError = response.error!.message;
    }
    _products
      ..clear()
      ..addEntries(
        response.productDetails.map((p) => MapEntry<String, ProductDetails>(
              p.id,
              p,
            )),
      );
    _isBusy = false;
    notifyListeners();
  }

  Future<bool> buyMonthly() async => _buy(monthlyProductId);
  Future<bool> buyAnnual() async => _buy(annualProductId);

  Future<bool> _buy(String productId) async {
    _lastError = null;
    final product = _products[productId];
    if (product == null) {
      _lastError = 'Product not available in store.';
      notifyListeners();
      return false;
    }

    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _lastError = 'Purchase flow could not start.';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> restorePurchases() async {
    _lastError = null;
    _isBusy = true;
    notifyListeners();
    await _iap.restorePurchases();
    _isBusy = false;
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _isBusy = true;
          break;
        case PurchaseStatus.error:
          _isBusy = false;
          _lastError = purchaseDetails.error?.message ?? 'Purchase failed.';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _isBusy = false;
          _lastError = null;
          await _setProStatus(true);
          break;
        case PurchaseStatus.canceled:
          _isBusy = false;
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
    notifyListeners();
  }

  Future<void> _setProStatus(bool enabled) async {
    _isPro = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proStatusKey, enabled);
  }

  Future<void> disposeService() async {
    await _purchaseStreamSubscription?.cancel();
    _purchaseStreamSubscription = null;
  }
}
