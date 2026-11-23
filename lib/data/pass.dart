import 'package:flutter/foundation.dart';

/// Le Womp Pass : un achat unique. Celui qui l'a débloque toutes les bandes où il joue,
/// et ses amis n'ont rien à payer.

/// Droit d'accès configuré dans RevenueCat.
const passEntitlement = 'pass';

/// Ce que le magasin propose : le prix affiché, déjà dans la monnaie du joueur.
class PassOffer {
  const PassOffer({required this.price});
  final String price;
}

enum PassResult { bought, pending, cancelled, failed }

/// Le magasin d'achats. Deux versions : RevenueCat pour l'app, une fausse pour les
/// tests et l'émulateur.
abstract class PassStore {
  /// Relie le magasin au compte du joueur. Lance une exception si c'est impossible.
  Future<void> init(String uid);

  /// Le joueur a-t-il déjà le Pass ?
  Future<bool> owned();

  /// L'offre en vente, ou null si le produit n'est pas encore en vente.
  Future<PassOffer?> offer();

  Future<PassResult> buy();

  /// Retrouve un Pass acheté avec le même compte Apple ou Google. true s'il est retrouvé.
  Future<bool> restore();

  /// Prévient quand le Pass arrive sans achat en cours, par exemple un paiement en attente validé.
  void listen(void Function(bool owned) onOwned);
}

/// Ce que l'app sait du Pass. Tant que [visible] est faux, rien n'en est visible
/// et le magasin n'est même pas contacté.
class PassController extends ChangeNotifier {
  PassController({this.store});

  /// null : pas de magasin dans cette version de l'app, le Pass reste caché.
  final PassStore? store;

  bool visible = false;
  bool owned = false;
  PassOffer? offer;
  bool offerLoaded = false;

  /// [remoteSwitch] vient du serveur : c'est l'interrupteur qui rend le Pass visible.
  Future<void> load({required bool remoteSwitch, required String uid}) async {
    final store = this.store;
    if (store == null || !remoteSwitch) return;
    try {
      await store.init(uid);
    } catch (_) {
      return; // magasin injoignable : le Pass reste caché
    }
    visible = true;
    notifyListeners();
    store.listen((has) {
      if (has && !owned) {
        owned = true;
        notifyListeners();
      }
    });
    try {
      owned = await store.owned();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadOffer() async {
    try {
      offer = await store?.offer();
    } catch (_) {
      offer = null;
    }
    offerLoaded = true;
    notifyListeners();
  }

  Future<PassResult> buy() async {
    final store = this.store;
    if (store == null) return PassResult.failed;
    PassResult result;
    try {
      result = await store.buy();
    } catch (_) {
      result = PassResult.failed;
    }
    if (result == PassResult.bought) {
      owned = true;
      notifyListeners();
    }
    return result;
  }

  Future<bool> restore() async {
    var found = false;
    try {
      found = await store?.restore() ?? false;
    } catch (_) {}
    if (found) {
      owned = true;
      notifyListeners();
    }
    return found;
  }
}

/// Magasin factice : les achats passent tout de suite, rien n'est facturé.
class FakePassStore implements PassStore {
  FakePassStore({this.price = r'$4.99', this.ownedAtStart = false, this.forSale = true});

  final String price;
  final bool ownedAtStart;
  final bool forSale;

  /// Résultat du prochain achat.
  PassResult nextResult = PassResult.bought;

  /// Achat fait plus tôt avec le même compte du magasin, à retrouver par [restore].
  bool boughtBefore = false;

  int initCalls = 0;
  bool _owned = false;
  void Function(bool owned)? _onOwned;

  /// Un paiement en attente finit par passer (pour un test).
  void approvePending() {
    _owned = boughtBefore = true;
    _onOwned?.call(true);
  }

  @override
  void listen(void Function(bool owned) onOwned) => _onOwned = onOwned;

  @override
  Future<void> init(String uid) async {
    initCalls++;
    _owned = ownedAtStart;
  }

  @override
  Future<bool> owned() async => _owned;

  @override
  Future<PassOffer?> offer() async => forSale ? PassOffer(price: price) : null;

  @override
  Future<PassResult> buy() async {
    if (nextResult == PassResult.bought) _owned = boughtBefore = true;
    return nextResult;
  }

  @override
  Future<bool> restore() async {
    if (boughtBefore) _owned = true;
    return _owned;
  }
}
