import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/store_service.dart';

/// Controller for managing store state and in-app purchases
class StoreController extends ChangeNotifier {
  final StoreService _storeService = StoreService();

  bool _isLoading = false;
  bool _isStoreAvailable = false;
  bool _isPurchasing = false;
  String? _error;
  List<ProductDetails> _products = [];
  Set<String> _purchasedProductIds = {};
  String? _purchasingProductId;
  PurchaseStatus? _lastPurchaseStatus;

  // Getters
  bool get isLoading => _isLoading;
  bool get isStoreAvailable => _isStoreAvailable;
  bool get isPurchasing => _isPurchasing;
  String? get error => _error;
  List<ProductDetails> get products => _products;
  Set<String> get purchasedProductIds => _purchasedProductIds;
  String? get purchasingProductId => _purchasingProductId;
  PurchaseStatus? get lastPurchaseStatus => _lastPurchaseStatus;

  /// Premium products (subscriptions)
  List<ProductDetails> get premiumProducts => _products
      .where((p) => p.id.contains('premium'))
      .toList();

  /// Ting products (consumables)
  List<ProductDetails> get tingProducts => _products
      .where((p) => p.id.contains('ting'))
      .toList();

  /// Check if user has premium subscription
  bool get hasPremium => _purchasedProductIds.any((id) => id.contains('premium'));

  /// Initialize the store
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check store availability
      _isStoreAvailable = await _storeService.isAvailable();
      
      if (!_isStoreAvailable) {
        _error = 'Store is not available';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Initialize purchase stream
      _storeService.initialize(onPurchaseUpdate: _handlePurchaseUpdate);

      // Fetch products
      _products = await _storeService.getProducts();
      
      // Sort products: premium first, then coins by price
      _products.sort((a, b) {
        if (a.id.contains('premium') && !b.id.contains('premium')) return -1;
        if (!a.id.contains('premium') && b.id.contains('premium')) return 1;
        return a.rawPrice.compareTo(b.rawPrice);
      });
      
      // IMPORTANT: Reset any stuck purchase state on init
      // This handles cases where iOS didn't send cancel event
      if (_isPurchasing) {
        debugPrint('[StoreController] Found stuck purchase state on init - resetting');
        _isPurchasing = false;
        _purchasingProductId = null;
      }

    } catch (e) {
      _error = e.toString();
      debugPrint('Store initialization error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Handle purchase updates from the stream
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      // Track the purchase status
      _lastPurchaseStatus = purchase.status;
      debugPrint('[StoreController] Purchase update: ${purchase.productID} status=${purchase.status}');
      
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _isPurchasing = true;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndCompletePurchase(purchase);
          break;

        case PurchaseStatus.error:
          debugPrint('[StoreController] ERROR: ${purchase.error?.message}');
          _error = purchase.error?.message ?? 'Purchase failed';
          _isPurchasing = false;
          _purchasingProductId = null;
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          debugPrint('[StoreController] ⚠️ CANCELED - User cancelled purchase');
          debugPrint('[StoreController] Setting isPurchasing=false, purchasingProductId=null');
          _isPurchasing = false;
          _purchasingProductId = null;
          notifyListeners();
          debugPrint('[StoreController] notifyListeners() called after cancel');
          break;
      }
    }
  }

  /// Verify and complete a purchase
  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase) async {
    try {
      // TODO: Add server-side verification here for production
      // For now, just complete the purchase locally
      
      // Add to purchased products (except consumables - they're used immediately)
      // Ting products are consumables, so we don't add them to purchased products
      if (!purchase.productID.contains('ting')) {
        _purchasedProductIds.add(purchase.productID);
      }

      // Complete the purchase
      await _storeService.completePurchase(purchase);
      
      _isPurchasing = false;
      _purchasingProductId = null;
      _error = null;
      notifyListeners();

      debugPrint('Purchase completed: ${purchase.productID}');
    } catch (e) {
      _error = 'Failed to complete purchase: $e';
      _isPurchasing = false;
      _purchasingProductId = null;
      notifyListeners();
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    if (_isPurchasing) return false;

    _isPurchasing = true;
    _purchasingProductId = product.id;
    _error = null;
    _lastPurchaseStatus = null; // Reset status for new purchase
    notifyListeners();

    final success = await _storeService.purchaseProduct(product);
    
    if (!success) {
      _isPurchasing = false;
      _purchasingProductId = null;
      _error = 'Failed to initiate purchase';
      notifyListeners();
    }

    return success;
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _storeService.restorePurchases();
    } catch (e) {
      _error = 'Failed to restore purchases: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Manually reset purchase state (for stuck purchases)
  /// Call this if purchase dialog was canceled but state is stuck
  void resetPurchaseState() {
    debugPrint('[StoreController] Manual reset purchase state');
    _isPurchasing = false;
    _purchasingProductId = null;
    _lastPurchaseStatus = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _storeService.dispose();
    super.dispose();
  }
}
