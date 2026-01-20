---
title: Signals (Listeners)
sidebar_label: Signals
sidebar_position: 5
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Signals (Listeners)

<IapKitBanner />

GodotIap provides signals to handle purchase updates and errors. These signals are essential for handling the asynchronous nature of in-app purchases.

## purchase_updated

Emitted when a purchase is successfully completed or updated.

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.purchase_updated.connect(_on_purchase_updated)

func _on_purchase_updated(purchase: Dictionary):
    print("Purchase received:", purchase)

    var state = purchase.get("purchaseState", "")
    var product_id = purchase.productId

    match state:
        "purchased":
            # Validate receipt on your server
            var is_valid = await validate_receipt_on_server(purchase)

            if is_valid:
                # Grant purchase to user
                grant_purchase_to_user(purchase)

                # Finish the transaction
                finish_purchase(purchase)

                print("Purchase completed successfully")
            else:
                print("Purchase verification failed")

        "pending":
            print("Purchase pending approval")

        _:
            print("Unknown purchase state: ", state)
```

**Signal Parameters:**

- `purchase` (Dictionary): The purchase object containing:
  - `productId` (String): Product identifier
  - `transactionId` (String): Transaction identifier
  - `purchaseToken` (String): Token for verification
  - `purchaseState` (String): `"purchased"`, `"pending"`, or `"unspecified"`
  - Platform-specific fields (see [Purchase Interface](./unified-apis#purchase-interface))

---

## purchase_error

Emitted when a purchase error occurs.

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.purchase_error.connect(_on_purchase_error)

func _on_purchase_error(error: Dictionary):
    print("Purchase error:", error)

    var code = error.get("code", "")
    var message = error.get("message", "")

    match code:
        "USER_CANCELED":
            # User cancelled the purchase - don't show error
            print("Purchase cancelled by user")

        "NETWORK_ERROR":
            show_error_message("Network error. Please check your connection.")

        "ITEM_UNAVAILABLE":
            show_error_message("This product is currently unavailable.")

        "ITEM_ALREADY_OWNED":
            # User already owns this product - restore it
            show_error_message("You already own this product.")
            restore_purchases()

        "PAYMENT_INVALID":
            show_error_message("Payment was invalid. Please try again.")

        "PAYMENT_NOT_ALLOWED":
            show_error_message("Payments are not allowed on this device.")

        _:
            show_error_message("Purchase failed: " + message)
```

**Signal Parameters:**

- `error` (Dictionary): The error object containing:
  - `code` (String): Error code
  - `message` (String): Human-readable error message
  - `domain` (String): Error domain (iOS only)

**Common Error Codes:**

| Code | Description |
|------|-------------|
| `USER_CANCELED` | User cancelled the purchase |
| `NETWORK_ERROR` | Network connection error |
| `ITEM_UNAVAILABLE` | Product not available |
| `ITEM_ALREADY_OWNED` | User already owns this non-consumable |
| `ITEM_NOT_OWNED` | Item not owned (for consume/acknowledge) |
| `PAYMENT_INVALID` | Payment information is invalid |
| `PAYMENT_NOT_ALLOWED` | Payments disabled on device |
| `BILLING_UNAVAILABLE` | Billing service unavailable |

---

## products_fetched

Emitted when products are successfully fetched.

```gdscript
var products: Array = []

func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.products_fetched.connect(_on_products_fetched)

        # Fetch products
        var product_ids = ["coins_100", "coins_500"]
        iap.fetch_products(JSON.stringify(product_ids), "inapp")

func _on_products_fetched(fetched_products: Array):
    products = fetched_products

    for product in products:
        print("Product: ", product.productId)
        print("Title: ", product.title)
        print("Price: ", product.localizedPrice)
        print("---")

    update_store_ui()
```

**Signal Parameters:**

- `products` (Array): Array of product dictionaries

---

## subscriptions_fetched

Emitted when subscriptions are successfully fetched.

```gdscript
var subscriptions: Array = []

func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

        # Fetch subscriptions
        var sub_ids = ["premium_monthly", "premium_yearly"]
        iap.fetch_subscriptions(JSON.stringify(sub_ids))

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs

    for sub in subscriptions:
        print("Subscription: ", sub.productId)
        print("Price: ", sub.localizedPrice)
```

**Signal Parameters:**

- `subscriptions` (Array): Array of subscription dictionaries

---

## iOS-Specific Signals

### promoted_product_ios

Emitted when a user initiates a promoted product purchase from the App Store.

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.promoted_product_ios.connect(_on_promoted_product)

func _on_promoted_product(product_id: String):
    print("Promoted product purchase initiated: ", product_id)

    # Show your custom purchase confirmation UI
    var confirmed = await show_product_confirmation(product_id)

    if confirmed:
        # Complete the promoted purchase
        iap.request_purchase_on_promoted_product_ios()
```

**Signal Parameters:**

- `product_id` (String): The product ID of the promoted product

**Related Methods:**

- `get_promoted_product_ios()`: Get the promoted product details
- `request_purchase_on_promoted_product_ios()`: Complete the promoted product purchase

:::note
This signal only fires on iOS devices when a user taps on a promoted product in the App Store.
:::

---

### subscription_status_changed_ios

Emitted when a subscription status changes (iOS only).

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.subscription_status_changed_ios.connect(_on_subscription_status_changed)

func _on_subscription_status_changed(status: Dictionary):
    print("Subscription status changed")
    print("Product ID: ", status.productId)
    print("State: ", status.state)

    match status.state:
        "subscribed":
            grant_premium_access()
        "expired":
            revoke_premium_access()
        "inBillingRetryPeriod":
            show_billing_issue_banner()
        "inGracePeriod":
            show_grace_period_banner()
```

---

## Android-Specific Signals

### user_choice_billing_android

Emitted when user chooses alternative billing in the User Choice Billing dialog (Android only).

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.user_choice_billing_android.connect(_on_user_choice_billing)

func _on_user_choice_billing(data: Dictionary):
    print("User selected alternative billing")
    print("Token: ", data.externalTransactionToken)
    print("Products: ", data.products)

    # Process payment in your payment system
    var payment_result = await process_external_payment(data.products)

    if payment_result.success:
        # Report token to Google Play within 24 hours
        await report_token_to_google(data.externalTransactionToken)
```

**Signal Parameters:**

- `data` (Dictionary):
  - `externalTransactionToken` (String): Token to report to Google
  - `products` (Array): List of product IDs

:::warning Important
The `externalTransactionToken` must be reported to Google Play backend within 24 hours.
:::

---

### developer_provided_billing_android

Emitted when user selects developer billing option in External Payments flow (Android only, Japan).

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        iap.developer_provided_billing_android.connect(_on_developer_billing)

func _on_developer_billing(data: Dictionary):
    print("User selected developer billing")
    print("Token: ", data.externalTransactionToken)

    # Process payment with your gateway
    var payment_result = await process_payment_with_gateway(
        data.externalTransactionToken
    )

    if payment_result.success:
        # Report to Google Play within 24 hours
        await report_external_transaction_to_google(
            data.externalTransactionToken
        )
```

**Signal Parameters:**

- `data` (Dictionary):
  - `externalTransactionToken` (String): Token to report to Google

**Requirements:**

- Google Play Billing Library 8.3.0+
- Only available in Japan

---

## Setting Up All Signals

Here's a complete example of setting up all purchase signals:

```gdscript
extends Node

var iap: GodotIap
var products: Array = []
var subscriptions: Array = []

func _ready():
    if not Engine.has_singleton("GodotIap"):
        print("GodotIap not available")
        return

    iap = Engine.get_singleton("GodotIap")
    _setup_signals()
    _initialize()

func _setup_signals():
    # Core signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

    # iOS-specific signals
    if OS.get_name() == "iOS":
        iap.promoted_product_ios.connect(_on_promoted_product)
        iap.subscription_status_changed_ios.connect(_on_subscription_status_changed)

    # Android-specific signals
    if OS.get_name() == "Android":
        iap.user_choice_billing_android.connect(_on_user_choice_billing)
        iap.developer_provided_billing_android.connect(_on_developer_billing)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        _load_products()

func _load_products():
    var product_ids = ["coins_100", "remove_ads"]
    iap.fetch_products(JSON.stringify(product_ids), "inapp")

    var sub_ids = ["premium_monthly"]
    iap.fetch_subscriptions(JSON.stringify(sub_ids))

# Core signal handlers
func _on_purchase_updated(purchase: Dictionary):
    print("Purchase updated: ", purchase.productId)
    await handle_purchase(purchase)

func _on_purchase_error(error: Dictionary):
    print("Purchase error: ", error.code)
    handle_error(error)

func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    update_product_ui()

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs
    update_subscription_ui()

# iOS signal handlers
func _on_promoted_product(product_id: String):
    print("Promoted product: ", product_id)

func _on_subscription_status_changed(status: Dictionary):
    print("Subscription status: ", status.state)

# Android signal handlers
func _on_user_choice_billing(data: Dictionary):
    print("User choice billing")

func _on_developer_billing(data: Dictionary):
    print("Developer billing")

# Helper functions
func handle_purchase(purchase: Dictionary):
    var verified = await verify_on_server(purchase)
    if verified:
        grant_purchase(purchase.productId)
        finish_transaction(purchase)

func handle_error(error: Dictionary):
    if error.code != "USER_CANCELED":
        show_error(error.message)
```

---

## Signal Lifecycle Notes

### 1. Set up early
Set up signals as early as possible in your app lifecycle to catch any pending purchases.

### 2. Clean up properly
Signals in Godot are automatically cleaned up when the node is freed, but you can manually disconnect if needed:

```gdscript
func _exit_tree():
    if iap:
        iap.purchase_updated.disconnect(_on_purchase_updated)
        iap.purchase_error.disconnect(_on_purchase_error)
```

### 3. Handle app states
Purchases can complete when your app is in the background. Always handle the `purchase_updated` signal to process any pending purchases when the app resumes.

### 4. Purchase States

Purchases can be in different states:

| State | Description |
|-------|-------------|
| `purchased` | Successfully completed |
| `pending` | Awaiting approval (e.g., parental approval) |
| `unspecified` | Unknown state |

Handle each state appropriately in your purchase signal handler.
