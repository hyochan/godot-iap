---
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Core Methods

<IapKitBanner />

Core methods available on both iOS and Android platforms. All methods use typed parameters and return typed objects.

## Setup

Add `GodotIapWrapper` as a child node in your scene, then reference it in your script:

```gdscript
extends Node

# Load OpenIAP types
const Types = preload("res://addons/godot-iap/types.gd")

# Reference to GodotIapWrapper node
@onready var iap = $GodotIapWrapper

# Throughout this documentation, we use `iap` to reference the wrapper.
# You can also use any variable name you prefer.
```

:::info GodotIapPlugin Reference
In the examples below, `GodotIapPlugin` refers to your reference to the `GodotIapWrapper` node.
Replace it with your own variable name (e.g., `iap`, `$GodotIapWrapper`, or `IapManager` if using an autoload).
:::

## Connection Methods

### init_connection

Initialize the billing connection. Must be called before any other IAP operations.

```gdscript
func init_connection() -> bool
```

**Returns:** `bool` - `true` if connection successful

**Example:**
```gdscript
func _ready():
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)

    if GodotIapPlugin.init_connection():
        print("IAP connection initialized")
        _fetch_products()
```

---

### end_connection

End the billing connection. Call when your app no longer needs IAP functionality.

```gdscript
func end_connection() -> Types.VoidResult
```

**Returns:** `Types.VoidResult` with `success` boolean

**Example:**
```gdscript
func _exit_tree():
    var result = GodotIapPlugin.end_connection()
    if result.success:
        print("Connection ended")
```

---

## Product Methods

### fetch_products

Fetch product details from the store. Returns an array of typed product objects.

```gdscript
func fetch_products(request: Types.ProductRequest) -> Array
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `request` | `Types.ProductRequest` | Product request with SKUs and type |

**Returns:** `Array` of `Types.ProductAndroid` (Android) or `Types.ProductIOS` (iOS)

:::info Platform-Specific Types
GDScript doesn't support Union types. The returned array contains either `ProductAndroid` or `ProductIOS` objects depending on the platform. Both share common properties like `id`, `title`, and `display_price`.
:::

**Example:**
```gdscript
func _fetch_products():
    var request = Types.ProductRequest.new()
    request.skus = ["coins_100", "coins_500", "remove_ads"]
    request.type = Types.ProductQueryType.ALL

    var products = GodotIapPlugin.fetch_products(request)
    for product in products:
        # Access typed properties directly
        print("Product: %s - %s" % [product.id, product.display_price])
        print("  Title: %s" % product.title)
        print("  Description: %s" % product.description)
```

---

## Purchase Methods

### request_purchase

Request a purchase for a product.

```gdscript
func request_purchase(props: Types.RequestPurchaseProps) -> Variant
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `props` | `Types.RequestPurchaseProps` | Purchase request with platform-specific options |

**Returns:** `Variant` - `Types.PurchaseAndroid`, `Types.PurchaseIOS`, or `null`

**Example:**
```gdscript
func purchase_product(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    props.request.google.skus = [product_id]

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id

    props.type = Types.ProductQueryType.IN_APP

    var purchase = GodotIapPlugin.request_purchase(props)
    if purchase:
        print("Purchase initiated: ", purchase.product_id)
```

---

### finish_transaction

Finish a transaction after processing. **Must be called for every successful purchase.**

```gdscript
func finish_transaction(purchase: Types.PurchaseInput, is_consumable: bool) -> Types.VoidResult
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase` | `Types.PurchaseInput` | Purchase to finish |
| `is_consumable` | `bool` | Whether the product is consumable |

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func _on_purchase_updated(purchase: Dictionary):
    if purchase.get("purchaseState") == "Purchased":
        # Verify on server first (recommended)
        var verified = await verify_on_server(purchase)
        if verified:
            var purchase_input = Types.PurchaseInput.from_dict(purchase)
            var is_consumable = _is_consumable_product(purchase.get("productId", ""))
            var result = GodotIapPlugin.finish_transaction(purchase_input, is_consumable)
            if result.success:
                print("Transaction finished")
```

---

### get_available_purchases

Get all available (unfinished) purchases.

```gdscript
func get_available_purchases() -> Array
```

**Returns:** `Array` of `Types.PurchaseAndroid` (Android) or `Types.PurchaseIOS` (iOS)

**Example:**
```gdscript
func restore_purchases():
    var purchases = GodotIapPlugin.get_available_purchases()
    for purchase in purchases:
        # Access typed properties
        print("Found purchase: %s" % purchase.product_id)
        await process_purchase(purchase)
```

---

### restore_purchases

Restore previous purchases. Useful for non-consumable products and subscriptions.

```gdscript
func restore_purchases() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func _on_restore_pressed():
    var result = GodotIapPlugin.restore_purchases()
    if result.success:
        print("Restore initiated - results come through purchase_updated signal")
```

---

## Subscription Methods

### get_active_subscriptions

Get active subscriptions for given IDs.

```gdscript
func get_active_subscriptions(subscription_ids: Array[String] = []) -> Array
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `subscription_ids` | `Array[String]` | Subscription IDs (empty for all) |

**Returns:** `Array` of `Types.ActiveSubscription`

**Example:**
```gdscript
func check_premium_status() -> bool:
    var ids: Array[String] = ["premium_monthly", "premium_yearly"]
    var active_subs = GodotIapPlugin.get_active_subscriptions(ids)
    return active_subs.size() > 0
```

---

### has_active_subscriptions

Check if user has any active subscriptions.

```gdscript
func has_active_subscriptions(subscription_ids: Array[String] = []) -> bool
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `subscription_ids` | `Array[String]` | Subscription IDs (empty for all) |

**Returns:** `bool`

**Example:**
```gdscript
func is_premium() -> bool:
    var ids: Array[String] = ["premium_monthly", "premium_yearly"]
    return GodotIapPlugin.has_active_subscriptions(ids)
```

---

## Signal Handlers

### purchase_updated

Emitted when a purchase is updated.

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.get("productId", "")
    var state = purchase.get("purchaseState", "")

    match state:
        "Purchased", "purchased":
            await handle_successful_purchase(purchase)
        "Pending", "pending":
            show_pending_message(product_id)
        _:
            show_error_message()
```

**Purchase Dictionary Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | Unique purchase ID |
| `productId` | `String` | Product identifier |
| `transactionId` | `String` | Transaction identifier |
| `purchaseState` | `String` | "Purchased", "Pending", etc. |
| `transactionDate` | `int` | Purchase timestamp |
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
            GodotIapPlugin.restore_purchases()
        _:
            show_error_dialog(message)
```

---

### products_fetched

Emitted when products are fetched (primarily used for iOS async operations).

```gdscript
func _on_products_fetched(result: Dictionary):
    if result.has("products"):
        for product_dict in result["products"]:
            print("Fetched: ", product_dict.get("id", ""))
    elif result.has("error"):
        print("Failed: ", result.get("error", ""))
```
