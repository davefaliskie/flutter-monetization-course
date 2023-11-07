import * as Functions from "firebase-functions";
import * as admin from "firebase-admin";
import {FirebaseCalls, IAPSource} from "./firebase.calls";
import {PurchaseHandler} from "./purchase-handler";
import {CLOUD_REGION} from "./constants";
import {AppStorePurchaseHandler} from "./app-store.purchase-handler";
import {GooglePlayPurchaseHandler} from "./google-play.purchase-handler";
import {productDataMap} from "./products";
import {HttpsError} from "firebase-functions/v1/https";

admin.initializeApp();

const functions = Functions.region(CLOUD_REGION);
const firebaseCalls = new FirebaseCalls(admin.firestore());
const purchaseHandlers: { [source in IAPSource]: PurchaseHandler } = {
  "google_play": new GooglePlayPurchaseHandler(firebaseCalls),
  "app_store": new AppStorePurchaseHandler(firebaseCalls),
};

interface VerifyPurchaseParams {
  source: IAPSource;
  verificationData: string;
  productId: string;
}

export const verifyPurchase = functions.https.onCall(
    async (data: VerifyPurchaseParams, context): Promise<boolean> => {
      // check for auth
      if (!context.auth) {
        console.warn("verifyPurchase was called no authentication");
        throw new HttpsError("unauthenticated", "Request was not authenticated.");
      }
      const productData = productDataMap[data.productId];
      // product data was unknown
      if (!productData) {
        console.warn(
            `verifyPurchase was called for an unknown product ("${data.productId}")`
        );
        return false;
      }
      // called from unknown source
      if (!purchaseHandlers[data.source]) {
        console.warn(
            `verifyPurchase called for an unknown source ("${data.source}")`
        );
        return false;
      }
      // validate the purchase
      return purchaseHandlers[data.source].verifyPurchase(
        context.auth?.uid,
        productData,
        data.verificationData,
      );
    }
);

export const handleAppStoreServerEvent =
    (purchaseHandlers.app_store as AppStorePurchaseHandler).handleServerEvent;

export const handlePlayStoreServerEvent =
    (purchaseHandlers.google_play as GooglePlayPurchaseHandler)
        .handleServerEvent;

export const expireSubscriptions = functions.pubsub.schedule("*/10 */1 * * *")
    .timeZone("America/New_York")
    .onRun(() => firebaseCalls.exporeSubscriptions());
