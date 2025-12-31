---
title: Unified APIs
sidebar_label: Unified APIs
sidebar_position: 2
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Unified APIs

<IapKitBanner />

These cross-platform methods work on both iOS and Android. For StoreKit/Play-specific helpers, see the [iOS Specific](./ios-specific) and [Android Specific](./android-specific) sections.

- [`init_connection()`](#init_connection) — Initialize the store connection
- [`end_connection()`](#end_connection) — End the store connection and cleanup
- [`fetch_products()`](#fetch_products) — Fetch product metadata
- [`fetch_subscriptions()`](#fetch_subscriptions) — Fetch subscription metadata
- [`request_purchase()`](#request_purchase) — Start a purchase
- [`finish_transaction()`](#finish_transaction) — Complete a transaction after validation
- [`get_available_purchases()`](#get_available_purchases) — Restore non-consumables and subscriptions
- [`deep_link_to_subscriptions()`](#deep_link_to_subscriptions) — Open native subscription management UI
- [`verify_purchase()`](#verify_purchase) — Verify purchase with native OpenIAP implementation

## init_connection()

Initializes the connection to the store. This method must be called before any other store operations.

```gdscript
var iap: GodotIap

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _initialize()

func _initialize():
    var result_json = iap.init_connection()
    var result = JSON.parse_string(result_json)

    if result.get("success", false):
        print("Store connection initialized")
    else:
        print("Failed to initialize: ", result.get("error", ""))
```

**Returns:** JSON string

```json
{
  "success": true
}
```

## end_connection()

Ends the connection to the store and cleans up resources.

```gdscript
func _cleanup():
    var result_json = iap.end_connection()
    var result = JSON.parse_string(result_json)

    if result.get("success", false):
        print("Store connection ended")
```

**Returns:** JSON string

```json
{
  "success": true
}
```

## fetch_products()

Fetches in-app product information from the store.

```gdscript
func load_products():
    var product_ids = ["coins_100", "coins_500", "remove_ads"]
    var result_json = iap.fetch_products(JSON.stringify(product_ids), "inapp")
    var products = JSON.parse_string(result_json)

    for product in products:
        print("Product: ", product.productId)
        print("Price: ", product.localizedPrice)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `product_ids` | `String` | JSON array of product IDs |
| `product_type` | `String` | Product type: `"inapp"` or `"subs"` |

**Returns:** JSON array of products

```json
[
  {
    "productId": "coins_100",
    "title": "100 Coins",
    "description": "Get 100 coins",
    "price": 0.99,
    "localizedPrice": "$0.99",
    "currency": "USD"
  }
]
```

:::tip Using Signals
You can also use the `products_fetched` signal to receive products asynchronously:

```gdscript
func _ready():
    iap.products_fetched.connect(_on_products_fetched)
    iap.fetch_products(JSON.stringify(["coins_100"]), "inapp")

func _on_products_fetched(products: Array):
    for product in products:
        print("Product: ", product.productId)
```
:::

## fetch_subscriptions()

Fetches subscription information from the store.

```gdscript
func load_subscriptions():
    var sub_ids = ["premium_monthly", "premium_yearly"]
    var result_json = iap.fetch_subscriptions(JSON.stringify(sub_ids))
    var subscriptions = JSON.parse_string(result_json)

    for sub in subscriptions:
        print("Subscription: ", sub.productId)
        print("Price: ", sub.localizedPrice)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `subscription_ids` | `String` | JSON array of subscription IDs |

**Returns:** JSON array of subscriptions

## request_purchase()

Initiates a purchase request for a product or subscription.

```gdscript
# Purchase a product
func buy_product(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp"
    }
    var result_json = iap.request_purchase(JSON.stringify(params))
    var result = JSON.parse_string(result_json)

    if result.get("success", false):
        print("Purchase initiated")
    # Purchase result comes via purchase_updated signal

# Purchase a subscription
func buy_subscription(subscription_id: String, offer_token: String = ""):
    var params = {
        "sku": subscription_id,
        "type": "subs"
    }

    # Android: Add offer token if available
    if OS.get_name() == "Android" and offer_token != "":
        params["offerToken"] = offer_token

    iap.request_purchase(JSON.stringify(params))
```

**Parameters (JSON object):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Product or subscription ID |
| `type` | `String` | `"inapp"` or `"subs"` |
| `offerToken` | `String` | (Android only) Subscription offer token |
| `quantity` | `int` | (iOS only) Purchase quantity |
| `appAccountToken` | `String` | (iOS only) User identifier |

**Returns:** JSON string with result

:::warning Important
`request_purchase` initiates the purchase flow but does not return the purchase result directly. Handle purchase outcomes through the `purchase_updated` and `purchase_error` signals.
:::

## finish_transaction()

Completes a purchase transaction. Must be called after successful purchase verification.

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    # Validate receipt on your server first
    var verified = await verify_on_server(purchase)

    if verified:
        # Grant purchase to user
        grant_purchase_to_user(purchase)

        # Finish the transaction
        var params = {
            "purchase": purchase,
            "isConsumable": is_consumable(purchase.productId)
        }
        var result_json = iap.finish_transaction(JSON.stringify(params))
        var result = JSON.parse_string(result_json)

        if result.get("success", false):
            print("Transaction completed")
```

**Parameters (JSON object):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase` | `Object` | The purchase object to finish |
| `isConsumable` | `bool` | Whether the product is consumable |

**Returns:** JSON string with result

## get_available_purchases()

Retrieves available purchases for restoration (non-consumable products and subscriptions).

```gdscript
func restore_purchases():
    var purchases_json = iap.get_available_purchases()
    var purchases = JSON.parse_string(purchases_json)

    for purchase in purchases:
        # Validate and restore each purchase
        var is_valid = await verify_on_server(purchase)
        if is_valid:
            grant_purchase_to_user(purchase)

    print("Purchases restored")
```

**Returns:** JSON array of purchases

```json
[
  {
    "productId": "remove_ads",
    "transactionId": "1000000123456789",
    "purchaseToken": "...",
    "purchaseState": "purchased"
  }
]
```

**Platform behavior:**

- **iOS** — Returns active entitlements from StoreKit 2
- **Android** — Queries both in-app and subscription purchases, merges results

## deep_link_to_subscriptions()

Opens the platform-specific subscription management UI.

```gdscript
func open_subscription_settings():
    var options = {}

    if OS.get_name() == "Android":
        options["packageNameAndroid"] = "com.yourcompany.game"
        options["skuAndroid"] = "premium_monthly"  # Optional

    var result_json = iap.deep_link_to_subscriptions(JSON.stringify(options))
    var result = JSON.parse_string(result_json)

    if result.get("success", false):
        print("Subscription settings opened")
```

**Parameters (JSON object):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `packageNameAndroid` | `String` | (Android) Package name |
| `skuAndroid` | `String` | (Android, optional) Specific subscription SKU |

**Returns:** JSON string with result

## verify_purchase()

Verifies a purchase using the native OpenIAP implementation. This validates purchases using platform-specific methods.

```gdscript
func verify(product_id: String, purchase: Dictionary):
    var options = {}

    if OS.get_name() == "iOS":
        options["apple"] = {
            "sku": product_id
        }
    elif OS.get_name() == "Android":
        options["google"] = {
            "sku": product_id,
            "packageName": "com.yourcompany.game",
            "purchaseToken": purchase.purchaseToken,
            "accessToken": await get_access_token_from_server(),
            "isSub": false
        }

    var result_json = iap.verify_purchase(JSON.stringify(options))
    var result = JSON.parse_string(result_json)

    if result.get("isValid", false):
        print("Purchase verified!")
        grant_purchase_to_user(purchase)
```

**Parameters (JSON object):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `apple` | `Object` | iOS verification options |
| `apple.sku` | `String` | Product SKU to validate |
| `google` | `Object` | Android verification options |
| `google.sku` | `String` | Product SKU to validate |
| `google.packageName` | `String` | Android package name |
| `google.purchaseToken` | `String` | Purchase token from purchase |
| `google.accessToken` | `String` | OAuth2 access token |
| `google.isSub` | `bool` | Whether product is a subscription |

**Returns:** JSON string with verification result

```json
{
  "success": true,
  "isValid": true
}
```

For external verification services with additional security, consider using <IapKitLink>IAPKit</IapKitLink>.

## Server-Side Verification with IAPKit

For production apps, we recommend using <IapKitLink>IAPKit</IapKitLink> for server-side purchase verification. IAPKit provides:

- **Cross-platform verification** for both iOS and Android purchases
- **Subscription status tracking** with renewal detection
- **Fraud prevention** with receipt validation
- **Webhook notifications** for real-time purchase events

### Basic HTTP Verification

You can call IAPKit's verification API directly from your game or backend server:

```gdscript
# Verify purchase with IAPKit
func verify_with_iapkit(purchase: Dictionary) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)

    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer YOUR_IAPKIT_API_KEY"
    ]

    var body = {}
    if OS.get_name() == "iOS":
        body = {
            "apple": {
                "jws": purchase.get("purchaseToken", "")
            }
        }
    elif OS.get_name() == "Android":
        body = {
            "google": {
                "purchaseToken": purchase.get("purchaseToken", "")
            }
        }

    http.request(
        "https://api.iapkit.com/v1/verify",
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
    )

    var response = await http.request_completed
    http.queue_free()

    var result = JSON.parse_string(response[3].get_string_from_utf8())
    return result if result is Dictionary else {}

# Usage in purchase handler
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "purchased":
        var verification = await verify_with_iapkit(purchase)

        if verification.get("isValid", false):
            var iapkit_state = verification.get("state", "")

            match iapkit_state:
                "entitled":
                    # User is entitled to the product
                    grant_purchase(purchase.productId)
                "pending":
                    # Purchase is pending - wait for confirmation
                    print("Purchase pending")
                "expired":
                    # Subscription has expired
                    revoke_entitlement(purchase.productId)
                "inauthentic":
                    # Purchase could not be verified - possible fraud
                    print("Warning: Inauthentic purchase detected")

        # Always finish the transaction
        var params = {
            "purchase": purchase,
            "isConsumable": is_consumable(purchase.productId)
        }
        iap.finish_transaction(JSON.stringify(params))
```

### IAPKit Purchase States

| State | Description | Action |
|-------|-------------|--------|
| `entitled` | User is entitled to the product | Grant entitlement |
| `pending` | Purchase is pending | Wait for confirmation |
| `canceled` | Purchase was canceled | Do not grant |
| `expired` | Subscription has expired | Revoke entitlement |
| `ready-to-consume` | Consumable ready to be consumed | Consume and grant |
| `consumed` | Consumable has been consumed | Already processed |
| `inauthentic` | Purchase could not be verified | Reject - possible fraud |

**See also:**

- <IapKitLink>IAPKit Dashboard</IapKitLink>
- [IAPKit Purchase States](https://www.openiap.dev/docs/apis#iapkit-purchase-states)
- [Error Codes Reference](../error-codes)

---

## Purchase Interface

The purchase object structure returned from purchases:

```gdscript
# Purchase Dictionary Structure
{
    "productId": "coins_100",
    "transactionId": "1000000123456789",
    "transactionDate": 1703980800000,
    "purchaseToken": "...",

    # iOS-specific
    "originalTransactionDateIOS": 1703980800000,
    "originalTransactionIdentifierIOS": "1000000123456789",
    "expirationDateIOS": 1706659200000,
    "environmentIOS": "Sandbox",

    # Android-specific
    "purchaseState": "purchased",
    "isAcknowledgedAndroid": false,
    "autoRenewingAndroid": true,
    "packageNameAndroid": "com.yourcompany.game"
}
```

---

## Complete Example

```gdscript
extends Node

var iap: GodotIap
var products: Array = []

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        _load_products()

func _load_products():
    var product_ids = ["coins_100", "remove_ads"]
    iap.fetch_products(JSON.stringify(product_ids), "inapp")

func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    for product in products:
        print("Loaded: ", product.productId, " - ", product.localizedPrice)

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "purchased":
        # Verify on server
        var verified = await verify_on_server(purchase)
        if verified:
            grant_purchase(purchase.productId)

            # Finish transaction
            var params = {
                "purchase": purchase,
                "isConsumable": is_consumable(purchase.productId)
            }
            iap.finish_transaction(JSON.stringify(params))

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    match code:
        "USER_CANCELED":
            print("User canceled")
        _:
            print("Error: ", error.get("message", ""))

func buy(product_id: String):
    var params = {"sku": product_id, "type": "inapp"}
    iap.request_purchase(JSON.stringify(params))

func restore():
    var purchases = JSON.parse_string(iap.get_available_purchases())
    for purchase in purchases:
        grant_purchase(purchase.productId)
```
