---
sidebar_position: 3
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# iOS-Specific Methods

<IapKitBanner />

Methods available only on iOS platform using StoreKit 2.

## Transaction Management

### sync_ios

Synchronize transactions with the App Store. Call this to ensure all transactions are up to date.

```gdscript
func sync_ios() -> String
```

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func refresh_purchases():
    iap.sync_ios()
```

---

### clear_transaction_ios

Clear finished transactions from the queue.

```gdscript
func clear_transaction_ios() -> String
```

**Returns:** JSON string with status

---

### get_pending_transactions_ios

Get all pending transactions that haven't been finished.

```gdscript
func get_pending_transactions_ios() -> String
```

**Returns:** JSON string with pending transactions

**Example:**
```gdscript
func check_pending():
    var result = JSON.parse_string(iap.get_pending_transactions_ios())
    if result.get("success", false):
        var transactions = JSON.parse_string(result.get("transactionsJson", "[]"))
        for tx in transactions:
            print("Pending: ", tx.productId)
```

---

## Offer Code & Subscriptions

### present_code_redemption_sheet_ios

Present the App Store offer code redemption sheet.

```gdscript
func present_code_redemption_sheet_ios() -> String
```

**Returns:** JSON string with status

**Example:**
```gdscript
func _on_redeem_code_pressed():
    iap.present_code_redemption_sheet_ios()
```

:::info Note
Available on iOS 14.0+. Results come through the `purchase_updated` signal.
:::

---

### show_manage_subscriptions_ios

Open the subscription management page in Settings.

```gdscript
func show_manage_subscriptions_ios() -> String
```

**Returns:** JSON string with status

**Example:**
```gdscript
func _on_manage_subscriptions_pressed():
    iap.show_manage_subscriptions_ios()
```

---

### subscription_status_ios

Get the subscription status for a product.

```gdscript
func subscription_status_ios(sku: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Subscription product ID |

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func check_subscription_status(subscription_id: String):
    iap.subscription_status_ios(subscription_id)

func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var statuses = JSON.parse_string(result.get("statusesJson", "[]"))
        for status in statuses:
            print("State: ", status.state)
            if status.renewalInfo:
                print("Will renew: ", status.renewalInfo.willAutoRenew)
```

---

### is_eligible_for_intro_offer_ios

Check if user is eligible for an introductory offer.

```gdscript
func is_eligible_for_intro_offer_ios(group_id: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `group_id` | `String` | Subscription group ID |

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func check_intro_eligibility(group_id: String):
    iap.is_eligible_for_intro_offer_ios(group_id)

func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var is_eligible = result.get("isEligible", false)
        if is_eligible:
            show_intro_offer_ui()
```

---

## Refund & Entitlement

### begin_refund_request_ios

Begin a refund request for a transaction.

```gdscript
func begin_refund_request_ios(transaction_id: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `transaction_id` | `String` | Transaction ID to refund |

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func request_refund(transaction_id: String):
    iap.begin_refund_request_ios(transaction_id)

func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var refund_status = result.get("refundStatus", "")
        print("Refund status: ", refund_status)
```

---

### current_entitlement_ios

Get the current entitlement for a product.

```gdscript
func current_entitlement_ios(sku: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Product ID |

**Returns:** JSON string with status (result via signal)

---

### latest_transaction_ios

Get the latest transaction for a product.

```gdscript
func latest_transaction_ios(sku: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `sku` | `String` | Product ID |

**Returns:** JSON string with status (result via signal)

---

## Storefront

### get_storefront_ios

Get the user's storefront information (country/region).

```gdscript
func get_storefront_ios() -> String
```

**Returns:** JSON string with storefront info

```json
{
  "success": true,
  "countryCode": "US",
  "id": "143441"
}
```

**Example:**
```gdscript
func get_user_country():
    var result = JSON.parse_string(iap.get_storefront_ios())
    if result.get("success", false):
        return result.get("countryCode", "")
    return ""
```

---

## App Transaction

### get_app_transaction_ios

Get the app transaction (proof of purchase from App Store).

```gdscript
func get_app_transaction_ios() -> String
```

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func verify_app_purchase():
    iap.get_app_transaction_ios()

func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var jws = result.get("appTransactionJWS", "")
        # Send to server for verification
        await verify_on_server(jws)
```

---

## Promoted Products

### get_promoted_product_ios

Get the currently promoted product (from App Store promotional purchase).

```gdscript
func get_promoted_product_ios() -> String
```

**Returns:** JSON string with status (result via signal)

---

### request_purchase_on_promoted_product_ios

Complete a purchase for a promoted product.

```gdscript
func request_purchase_on_promoted_product_ios() -> String
```

**Returns:** JSON string with status

:::warning Deprecated
This method is deprecated. Use `promoted_product_ios` signal with `request_purchase` instead.
:::

**Example:**
```gdscript
func _setup_signals():
    iap.promoted_product_ios.connect(_on_promoted_product)

func _on_promoted_product(product_id: String):
    # User tapped a promoted product in App Store
    # You can show a confirmation dialog or proceed with purchase
    var params = {
        "sku": product_id,
        "ios": { "quantity": 1 }
    }
    iap.request_purchase(JSON.stringify(params))
```

---

## Receipt & Verification

### get_receipt_data_ios

Get the App Store receipt data.

```gdscript
func get_receipt_data_ios() -> String
```

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func get_receipt():
    iap.get_receipt_data_ios()

func _on_products_fetched(result: Dictionary):
    if result.get("success", false):
        var receipt_data = result.get("receiptData", "")
        # Send to server for verification
```

---

### is_transaction_verified_ios

Check if a transaction is verified.

```gdscript
func is_transaction_verified_ios(transaction_id: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `transaction_id` | `String` | Transaction ID |

**Returns:** JSON string with status (result via signal)

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

**Returns:** JSON string with status (result via signal)

---

## External Purchase APIs (iOS 18.2+)

These methods support external purchase flows for apps in eligible regions.

### can_present_external_purchase_notice_ios

Check if external purchase notice can be presented.

```gdscript
func can_present_external_purchase_notice_ios() -> String
```

**Returns:** JSON string with status (result via signal)

---

### present_external_purchase_notice_sheet_ios

Present the external purchase notice sheet to the user.

```gdscript
func present_external_purchase_notice_sheet_ios() -> String
```

**Returns:** JSON string with status (result via signal)

---

### present_external_purchase_link_ios

Present an external purchase link.

```gdscript
func present_external_purchase_link_ios(url: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `String` | External purchase URL |

**Returns:** JSON string with status (result via signal)

**Example:**
```gdscript
func open_external_purchase():
    # First check if we can present the notice
    iap.can_present_external_purchase_notice_ios()

func _on_products_fetched(result: Dictionary):
    if result.get("canPresent", false):
        # Present the notice first
        iap.present_external_purchase_notice_sheet_ios()

func _on_notice_accepted():
    # After user accepts, open external link
    iap.present_external_purchase_link_ios("https://your-store.com/purchase")
```

:::info Regional Availability
External purchase APIs are only available in regions where Apple allows external purchasing (e.g., EU under DMA).
:::
