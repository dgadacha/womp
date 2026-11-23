import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'pass.dart';

/// Le Pass vendu par RevenueCat : un produit non renouvelable, rattaché au droit
/// [passEntitlement], présenté dans l'offre courante.
class RevenueCatPassStore implements PassStore {
  RevenueCatPassStore(this.apiKey);

  /// Clé publique du SDK RevenueCat (appl_… ou goog_…). Elle n'a rien de secret.
  final String apiKey;

  Package? _package;

  static bool _has(CustomerInfo info) => info.entitlements.active.containsKey(passEntitlement);

  @override
  Future<void> init(String uid) async {
    // Le compte RevenueCat porte l'uid Firebase : un même joueur, un même Pass.
    if (await Purchases.isConfigured) {
      await Purchases.logIn(uid);
    } else {
      await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = uid);
    }
  }

  @override
  Future<bool> owned() async => _has(await Purchases.getCustomerInfo());

  @override
  Future<PassOffer?> offer() async {
    final current = (await Purchases.getOfferings()).current;
    final package = current?.lifetime ?? current?.availablePackages.firstOrNull;
    _package = package;
    return package == null ? null : PassOffer(price: package.storeProduct.priceString);
  }

  @override
  Future<PassResult> buy() async {
    if (_package == null) await offer();
    final package = _package;
    if (package == null) return PassResult.failed;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _has(result.customerInfo) ? PassResult.bought : PassResult.failed;
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => PassResult.cancelled,
        PurchasesErrorCode.paymentPendingError => PassResult.pending,
        // Déjà acheté avec ce compte du magasin : on le retrouve.
        PurchasesErrorCode.productAlreadyPurchasedError =>
          await restore() ? PassResult.bought : PassResult.failed,
        _ => PassResult.failed,
      };
    }
  }

  @override
  Future<bool> restore() async => _has(await Purchases.restorePurchases());

  @override
  void listen(void Function(bool owned) onOwned) =>
      Purchases.addCustomerInfoUpdateListener((info) => onOwned(_has(info)));
}
