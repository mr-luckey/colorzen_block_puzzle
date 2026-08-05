import 'dart:async';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract class IapService {
  Future<void> init({void Function(bool adsRemoved)? onAdsOwnershipChanged});
  Future<bool> purchaseRemoveAds();
  Future<bool> restorePurchases();
}

class InAppPurchaseService implements IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _available = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  void Function(bool adsRemoved)? _onAdsOwnershipChanged;

  @override
  Future<void> init({void Function(bool adsRemoved)? onAdsOwnershipChanged}) async {
    _onAdsOwnershipChanged = onAdsOwnershipChanged;
    try {
      _available = await _iap.isAvailable().timeout(const Duration(seconds: 3));
    } catch (_) {
      _available = false;
    }
    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != IapConstants.removeAdsProductId) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _onAdsOwnershipChanged?.call(true);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  @override
  Future<bool> purchaseRemoveAds() async {
    if (!_available) {
      // Dev / emulator fallback so settings stay testable.
      _onAdsOwnershipChanged?.call(true);
      return true;
    }
    try {
      final response = await _iap.queryProductDetails(
        {IapConstants.removeAdsProductId},
      );
      if (response.productDetails.isEmpty) {
        _onAdsOwnershipChanged?.call(true);
        return true;
      }
      final product = response.productDetails.first;
      return _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> restorePurchases() async {
    if (!_available) {
      _onAdsOwnershipChanged?.call(true);
      return true;
    }
    try {
      await _iap.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Dev-friendly stub when store is unavailable.
class StubIapService implements IapService {
  void Function(bool adsRemoved)? _onAdsOwnershipChanged;

  @override
  Future<void> init({void Function(bool adsRemoved)? onAdsOwnershipChanged}) async {
    _onAdsOwnershipChanged = onAdsOwnershipChanged;
  }

  @override
  Future<bool> purchaseRemoveAds() async {
    _onAdsOwnershipChanged?.call(true);
    return true;
  }

  @override
  Future<bool> restorePurchases() async {
    _onAdsOwnershipChanged?.call(true);
    return true;
  }
}
