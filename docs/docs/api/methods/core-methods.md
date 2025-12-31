---
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Core Methods

<IapKitBanner />

Core methods available on both iOS and Android platforms.

## Connection Methods

### init_connection

Initialize the billing connection. Must be called before any other IAP operations.

```gdscript
func init_connection() -> String
```

**Returns:** JSON string with result

```json
{
  "success": true
}
```

**Example:**
```gdscript
var result = JSON.parse_string(iap.init_connection())
if result.get("success", false):
    print("IAP connection initialized")
```

---

### end_connection

End the billing connection. Call when your app no longer needs IAP functionality.

```gdscript
func end_connection() -> String
```

**Returns:** JSON string with result

```json
{
  "success": true
}
```

**Example:**
```gdscript
func _exit_tree():
    if iap:
        iap.end_connection()
```

---

## Product Methods

### fetch_products

Fetch product details from the store.

```gdscript
func fetch_products(skus_json: String, product_type: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `skus_json` | `String` | JSON array of product IDs |
| `product_type` | `String` | "inapp" or "subs" |

**Returns:** JSON string with status (result via `products_fetched` signal)

**Example:**
```gdscript
var product_ids = ["coins_100", "coins_500", "remove_ads"]
iap.fetch_products(JSON.stringify(product_ids), "inapp")

# Handle result in signal
func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var products = JSON.parse_string(result.get("productsJson", "[]"))
        for product in products:
            print("Product: ", product.id, " - ", product.displayPrice)
```

---

### fetch_subscriptions

Fetch subscription product details.

```gdscript
func fetch_subscriptions(skus_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `skus_json` | `String` | JSON array of subscription IDs |

**Returns:** JSON string with status

**Example:**
```gdscript
var sub_ids = ["premium_monthly", "premium_yearly"]
iap.fetch_subscriptions(JSON.stringify(sub_ids))
```

---

## Purchase Methods

### request_purchase

Request a purchase for a product.

```gdscript
func request_purchase(params_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `params_json` | `String` | JSON object with purchase parameters |

**Purchase Parameters:**
```json
{
  "sku": "product_id",
  "ios": {
    "quantity": 1,
    "uuid": "optional-uuid",
    "appAccountToken": "optional-token"
  },
  "android": {
    "skus": ["product_id"],
    "obfuscatedAccountId": "optional",
    "obfuscatedProfileId": "optional"
  }
}
```

**Returns:** JSON string with status

**Example:**
```gdscript
func purchase_product(product_id: String):
    var params = {
        "sku": product_id,
        "ios": { "quantity": 1 },
        "android": { "skus": [product_id] }
    }
    iap.request_purchase(JSON.stringify(params))
```

---

### request_subscription

Request a subscription purchase.

```gdscript
func request_subscription(params_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `params_json` | `String` | JSON object with subscription parameters |

**Subscription Parameters:**
```json
{
  "sku": "subscription_id",
  "ios": {
    "quantity": 1,
    "promotionalOffer": {
      "id": "offer_id",
      "keyIdentifier": "key_id",
      "nonce": "nonce",
      "timestamp": 1234567890,
      "signature": "signature"
    }
  },
  "android": {
    "skus": ["subscription_id"],
    "subscriptionOffers": [{
      "sku": "subscription_id",
      "offerToken": "token"
    }]
  }
}
```

**Example:**
```gdscript
func subscribe(subscription_id: String):
    var params = {
        "sku": subscription_id,
        "ios": { "quantity": 1 },
        "android": {
            "skus": [subscription_id],
            "subscriptionOffers": [{
                "sku": subscription_id,
                "offerToken": selected_offer_token
            }]
        }
    }
    iap.request_subscription(JSON.stringify(params))
```

---

### finish_transaction

Finish a transaction after processing. **Must be called for every successful purchase.**

```gdscript
func finish_transaction(purchase_json: String, is_consumable: bool) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase_json` | `String` | JSON object of the purchase |
| `is_consumable` | `bool` | Whether the product is consumable |

**Returns:** JSON string with result

**Example:**
```gdscript
func _on_purchase_updated(purchase: Dictionary):
    if purchase.get("purchaseState") == "purchased":
        # Verify on server first
        var verified = await verify_on_server(purchase)
        if verified:
            var is_consumable = is_consumable_product(purchase.productId)
            var result = JSON.parse_string(
                iap.finish_transaction(JSON.stringify(purchase), is_consumable)
            )
            if result.get("success", false):
                print("Transaction finished")
```

---

### get_available_purchases

Get all available (unfinished) purchases.

```gdscript
func get_available_purchases() -> String
```

**Returns:** JSON string with purchases array

```json
{
  "success": true,
  "purchasesJson": "[{\"productId\":\"coins_100\",\"purchaseState\":\"purchased\",...}]"
}
```

**Example:**
```gdscript
func restore_purchases():
    var result = JSON.parse_string(iap.get_available_purchases())
    if result.get("success", false):
        var purchases = JSON.parse_string(result.get("purchasesJson", "[]"))
        for purchase in purchases:
            await process_purchase(purchase)
```

---

### restore_purchases

Restore previous purchases. Useful for non-consumable products and subscriptions.

```gdscript
func restore_purchases() -> String
```

**Returns:** JSON string with status

**Example:**
```gdscript
func _on_restore_pressed():
    iap.restore_purchases()

# Results come through purchase_updated signal
```

---

## Subscription Methods

### get_active_subscriptions

Get active subscriptions for given IDs.

```gdscript
func get_active_subscriptions(subscription_ids_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `subscription_ids_json` | `String` | JSON array of subscription IDs (or empty for all) |

**Returns:** JSON string with active subscriptions

**Example:**
```gdscript
func check_premium_status():
    var ids = ["premium_monthly", "premium_yearly"]
    var result = JSON.parse_string(iap.get_active_subscriptions(JSON.stringify(ids)))
    if result.get("success", false):
        var subs = JSON.parse_string(result.get("subscriptionsJson", "[]"))
        return subs.size() > 0
    return false
```

---

### has_active_subscriptions

Check if user has any active subscriptions.

```gdscript
func has_active_subscriptions(subscription_ids_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `subscription_ids_json` | `String` | JSON array of subscription IDs (or empty for all) |

**Returns:** JSON string with boolean result

```json
{
  "success": true,
  "hasActive": true
}
```

**Example:**
```gdscript
func is_premium():
    var ids = ["premium_monthly", "premium_yearly"]
    var result = JSON.parse_string(iap.has_active_subscriptions(JSON.stringify(ids)))
    return result.get("hasActive", false)
```

---

## Signal Handlers

### purchase_updated

Emitted when a purchase is updated.

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.get("productId", "")
    var state = purchase.get("purchaseState", "")
    var transaction_id = purchase.get("transactionId", "")

    match state:
        "purchased":
            await handle_successful_purchase(purchase)
        "pending":
            show_pending_message(product_id)
        "failed":
            show_error_message()
```

**Purchase Dictionary Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique purchase ID |
| `productId` | `String` | Product identifier |
| `transactionId` | `String` | Transaction identifier |
| `purchaseState` | `String` | "purchased", "pending", "failed" |
| `transactionDate` | `int` | Purchase timestamp |
| `quantity` | `int` | Quantity purchased |
| `platform` | `String` | "ios" or "android" |
| `purchaseToken` | `String` | (Android) Purchase token |
| `isAcknowledged` | `bool` | (Android) Whether acknowledged |

---

### purchase_error

Emitted when a purchase error occurs.

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "")

    match code:
        "USER_CANCELED":
            print("Purchase canceled by user")
        "ITEM_ALREADY_OWNED":
            restore_purchases()
        _:
            show_error_dialog(message)
```

---

### products_fetched

Emitted when products are fetched.

```gdscript
func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var json = result.get("productsJson", "[]")
        var products = JSON.parse_string(json)
        update_store_ui(products)
    else:
        var error = result.get("error", "Unknown error")
        print("Failed to fetch products: ", error)
```
