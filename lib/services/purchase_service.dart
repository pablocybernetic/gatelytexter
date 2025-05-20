// lib/services/purchase_service.dart
//
// One singleton instance is created in main.dart:
//
//   final purchaseServiceInstance = PurchaseService();
//   await purchaseServiceInstance.init();
//
// …and disposed with   purchaseServiceInstance.dispose();  on app-exit.
//
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:gately/services/license_manager.dart';

class PurchaseService {
  /*–––––––– configuration ––––––––*/
  static const _kProductId = 'texter_ace_premium'; // ← your store-product

  /*–––––––– internal ––––––––*/
  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _sub;

  bool _storeAvailable = false; // device really has the Play-Store
  bool _productQueried = false; // we’ve queried & cached meta-data
  ProductDetails? _product; // populated after query

  /*–––––––– public read-only helpers ––––––––*/
  bool get storeAvailable => _storeAvailable;
  bool get ready => _storeAvailable && _product != null;
  String get price => _product?.price ?? ''; // e.g. “US $1.99”

  /*-------------------------------------------------------------------------**
   *  init(): MUST be called once at start-up before you access [ready].
   *------------------------------------------------------------------------*/
  Future<void> init() async {
    _storeAvailable = await _iap.isAvailable();

    if (!_storeAvailable) return; // desktop or no Play-Store

    // ❶ Cache product meta-data (title, price, etc.)
    final resp = await _iap.queryProductDetails({_kProductId});
    if (resp.notFoundIDs.isEmpty && resp.productDetails.isNotEmpty) {
      _product = resp.productDetails.first;
      _productQueried = true;
    }

    // ❷ Listen for any NEW or RESTORED purchases.
    _sub = _iap.purchaseStream.listen(_handlePurchase, onDone: dispose);

    // ❸ 🔄 Restore past, already-paid purchases (runs silently each launch).
    await _iap.restorePurchases();
  }

  void dispose() {
    _sub.cancel();
  }

  /*-------------------------------------------------------------------------**
   *  Buy button in the UI calls this.
   *------------------------------------------------------------------------*/
  Future<void> buy() async {
    if (!ready) return; // safety-net for the UI
    final param = PurchaseParam(productDetails: _product!);

    // Because “Texter Ace Premium” is a PERMANENT unlock, we treat it as
    // “non-consumable” → use [buyNonConsumable].
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /*–––––––– PRIVATE ––––––––*/
  void _handlePurchase(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndGrant(p); // success or restore
          break;

        case PurchaseStatus.error:
          _iap.completePurchase(p); // consume the error event
          break;

        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break; // UI can show its own “pending…”
      }
    }
  }

  /*  Server-side verification is strongly recommended for a real product.
      For this demo we trust the client and grant immediately.            */
  Future<void> _verifyAndGrant(PurchaseDetails p) async {
    await _iap.completePurchase(p); // acknowledge to Play-Store
    await LicenseManager.instance.grantPaid(); // unlock premium locally
  }
}
