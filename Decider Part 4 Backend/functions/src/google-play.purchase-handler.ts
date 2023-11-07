import {PurchaseHandler} from "./purchase-handler";
import {androidpublisher_v3 as AndroidPublisherApi} from "googleapis";
import {GoogleAuth} from "google-auth-library";
import {FirebaseCalls, NonSubscriptionPurchase, NonSubscriptionStatus, SubscriptionPurchase, SubscriptionStatus, Purchase} from "./firebase.calls";
import {firestore} from "firebase-admin/lib/firestore";
import credentials from "./assets/service-account.json";
import {ANDROID_PACKAGE_ID, GOOGLE_PLAY_PUBSUB_TOPIC, CLOUD_REGION} from "./constants";
import {ProductData, productDataMap} from "./products";
import * as Functions from "firebase-functions";

const functions = Functions.region(CLOUD_REGION);

export class GooglePlayPurchaseHandler extends PurchaseHandler {
  private androidPublisher: AndroidPublisherApi.Androidpublisher;

  constructor(private firebaseCalls: FirebaseCalls) {
    super();
    this.androidPublisher = new AndroidPublisherApi.Androidpublisher({
      auth: new GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
      }),
    });
  }

  async handleSubscription(
      userId: string | null, productData: ProductData, token: string
  ) : Promise<boolean> {
    try {
      const response = await this.androidPublisher.purchases.subscriptions.get({
        packageName: ANDROID_PACKAGE_ID,
        subscriptionId: productData.productId,
        token,
      });

      if (!response.data.orderId) {
        console.error("Could not handle purchase without order id");
        return false;
      }

      // Update order id if necessary
      let orderId = response.data.orderId;
      const orderIdMatch = /^(.+)?[.]{2}[0-9]+$/g.exec(orderId);
      if (orderIdMatch) {
        orderId = orderIdMatch[1];
      }

      const purchaseData: Omit<SubscriptionPurchase, "userId"> = {
        iapSource: "google_play",
        orderId: orderId,
        productId: productData.productId,
        purchaseDate: firestore.Timestamp.fromMillis(parseInt(response.data.startTimeMillis ?? "0", 10)),
        type: "SUBSCRIPTION",
        expiryDate: firestore.Timestamp.fromMillis(parseInt(response.data.expiryTimeMillis ?? "0", 10)),
        status: [
          "PENDING",
          "ACTIVE",
          "ACTIVE",
          "PENDING",
          "EXPIRED",
        ][response.data.paymentState ?? 4] as SubscriptionStatus,
      };
      if (userId) {
        await this.firebaseCalls.createOrUpdatePurchase(
            {...purchaseData, userId} as Purchase
        );
      } else {
        await this.firebaseCalls.updatePurchase(
          purchaseData as Purchase
        );
      }
      return true;
    } catch (e) {
      console.log("could not verify the purchase because of error", e);
      return false;
    }
  }

  async handleNonSubscription(
      userId: string | null, productData: ProductData, token: string
  ) : Promise<boolean> {
    try {
      const response = await this.androidPublisher.purchases.products.get({
        packageName: ANDROID_PACKAGE_ID,
        productId: productData.productId,
        token,
      });

      if (!response.data.orderId) {
        console.error("Could not handle purchase without order id");
        return false;
      }

      const purchaseData: Omit<NonSubscriptionPurchase, "userId"> = {
        iapSource: "google_play",
        orderId: response.data.orderId,
        productId: productData.productId,
        purchaseDate: firestore.Timestamp.fromMillis(parseInt(response.data.purchaseTimeMillis ?? "0", 10)),
        type: "NON_SUBSCRIPTION",
        status: [
          "COMPLETE",
          "CANCELED",
          "PENDING",
        ][response.data.purchaseState ?? 0] as NonSubscriptionStatus,
      };

      if (userId) {
        await this.firebaseCalls.createOrUpdatePurchase(
            {...purchaseData, userId} as Purchase
        );
      } else {
        await this.firebaseCalls.updatePurchase(
          purchaseData as Purchase
        );
      }
      return true;
    } catch (e) {
      console.log("could not verify the purchase because of error", e);
      return false;
    }
  }

  handleServerEvent = functions.pubsub.topic(GOOGLE_PLAY_PUBSUB_TOPIC)
      .onPublish(async (message) => {
        type GooglePlayOneTimeProductNotification = {
          "version": string;
          "notificationType": number;
          "purchaseToken": string;
          "sku": string;
        }
        type GooglePlaySubscriptionNotification = {
          "version": string;
          "notificationType": number;
          "purchaseToken": string;
          "subscriptionId": string;
        }
        type GooglePlayTestNotification = {
          "version": string;
        }
        type GooglePlayBillingEvent = {
          "version": string;
          "packageName": string;
          "eventTimeMillis": number;
          "oneTimeProductNotification": GooglePlayOneTimeProductNotification;
          "subscriptionNotification": GooglePlaySubscriptionNotification;
          "testNotification": GooglePlayTestNotification;
        }
        let event: GooglePlayBillingEvent;

        try {
          event = JSON.parse(Buffer.from(message.data, "base64").toString("ascii"));
        } catch (e) {
          console.error("Could not parse Google Play billing event", e);
          return;
        }

        // if (event.testNotification) return;
        const {purchaseToken, subscriptionId, sku} = {
          ...event.subscriptionNotification,
          ...event.oneTimeProductNotification,
        };

        const productData = productDataMap[subscriptionId ?? sku];
        if (!productData) return;

        const notificationType = subscriptionId ? "SUBSCRIPTION" : sku ? "NON_SUBSCRIPTION" : null;
        if (productData.type !== notificationType) return;
        switch (notificationType) {
          case "SUBSCRIPTION":
            await this.handleSubscription(null, productData, purchaseToken);
            break;
          case "NON_SUBSCRIPTION":
            await this.handleNonSubscription(null, productData, purchaseToken);
            break;
        }
      });
}
