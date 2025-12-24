import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../controllers/store_controller.dart';
import '../utils/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        title: Text(l10n.storeTitle),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppTheme.gray50,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          Consumer<StoreController>(
            builder: (context, controller, _) {
              return TextButton(
                onPressed: controller.isLoading ? null : () => controller.restorePurchases(),
                child: Text(
                  l10n.storeRestorePurchases,
                  style: TextStyle(
                    color: controller.isLoading ? AppTheme.gray400 : AppTheme.primaryColor,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<StoreController>(
        builder: (context, controller, _) {
          if (controller.isLoading && controller.products.isEmpty) {
            return _buildLoadingState();
          }

          if (!controller.isStoreAvailable) {
            return _buildUnavailableState(l10n);
          }

          if (controller.error != null && controller.products.isEmpty) {
            return _buildErrorState(controller.error!, l10n, controller);
          }

          return _buildStoreContent(context, controller, l10n);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text(
            'Loading store...',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_outlined,
                size: 64,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.storeUnavailable,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.storeUnavailableDesc,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, AppLocalizations l10n, StoreController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.storeError,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => controller.initialize(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreContent(BuildContext context, StoreController controller, AppLocalizations l10n) {
    // Show error snackbar if there's an error
    if (controller.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.error!),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: l10n.commonClose,
              textColor: Colors.white,
              onPressed: () => controller.clearError(),
            ),
          ),
        );
        controller.clearError();
      });
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Banner
          _buildPremiumBanner(l10n),
          
          const SizedBox(height: 24),
          
          // Premium Subscription Section
          if (controller.premiumProducts.isNotEmpty) ...[
            _buildSectionTitle(l10n.storePremiumSection, Icons.workspace_premium),
            const SizedBox(height: 12),
            ...controller.premiumProducts.map((product) => 
              _buildPremiumCard(context, product, controller, l10n)
            ),
            const SizedBox(height: 24),
          ],

          // Coins Section
          if (controller.coinProducts.isNotEmpty) ...[
            _buildSectionTitle(l10n.storeCoinsSection, Icons.monetization_on_outlined),
            const SizedBox(height: 12),
            _buildCoinGrid(context, controller.coinProducts, controller, l10n),
          ],

          // Empty State when no products
          if (controller.products.isEmpty) ...[
            _buildEmptyProducts(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.diamond_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.storePremiumTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.storePremiumSubtitle,
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
          // Benefits
          _buildPremiumBenefit(Icons.visibility, l10n.storeBenefit1),
          const SizedBox(height: 8),
          _buildPremiumBenefit(Icons.flash_on, l10n.storeBenefit2),
          const SizedBox(height: 8),
          _buildPremiumBenefit(Icons.favorite, l10n.storeBenefit3),
        ],
      ),
    );
  }

  Widget _buildPremiumBenefit(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumCard(
    BuildContext context, 
    ProductDetails product, 
    StoreController controller,
    AppLocalizations l10n,
  ) {
    final bool isPurchased = controller.purchasedProductIds.contains(product.id);
    final bool isPurchasing = controller.purchasingProductId == product.id;
    final bool isMonthly = product.id.contains('monthly');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMonthly ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
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
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isMonthly ? Icons.star : Icons.diamond,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMonthly ? l10n.storeMonthlyPlan : l10n.storeYearlyPlan,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (isMonthly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.storePopular,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.price,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Button
          if (isPurchased)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, color: AppTheme.successColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    l10n.storePurchased,
                    style: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: isPurchasing || controller.isPurchasing 
                  ? null 
                  : () => controller.purchaseProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: isPurchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.storeBuyButton,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoinGrid(
    BuildContext context,
    List<ProductDetails> products,
    StoreController controller,
    AppLocalizations l10n,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return _buildCoinCard(context, products[index], controller, l10n);
      },
    );
  }

  Widget _buildCoinCard(
    BuildContext context,
    ProductDetails product,
    StoreController controller,
    AppLocalizations l10n,
  ) {
    final bool isPurchasing = controller.purchasingProductId == product.id;
    final int coinAmount = _getCoinAmount(product.id);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Coin Icon with amount
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Coin amount
          Text(
            '$coinAmount',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            l10n.storeCoins,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Price button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isPurchasing || controller.isPurchasing
                  ? null
                  : () => controller.purchaseProduct(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade600,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isPurchasing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      product.price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProducts(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.storeNoProducts,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.storeNoProductsDesc,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _getCoinAmount(String productId) {
    if (productId.contains('1000')) return 1000;
    if (productId.contains('500')) return 500;
    if (productId.contains('100')) return 100;
    return 0;
  }
}
