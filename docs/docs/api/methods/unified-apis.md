---
title: Unified APIs
sidebar_label: Unified APIs
sidebar_position: 2
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Unified APIs

<IapKitBanner />

These cross-platform methods work on both iOS and Android using the **type-safe API**. For StoreKit/Play-specific helpers, see the [iOS Specific](./ios-specific) and [Android Specific](./android-specific) sections.

- [`init_connection()`](#init_connection) — Initialize the store connection
- [`end_connection()`](#end_connection) — End the store connection and cleanup
- [`fetch_products()`](#fetch_products) — Fetch product metadata
- [`request_purchase()`](#request_purchase) — Start a purchase
- [`finish_transaction()`](#finish_transaction) — Complete a transaction after validation
- [`get_available_purchases()`](#get_available_purchases) — Restore non-consumables and subscriptions
- [`deep_link_to_subscriptions()`](#deep_link_to_subscriptions) — Open native subscription management UI
- [`verify_purchase()`](#verify_purchase) — Verify purchase with native OpenIAP implementation

## Setup

```gdscript
extends Node

# Load OpenIAP types for type-safe API
const Types = preload("res://addons/godot-iap/types.gd")

# Reference to GodotIapWrapper node (add as child in scene tree)
@onready var iap = $GodotIapWrapper
```

## init_connection()

Initializes the connection to the store. This method must be called before any other store operations.

```gdscript
func _ready():
    _setup_signals()
    _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.connected.connect(_on_connected)

func _initialize():
    # Returns bool - true if connection successful
    var success = iap.init_connection()

    if success:
        print("Store connection initialized")
    else:
        print("Failed to initialize connection")
```

**Returns:** `bool` - `true` if connection successful

## end_connection()

Ends the connection to the store and cleans up resources.

```gdscript
func _cleanup():
    # Returns bool - true if disconnection successful
    var success = iap.end_connection()

    if success:
        print("Store connection ended")
```

**Returns:** `bool` - `true` if disconnection successful

## fetch_products()

Fetches product information from the store using typed request.

```gdscript
func load_products():
    # Create typed ProductRequest
    var request = Types.ProductRequest.new()
    var skus: Array[String] = ["coins_100", "coins_500", "remove_ads"]
    request.skus = skus
    request.type = Types.ProductQueryType.ALL  # or IN_APP, SUBS

    # Returns Array of Types.ProductAndroid or Types.ProductIOS
    var products = iap.fetch_products(request)

    for product in products:
        # Access typed properties directly
        print("Product: ", product.id)
        print("Price: ", product.display_price)
        print("Title: ", product.title)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `request` | `Types.ProductRequest` | Product request with SKUs and type |

**Returns:** `Array` of `Types.ProductAndroid` (Android) or `Types.ProductIOS` (iOS)

:::tip Using Signals
Products are also available through the `products_fetched` signal for async handling:

```gdscript
func _ready():
    iap.products_fetched.connect(_on_products_fetched)

func _on_products_fetched(result: Dictionary):
    if result.has("products"):
        for product_dict in result["products"]:
            print("Product: ", product_dict.get("id", ""))
```
:::

## request_purchase()

Initiates a purchase request for a product or subscription using typed props.

```gdscript
# Purchase a product
func buy_product(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    props.type = Types.ProductQueryType.IN_APP

    # Returns Types.PurchaseAndroid, Types.PurchaseIOS, or null
    var purchase = iap.request_purchase(props)

    if purchase:
        print("Purchase initiated: ", purchase.product_id)
    # Purchase result also comes via purchase_updated signal

# Purchase a subscription
func buy_subscription(subscription_id: String, offer_token: String = ""):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    # Android configuration (offer token required for subscriptions)
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [subscription_id]
    props.request.google.skus = skus
    if offer_token != "":
        var offers: Array[Types.SubscriptionOfferAndroid] = []
        var offer = Types.SubscriptionOfferAndroid.new()
        offer.sku = subscription_id
        offer.offer_token = offer_token
        offers.append(offer)
        props.request.google.subscription_offers = offers

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = subscription_id

    iap.request_purchase(props)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `props` | `Types.RequestPurchaseProps` | Purchase request with platform-specific options |

**Returns:** `Variant` - `Types.PurchaseAndroid`, `Types.PurchaseIOS`, or `null`

:::warning Important
`request_purchase` initiates the purchase flow. Handle purchase outcomes through the `purchase_updated` and `purchase_error` signals.
:::

## finish_transaction()

Completes a purchase transaction. Must be called after successful purchase verification.

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    # Validate receipt on your server first (recommended)
    var verified = await verify_on_server(purchase)

    if verified:
        # Grant purchase to user
        grant_purchase_to_user(purchase)

        # Finish the transaction using Dictionary convenience method
        var is_consumable = is_consumable_product(purchase.get("productId", ""))
        var result = iap.finish_transaction_dict(purchase, is_consumable)

        if result.success:
            print("Transaction completed")

# Alternative: Using typed PurchaseInput
func finish_with_typed_input(purchase: Dictionary):
    var purchase_input = Types.PurchaseInput.from_dict(purchase)
    var is_consumable = true
    var result = iap.finish_transaction(purchase_input, is_consumable)

    if result.success:
        print("Transaction finished")
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase` | `Types.PurchaseInput` or `Dictionary` | The purchase to finish |
| `is_consumable` | `bool` | Whether the product is consumable |

**Returns:** `Types.VoidResult` with `success` boolean

## get_available_purchases()

Retrieves available purchases for restoration (non-consumable products and subscriptions).

```gdscript
func restore_purchases():
    # Returns Array of Types.PurchaseAndroid or Types.PurchaseIOS
    var purchases = iap.get_available_purchases()

    for purchase in purchases:
        # Access typed properties
        print("Product: ", purchase.product_id)

        # Validate and restore each purchase
        var is_valid = await verify_on_server_typed(purchase)
        if is_valid:
            grant_purchase_to_user_typed(purchase)

    print("Purchases restored")
```

**Returns:** `Array` of `Types.PurchaseAndroid` (Android) or `Types.PurchaseIOS` (iOS)

**Platform behavior:**

- **iOS** — Returns active entitlements from StoreKit 2
- **Android** — Queries both in-app and subscription purchases, merges results

## deep_link_to_subscriptions()

Opens the platform-specific subscription management UI.

```gdscript
func open_subscription_settings():
    var options = Types.DeepLinkOptions.new()

    if OS.get_name() == "Android":
        options.package_name_android = "com.yourcompany.game"
        options.sku_android = "premium_monthly"  # Optional

    iap.deep_link_to_subscriptions(options)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | `Types.DeepLinkOptions` | Deep link options (optional) |

## verify_purchase()

Verifies a purchase using the native OpenIAP implementation. This validates purchases using platform-specific methods.

```gdscript
func verify(product_id: String, purchase):
    var props = Types.VerifyPurchaseProps.new()

    if OS.get_name() == "iOS":
        props.apple = Types.VerifyPurchasePropsIOS.new()
        props.apple.sku = product_id
    elif OS.get_name() == "Android":
        props.google = Types.VerifyPurchasePropsAndroid.new()
        props.google.sku = product_id
        props.google.package_name = "com.yourcompany.game"
        props.google.purchase_token = purchase.purchase_token
        props.google.access_token = await get_access_token_from_server()
        props.google.is_sub = false

    # Returns Types.VerifyPurchaseResultIOS or Types.VerifyPurchaseResultAndroid
    var result = iap.verify_purchase(props)

    if result and result.is_valid:
        print("Purchase verified!")
        grant_purchase_to_user_typed(purchase)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `props` | `Types.VerifyPurchaseProps` | Verification options |

**Returns:** `Types.VerifyPurchaseResultIOS` or `Types.VerifyPurchaseResultAndroid`, or `null`

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

    if state == "purchased" or state == "Purchased":
        var verification = await verify_with_iapkit(purchase)

        if verification.get("isValid", false):
            var iapkit_state = verification.get("state", "")

            match iapkit_state:
                "entitled":
                    # User is entitled to the product
                    grant_purchase(purchase.get("productId", ""))
                "pending":
                    # Purchase is pending - wait for confirmation
                    print("Purchase pending")
                "expired":
                    # Subscription has expired
                    revoke_entitlement(purchase.get("productId", ""))
                "inauthentic":
                    # Purchase could not be verified - possible fraud
                    print("Warning: Inauthentic purchase detected")

        # Always finish the transaction
        var is_consumable = is_consumable_product(purchase.get("productId", ""))
        iap.finish_transaction_dict(purchase, is_consumable)
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

The purchase dictionary structure returned from `purchase_updated` signal:

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

const Types = preload("res://addons/godot-iap/types.gd")

@onready var iap = $GodotIapWrapper

var products: Array = []

func _ready():
    _setup_signals()
    _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.connected.connect(_on_connected)

func _initialize():
    if iap.init_connection():
        _load_products()

func _load_products():
    var request = Types.ProductRequest.new()
    var skus: Array[String] = ["coins_100", "remove_ads"]
    request.skus = skus
    request.type = Types.ProductQueryType.ALL

    products = iap.fetch_products(request)
    for product in products:
        print("Loaded: ", product.id, " - ", product.display_price)

func _on_connected():
    print("Store connected")

func _on_products_fetched(result: Dictionary):
    # Handle async products fetch (iOS)
    if result.has("products"):
        for product_dict in result["products"]:
            print("Fetched: ", product_dict.get("id", ""))

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "purchased" or state == "Purchased":
        # Verify on server
        var verified = await verify_on_server(purchase)
        if verified:
            grant_purchase(purchase.get("productId", ""))

            # Finish transaction
            var is_consumable = is_consumable_product(purchase.get("productId", ""))
            iap.finish_transaction_dict(purchase, is_consumable)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    match code:
        "USER_CANCELED":
            print("User canceled")
        _:
            print("Error: ", error.get("message", ""))

func buy(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    iap.request_purchase(props)

func restore():
    var purchases = iap.get_available_purchases()
    for purchase in purchases:
        grant_purchase(purchase.product_id)

func verify_on_server(purchase: Dictionary) -> bool:
    # Implement server-side verification
    return true

func grant_purchase(product_id: String):
    # Grant content to user
    pass

func is_consumable_product(product_id: String) -> bool:
    return product_id in ["coins_100", "coins_500"]
```
