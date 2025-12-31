---
sidebar_position: 3
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# iOS-Specific Methods

<IapKitBanner />

Methods available only on iOS platform using StoreKit 2. All methods use typed parameters and return typed objects.

## Setup

```gdscript
# Load OpenIAP types
const Types = preload("res://addons/godot-iap/types.gd")
```

## Transaction Management

### sync_ios

Synchronize transactions with the App Store. Call this to ensure all transactions are up to date.

```gdscript
func sync_ios() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func refresh_purchases():
    var result = GodotIapPlugin.sync_ios()
    if result.success:
        print("Sync completed")
```

---

### clear_transaction_ios

Clear finished transactions from the queue.

```gdscript
func clear_transaction_ios() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

---

### get_pending_transactions_ios

Get all pending transactions that haven't been finished.

```gdscript
func get_pending_transactions_ios() -> Array
```

**Returns:** `Array` of `Types.TransactionIOS`

**Example:**
```gdscript
func check_pending():
    var transactions = GodotIapPlugin.get_pending_transactions_ios()
    for tx in transactions:
        # Access typed properties
        print("Pending: %s" % tx.product_id)
```

---

## Offer Code & Subscriptions

### present_code_redemption_sheet_ios

Present the App Store offer code redemption sheet.

```gdscript
func present_code_redemption_sheet_ios() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func _on_redeem_code_pressed():
    GodotIapPlugin.present_code_redemption_sheet_ios()
```

:::info Note
Available on iOS 14.0+. Results come through the `purchase_updated` signal.
:::

---

### show_manage_subscriptions_ios

Open the subscription management page in Settings.

```gdscript
func show_manage_subscriptions_ios() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func _on_manage_subscriptions_pressed():
    GodotIapPlugin.show_manage_subscriptions_ios()
```

---

### subscription_status_ios

Get the subscription status for a product.

```gdscript
func subscription_status_ios(sku: String) -> Array
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Subscription product ID |

**Returns:** `Array` of `Types.SubscriptionStatusIOS`

**Example:**
```gdscript
func check_subscription_status(subscription_id: String):
    var statuses = GodotIapPlugin.subscription_status_ios(subscription_id)
    for status in statuses:
        print("State: ", status.state)
        if status.renewal_info:
            print("Will renew: ", status.renewal_info.will_auto_renew)
```

---

### is_eligible_for_intro_offer_ios

Check if user is eligible for an introductory offer.

```gdscript
func is_eligible_for_intro_offer_ios(group_id: String) -> bool
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `group_id` | `String` | Subscription group ID |

**Returns:** `bool`

**Example:**
```gdscript
func check_intro_eligibility(group_id: String):
    if GodotIapPlugin.is_eligible_for_intro_offer_ios(group_id):
        show_intro_offer_ui()
```

---

## Refund & Entitlement

### begin_refund_request_ios

Begin a refund request for a transaction.

```gdscript
func begin_refund_request_ios(transaction_id: String) -> Types.RefundRequestResultIOS
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `transaction_id` | `String` | Transaction ID to refund |

**Returns:** `Types.RefundRequestResultIOS`

**Example:**
```gdscript
func request_refund(transaction_id: String):
    var result = GodotIapPlugin.begin_refund_request_ios(transaction_id)
    print("Refund status: ", result.status)
```

---

### current_entitlement_ios

Get the current entitlement for a product.

```gdscript
func current_entitlement_ios(sku: String) -> Variant
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Product ID |

**Returns:** `Variant` - `Types.TransactionIOS` or `null`

---

### latest_transaction_ios

Get the latest transaction for a product.

```gdscript
func latest_transaction_ios(sku: String) -> Variant
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Product ID |

**Returns:** `Variant` - `Types.TransactionIOS` or `null`

---

## Storefront

### get_storefront_ios

Get the user's storefront information (country/region).

```gdscript
func get_storefront_ios() -> Variant
```

**Returns:** `Variant` - `Types.StorefrontIOS` or `null`

**Example:**
```gdscript
func get_user_country() -> String:
    var storefront = GodotIapPlugin.get_storefront_ios()
    if storefront:
        return storefront.country_code
    return ""
```

---

## App Transaction

### get_app_transaction_ios

Get the app transaction (proof of purchase from App Store).

```gdscript
func get_app_transaction_ios() -> Variant
```

**Returns:** `Variant` - `Types.AppTransactionIOS` or `null`

**Example:**
```gdscript
func verify_app_purchase():
    var app_tx = GodotIapPlugin.get_app_transaction_ios()
    if app_tx:
        # Send to server for verification
        await verify_on_server(app_tx.jws)
```

---

## Promoted Products

### get_promoted_product_ios

Get the currently promoted product (from App Store promotional purchase).

```gdscript
func get_promoted_product_ios() -> Variant
```

**Returns:** `Variant` - `Types.ProductIOS` or `null`

---

### request_purchase_on_promoted_product_ios

Complete a purchase for a promoted product.

```gdscript
func request_purchase_on_promoted_product_ios() -> Variant
```

**Returns:** `Variant` - `Types.PurchaseIOS` or `null`

:::warning Deprecated
This method is deprecated. Use `promoted_product_ios` signal with `request_purchase` instead.
:::

**Example:**
```gdscript
func _setup_signals():
    GodotIapPlugin.promoted_product_ios.connect(_on_promoted_product)

func _on_promoted_product(product_id: String):
    # User tapped a promoted product in App Store
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id
    props.type = Types.ProductQueryType.IN_APP

    GodotIapPlugin.request_purchase(props)
```

---

## Receipt & Verification

### get_receipt_data_ios

Get the App Store receipt data.

```gdscript
func get_receipt_data_ios() -> String
```

**Returns:** `String` - Base64-encoded receipt data

**Example:**
```gdscript
func get_receipt() -> String:
    return GodotIapPlugin.get_receipt_data_ios()
```

---

### is_transaction_verified_ios

Check if a transaction is verified.

```gdscript
func is_transaction_verified_ios(transaction_id: String) -> bool
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `transaction_id` | `String` | Transaction ID |

**Returns:** `bool`

---

### get_transaction_jws_ios

Get the JWS (JSON Web Signature) for a transaction.

```gdscript
func get_transaction_jws_ios(transaction_id: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `transaction_id` | `String` | Transaction ID |

**Returns:** `String` - JWS token

---

## External Purchase APIs (iOS 18.2+)

These methods support external purchase flows for apps in eligible regions.

### can_present_external_purchase_notice_ios

Check if external purchase notice can be presented.

```gdscript
func can_present_external_purchase_notice_ios() -> bool
```

**Returns:** `bool`

---

### present_external_purchase_notice_sheet_ios

Present the external purchase notice sheet to the user.

```gdscript
func present_external_purchase_notice_sheet_ios() -> Types.VoidResult
```

**Returns:** `Types.VoidResult`

---

### present_external_purchase_link_ios

Present an external purchase link.

```gdscript
func present_external_purchase_link_ios(url: String) -> Types.VoidResult
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | External purchase URL |

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func open_external_purchase():
    # First check if we can present the notice
    if GodotIapPlugin.can_present_external_purchase_notice_ios():
        # Present the notice first
        GodotIapPlugin.present_external_purchase_notice_sheet_ios()

func _on_notice_accepted():
    # After user accepts, open external link
    GodotIapPlugin.present_external_purchase_link_ios("https://your-store.com/purchase")
```

:::info Regional Availability
External purchase APIs are only available in regions where Apple allows external purchasing (e.g., EU under DMA).
:::
