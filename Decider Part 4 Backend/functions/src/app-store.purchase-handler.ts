import {PurchaseHandler} from "./purchase-handler";
import {ProductData, productDataMap} from "./products";
import * as appleReceiptVerify from "node-apple-receipt-verify";
import {APP_STORE_SHARED_SECRET, CLOUD_REGION} from "./constants";
import {FirebaseCalls} from "./firebase.calls";
import {firestore} from "firebase-admin/lib/firestore";
import * as Functions from "firebase-functions";
import jwtDecode from "jwt-decode";
import Timestamp = firestore.Timestamp;


declare module "node-apple-receipt-verify" {
  interface PurchasedProducts {
    originalTransactionId: string;
  }
  interface SignedPayload {
    notificationType: string,
    data: {[key: string]: string}
  }
  interface SignedTransactionInfo {
    productId: string,
    expiresDate: string,
    originalTransactionId: string,
  }
}

const functions = Functions.region(CLOUD_REGION);

export class AppStorePurchaseHandler extends PurchaseHandler {
  constructor(private firebaseCalls: FirebaseCalls) {
    super();
    appleReceiptVerify.config({
      verbose: true,
      secret: APP_STORE_SHARED_SECRET,
      extended: true,
      environment: ["production"],
      excludeOldTransactions: true,
    });
  }
  async handleSubscription(
      userId: string, productData: ProductData, token: string
  ) : Promise<boolean> {
    return this.handleValidation(userId, token);
  }

  async handleNonSubscription(
      userId: string, productData: ProductData, token: string
  ) : Promise<boolean> {
    return this.handleValidation(userId, token);
  }

  // eslint-disable-next-line max-len
  private async handleValidation(userId: string, token: string) : Promise<boolean> {
    let products: appleReceiptVerify.PurchasedProducts[];
    try {
      products = await appleReceiptVerify.validate({receipt: token});
    } catch (e) {
      if (e instanceof appleReceiptVerify.EmptyError) {
        console.log("Reciept was valid but empty");
        return true;
      } else if (e instanceof appleReceiptVerify.ServiceUnavailableError) {
        console.log("App store is currently unavailable");
        return false;
      }
      return false;
    }

    // handle product verification
    for (const product of products) {
      const productData = productDataMap[product.productId];
      if (!productData) continue;

      switch (productData.type) {
        case "SUBSCRIPTION":
          // handle Subscription
          await this.firebaseCalls.createOrUpdatePurchase({
            iapSource: "app_store",
            orderId: product.originalTransactionId,
            productId: product.productId,
            userId: userId,
            purchaseDate: firestore.Timestamp.fromMillis(product.purchaseDate),
            type: productData.type,
            // eslint-disable-next-line max-len
            expiryDate: firestore.Timestamp.fromMillis(product.expirationDate ?? 0),
            status: (product.expirationDate ?? 0) <= Date.now() ? "EXPIRED" : "ACTIVE",
          });
          break;
        case "NON_SUBSCRIPTION":
          // handle non subscription
          await this.firebaseCalls.createOrUpdatePurchase({
            iapSource: "app_store",
            orderId: product.originalTransactionId,
            productId: product.productId,
            userId: userId,
            purchaseDate: firestore.Timestamp.fromMillis(product.purchaseDate),
            type: productData.type,
            status: "COMPLETE",
          });
          break;
      }
    }
    return true;
  }

  handleServerEvent = functions.https.onRequest(async (req, res) => {
    // console.log("NEW MESSAGE!!!");
    // console.log("REQUEST BODY: " + JSON.stringify(req.body));
    const decodedBody: appleReceiptVerify.SignedPayload =
        jwtDecode(req.body.signedPayload);
    const signedInfo: appleReceiptVerify.SignedTransactionInfo =
        jwtDecode(decodedBody.data.signedTransactionInfo);
    const eventData = {
      notificationType: decodedBody.notificationType,
      productId: signedInfo.productId,
      expiresDate: signedInfo.expiresDate,
      originTransactionId: signedInfo.originalTransactionId,
    };
    // console.log("Signed Payload " + JSON.stringify(decodedBody));
    // console.log("Signed Info " + JSON.stringify(signedInfo));
    // console.log("Event data" + JSON.stringify(eventData));

    const productData = productDataMap[eventData.productId];

    if (!productData) {
      console.log("No matching product data for product: " + eventData.productId);
      res.status(403).send();
      return;
    }

    if (productData.type == "SUBSCRIPTION") {
      try {
        await this.firebaseCalls.updatePurchase({
          iapSource: "app_store",
          orderId: eventData.originTransactionId,
          expiryDate: Timestamp.fromMillis(parseInt(eventData.expiresDate, 10)),
          status: Date.now() >= parseInt(eventData.expiresDate, 10) ?
                "EXPIRED" : "ACTIVE",
        });
      } catch (e) {
        console.log("Could not update purchase", eventData);
      }
    }

    res.status(200).send();
  });
}
