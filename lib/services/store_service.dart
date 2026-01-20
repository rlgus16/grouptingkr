import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service for handling in-app purchases
class StoreService {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Product IDs - replace with actual IDs from Play Console / App Store Connect
  static const Set<String> _productIds = {
    '12ting',
    '25ting',
    '100ting',
    '200ting',
    '400ting',
    '800ting',
  };

  /// Check if store is available
  Future<bool> isAvailable() async {
    return await _inAppPurchase.isAvailable();
  }

  /// Initialize the purchase stream
  void initialize({required Function(List<PurchaseDetails>) onPurchaseUpdate}) {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('Store purchase stream error: $error'),
    );
  }

  /// Dispose subscription
  void dispose() {
    _subscription?.cancel();
  }

  /// Fetch available products from store
  Future<List<ProductDetails>> getProducts() async {
    final bool available = await isAvailable();
    if (!available) {
      debugPrint('Store is not available');
      return [];
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
    
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    
    if (response.error != null) {
      debugPrint('Error fetching products: ${response.error}');
      return [];
    }

    return response.productDetails;
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      if (_isConsumable(product.id)) {
        return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      } else {
        return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Check if product is consumable (Ting)
  /// All Ting packages are consumable since users can purchase them multiple times
  bool _isConsumable(String productId) {
    return productId.contains('ting');
  }

  /// Complete a purchase (call after successful verification)
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }
}
