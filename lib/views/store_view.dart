import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/firebase_service.dart';
import '../services/user_service.dart';
import '../controllers/store_controller.dart';

class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isInitialized = false;

  // Map product IDs to their display information
  final Map<String, TingPackageInfo> _packageInfo = {
    '12ting': TingPackageInfo(baseAmount: 12, bonusAmount: 0, price: '₩1,800'),
    '25ting': TingPackageInfo(baseAmount: 25, bonusAmount: 1, price: '₩3,500'),
    '100ting': TingPackageInfo(baseAmount: 100, bonusAmount: 10, price: '₩14,000'),
    '200ting': TingPackageInfo(baseAmount: 200, bonusAmount: 40, price: '₩28,000'),
    '400ting': TingPackageInfo(baseAmount: 400, bonusAmount: 120, price: '₩56,000'),
    '800ting': TingPackageInfo(baseAmount: 800, bonusAmount: 280, price: '₩112,000'),
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Initialize store after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStore();
    });
  }

  Future<void> _initializeStore() async {
    if (_isInitialized) return;
    
    final storeController = context.read<StoreController>();
    await storeController.initialize();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.storeTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.gray50,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Consumer<StoreController>(
        builder: (context, storeController, _) {
          // Show error if any
          if (storeController.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(storeController.error!),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                storeController.clearError();
              }
            });
          }

          // Show loading state during initial load
          if (storeController.isLoading && !_isInitialized) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Show error state if store is not available
          if (!storeController.isStoreAvailable) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.store_outlined,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.storeUnavailable,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.storeUnavailableDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner
                    _buildHeaderBanner(),
                    const SizedBox(height: 28),
                    // Section Title
                    _buildSectionTitle(),
                    const SizedBox(height: 16),
                    // Ting Packages Grid
                    _buildPackagesGrid(storeController),
                    const SizedBox(height: 24),
                    // Info Cards
                    _buildInfoCards(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD54F),
            Color(0xFFFFB300),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '💎',
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.storeRechargeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalizations.of(context)!.storeRechargeDesc,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.storeBonusPromo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '✨',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          AppLocalizations.of(context)!.storeTingPackages,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPackagesGrid(StoreController storeController) {
    final tingProducts = storeController.tingProducts;

    // If no products loaded yet, show loading
    if (tingProducts.isEmpty && storeController.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no products available, show message
    if (tingProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Text(
            AppLocalizations.of(context)!.storeNoProducts,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: tingProducts.length,
      itemBuilder: (context, index) {
        final product = tingProducts[index];
        final info = _packageInfo[product.id];
        
        // Skip if no info for this product
        if (info == null) return const SizedBox.shrink();
        
        return _buildPackageCard(product, info, index, storeController);
      },
    );
  }

  Widget _buildPackageCard(
    ProductDetails product,
    TingPackageInfo info,
    int index,
    StoreController storeController,
  ) {
    final hasBonus = info.bonusAmount >= 0;
    final isPurchasing = storeController.isPurchasing && 
                        storeController.purchasingProductId == product.id;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: isPurchasing ? null : () => _onPackageTap(product, info, storeController),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Ting Icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE082), Color(0xFFFFCA28)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        '💎',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${info.baseAmount}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Ting',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Bonus Badge
                    if (hasBonus) ...[ 
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.storeBonus(info.bonusAmount),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Price Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          product.price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Loading overlay
              if (isPurchasing)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildInfoCard(
          icon: '🔒',
          title: AppLocalizations.of(context)!.storeSecurePayment,
          description: AppLocalizations.of(context)!.storeSecurePaymentDesc,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onPackageTap(ProductDetails product, TingPackageInfo info, StoreController storeController) {
    // Proceed directly to purchase without showing confirmation modal
    _processPurchase(product, info, storeController);
  }

  Future<void> _processPurchase(
    ProductDetails product,
    TingPackageInfo info,
    StoreController storeController,
  ) async {
    // Initiate the purchase through StoreController
    final success = await storeController.purchaseProduct(product);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.storePurchaseFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Listen for purchase completion
    // The StoreController will handle the purchase stream
    // We need to listen for when the purchase completes and credit the Ting
    _listenForPurchaseCompletion(product.id, info);
  }

  void _listenForPurchaseCompletion(String productId, TingPackageInfo info) {
    final storeController = context.read<StoreController>();
    
    // Create a one-time listener for purchase completion
    void listener() {
      if (!storeController.isPurchasing && storeController.purchasingProductId == null) {
        // Purchase completed - check the actual status
        final status = storeController.lastPurchaseStatus;
        
        // Only credit Ting if purchase was explicitly successful
        if (status == PurchaseStatus.purchased || status == PurchaseStatus.restored) {
          _creditTing(info);
        }
        // Canceled and error cases don't need additional handling
        // (errors are already shown by the controller's error handling)
        
        storeController.removeListener(listener);
      }
    }
    
    storeController.addListener(listener);
  }

  Future<void> _creditTing(TingPackageInfo info) async {
    final userId = FirebaseService().currentUserId;
    
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final totalAmount = info.baseAmount + info.bonusAmount;
    
    try {
      final success = await UserService().addTings(userId, totalAmount);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.storePurchaseSuccess(totalAmount)),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileEditFailed),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.profileEditFailed),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Data model for Ting package display information
class TingPackageInfo {
  final int baseAmount;
  final int bonusAmount;
  final String price;

  const TingPackageInfo({
    required this.baseAmount,
    required this.bonusAmount,
    required this.price,
  });
}
