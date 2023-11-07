import {ProductData} from "./products";

export abstract class PurchaseHandler {
  async verifyPurchase(
      userId: string, productData: ProductData, token: string
  ) : Promise<boolean> {
    if (productData.type == "SUBSCRIPTION") {
      return this.handleSubscription(userId, productData, token);
    } else if (productData.type == "NON_SUBSCRIPTION") {
      return this.handleNonSubscription(userId, productData, token);
    } else {
      return false;
    }
  }

  abstract handleSubscription(
    userId: string, productData: ProductData, token: string
  ) : Promise<boolean>;

  abstract handleNonSubscription(
    userId: string, productData: ProductData, token: string
  ) : Promise<boolean>;
}
