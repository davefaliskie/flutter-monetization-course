import 'package:cloud_functions/cloud_functions.dart';
import 'package:decider/services/firebase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  String uid;
  IAPService(this.uid);

  void listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      print("purchaseDetails.status ${purchaseDetails.status}");
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          _handleSuccessfulPurchase(purchaseDetails);
        }
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        print(purchaseDetails.error!);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
        print("Purchase marked complete");
      }
    });
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.productID == "decisions_yt_5") {
      FirebaseService().increaseDecision(uid: uid, quantity: 5);
    }
    if (purchaseDetails.productID == 'decisions_yt_50') {
      FirebaseService().increaseDecision(uid: uid, quantity: 50);
    }
    if (purchaseDetails.productID == 'decisions_yt_500') {
      FirebaseService().increaseDecision(uid: uid, quantity: 500);
    }
    if (purchaseDetails.productID == 'premium_yt') {
      FirebaseService().setAccountType(uid: uid, type: 'premium');
    }
    if (purchaseDetails.productID == 'unlimited_yt_monthly' || purchaseDetails.productID == 'unlimited_yt_yearly') {
      FirebaseService().setAccountType(uid: uid, type: 'unlimited');
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    print("Verifying Purchase");
    final verifier = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
    final results = await verifier({
      'source': purchaseDetails.verificationData.source,
      'verificationData': purchaseDetails.verificationData.serverVerificationData,
      'productId': purchaseDetails.productID,
    });
    print("Called verify purchase with following result $results");
    return results.data as bool;
  }

}