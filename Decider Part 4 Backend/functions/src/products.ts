export interface ProductData {
  productId: string;
  type: "SUBSCRIPTION" | "NON_SUBSCRIPTION";
}

export const productDataMap: { [productId: string]: ProductData} = {
  "decisions_yt_5": {
    productId: "decisions_yt_5",
    type: "NON_SUBSCRIPTION",
  },
  "decisions_yt_50": {
    productId: "decisions_yt_50",
    type: "NON_SUBSCRIPTION",
  },
  "decisions_yt_500": {
    productId: "decisions_yt_500",
    type: "NON_SUBSCRIPTION",
  },
  "premium_yt": {
    productId: "premium_yt",
    type: "NON_SUBSCRIPTION",
  },
  "unlimited_yt_monthly": {
    productId: "unlimited_yt_monthly",
    type: "SUBSCRIPTION",
  },
  "unlimited_yt_yearly": {
    productId: "unlimited_yt_yearly",
    type: "SUBSCRIPTION",
  },
};
