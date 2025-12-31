---
title: Purchases
sidebar_label: Purchases
sidebar_position: 2
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Purchases

<IapKitBanner />

This guide covers the complete purchase flow for in-app purchases in Godot using GodotIap.

:::warning Purchase Flow Design
The purchase flow uses an **event pattern** rather than a callback pattern:

1. Multiple responses may occur when requesting a payment
2. Purchases are inter-session **asynchronous** - requests may complete after the app is closed
3. Purchases may be pending and hard to track
4. Always use signals to handle purchase results
:::

For a comprehensive understanding of the purchase lifecycle, see our [Lifecycle Guide](./lifecycle).

## Purchase Flow Overview

Once you have called `fetch_products()` and have a valid response, you can call `request_purchase()`. Subscribable products can be purchased just like consumable products.

Before you request any purchase, you should connect to the purchase signals. It is recommended to start listening to updates as soon as your application launches.

### Key Concepts

1. **Event-driven**: Purchases are handled through signals rather than return values
2. **Asynchronous**: Purchases may complete after your app is closed or crashed
3. **Validation required**: Always validate purchases on your server
4. **Finish transactions**: Always finish transactions after processing

## Basic Purchase Flow

### 1. Setup Purchase Signals

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
    # Core purchase signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        _load_products()

func _load_products():
    var product_ids = ["coins_100", "coins_500", "remove_ads"]
    iap.fetch_products(JSON.stringify(product_ids), "inapp")

func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    for product in products:
        print("Product: ", product.productId, " - ", product.localizedPrice)
```

### 2. Handle Purchase Updates

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    var product_id = purchase.productId

    print("Purchase updated: ", product_id, " state: ", state)

    match state:
        "purchased":
            # Validate on server first
            var is_valid = await validate_on_server(purchase)

            if is_valid:
                # Grant the content
                grant_purchase(product_id)

                # Finish the transaction
                _finish_transaction(purchase)
            else:
                print("Purchase validation failed")

        "pending":
            # Payment is pending (e.g., parental approval)
            print("Purchase pending: ", product_id)
            show_pending_message()

        _:
            print("Unknown purchase state: ", state)

func _finish_transaction(purchase: Dictionary):
    var params = {
        "purchase": purchase,
        "isConsumable": is_consumable(purchase.productId)
    }
    var result = JSON.parse_string(iap.finish_transaction(JSON.stringify(params)))
    if result.get("success", false):
        print("Transaction finished")
```

### 3. Handle Purchase Errors

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "")

    match code:
        "USER_CANCELED":
            # User cancelled - no action needed
            print("Purchase cancelled by user")

        "NETWORK_ERROR":
            show_error("Network error. Please check your connection.")

        "ITEM_UNAVAILABLE":
            show_error("This product is currently unavailable.")

        "ITEM_ALREADY_OWNED":
            # User already owns this product - restore it
            show_error("You already own this product.")
            restore_purchases()

        "PAYMENT_INVALID":
            show_error("Payment was invalid. Please try again.")

        "PAYMENT_NOT_ALLOWED":
            show_error("Payments are not allowed on this device.")

        _:
            show_error("Purchase failed: " + message)
```

### 4. Request a Purchase

```gdscript
func buy_product(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp"
    }
    var result = JSON.parse_string(iap.request_purchase(JSON.stringify(params)))

    if result.get("success", false):
        print("Purchase initiated for: ", product_id)
    else:
        print("Failed to initiate purchase: ", result.get("error", ""))

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

## Platform Differences

### iOS

- Single SKU per purchase
- Uses `sku` parameter

```gdscript
func buy_ios(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp",
        "quantity": 1,  # Optional
        "appAccountToken": "user-123"  # Optional
    }
    iap.request_purchase(JSON.stringify(params))
```

### Android

- Supports multiple SKUs
- Subscriptions require `offerToken`

```gdscript
func buy_android(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp",
        "obfuscatedAccountId": "user-123",  # Optional
        "obfuscatedProfileId": "profile-456"  # Optional
    }
    iap.request_purchase(JSON.stringify(params))

func buy_android_subscription(subscription_id: String, subscription: Dictionary):
    # Get offer token from subscription details
    var offer_details = subscription.get("subscriptionOfferDetailsAndroid", [])
    if offer_details.size() == 0:
        print("No subscription offers available")
        return

    var offer_token = offer_details[0].get("offerToken", "")

    var params = {
        "sku": subscription_id,
        "type": "subs",
        "offerToken": offer_token  # Required for Android subscriptions
    }
    iap.request_purchase(JSON.stringify(params))
```

## Product Types

### Consumable Products

Consumable products can be purchased multiple times (e.g., coins, gems):

```gdscript
func buy_consumable(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp"
    }
    iap.request_purchase(JSON.stringify(params))

func _on_purchase_updated(purchase: Dictionary):
    if purchase.purchaseState == "purchased":
        # Grant consumable content
        add_coins(get_coin_amount(purchase.productId))

        # Finish as consumable (allows repurchase)
        var params = {
            "purchase": purchase,
            "isConsumable": true
        }
        iap.finish_transaction(JSON.stringify(params))
```

### Non-Consumable Products

Non-consumable products are purchased once (e.g., premium features):

```gdscript
func buy_non_consumable(product_id: String):
    var params = {
        "sku": product_id,
        "type": "inapp"
    }
    iap.request_purchase(JSON.stringify(params))

func _on_purchase_updated(purchase: Dictionary):
    if purchase.purchaseState == "purchased":
        # Grant permanent content
        unlock_feature(purchase.productId)

        # Finish as non-consumable
        var params = {
            "purchase": purchase,
            "isConsumable": false
        }
        iap.finish_transaction(JSON.stringify(params))
```

### Subscriptions

Subscriptions require special handling, especially on Android:

```gdscript
func buy_subscription(subscription_id: String):
    if OS.get_name() == "iOS":
        var params = {
            "sku": subscription_id,
            "type": "subs"
        }
        iap.request_purchase(JSON.stringify(params))

    elif OS.get_name() == "Android":
        # Find the subscription details
        var subscription = find_subscription(subscription_id)
        if not subscription:
            print("Subscription not found")
            return

        var offer_details = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offer_details.size() == 0:
            print("No subscription offers available")
            return

        var params = {
            "sku": subscription_id,
            "type": "subs",
            "offerToken": offer_details[0].offerToken
        }
        iap.request_purchase(JSON.stringify(params))
```

## Getting Product Information

### Display Products

```gdscript
func display_products():
    for product in products:
        var title = product.get("title", "")
        var price = product.get("localizedPrice", "")
        var description = product.get("description", "")

        print("Title: ", title)
        print("Price: ", price)
        print("Description: ", description)
        print("---")

func get_product_price(product_id: String) -> String:
    for product in products:
        if product.productId == product_id:
            return product.get("localizedPrice", "$0.99")
    return "$0.99"  # Default price
```

### Platform-Specific Pricing

```gdscript
func get_product_price_detailed(product_id: String) -> String:
    for product in products:
        if product.productId != product_id:
            continue

        if OS.get_name() == "iOS":
            return product.get("displayPrice", "$0.99")

        elif OS.get_name() == "Android":
            var offer = product.get("oneTimePurchaseOfferDetails", {})
            return offer.get("formattedPrice", "$0.99")

    return "$0.99"

func get_subscription_price(subscription_id: String) -> String:
    for sub in subscriptions:
        if sub.productId != subscription_id:
            continue

        if OS.get_name() == "iOS":
            return sub.get("displayPrice", "$9.99")

        elif OS.get_name() == "Android":
            var offers = sub.get("subscriptionOfferDetailsAndroid", [])
            if offers.size() > 0:
                var phases = offers[0].get("pricingPhases", {})
                var phase_list = phases.get("pricingPhaseList", [])
                if phase_list.size() > 0:
                    return phase_list[0].get("formattedPrice", "$9.99")

    return "$9.99"
```

## Purchase Restoration

Implement purchase restoration for non-consumable products and subscriptions:

```gdscript
func restore_purchases():
    var purchases_json = iap.get_available_purchases()
    var purchases = JSON.parse_string(purchases_json)

    if purchases.size() == 0:
        show_message("No purchases to restore")
        return

    var restored_count = 0

    for purchase in purchases:
        var product_id = purchase.productId

        # Validate on server
        var is_valid = await validate_on_server(purchase)

        if is_valid:
            # Grant the content
            grant_purchase(product_id)
            restored_count += 1

    if restored_count > 0:
        show_message("Restored %d purchases" % restored_count)
    else:
        show_message("No valid purchases found")
```

## Purchase Verification

:::warning Production Requirement
Always validate purchases on a secure server for production apps. Client-side verification can be tampered with.
:::

### Server-Side Verification

```gdscript
func validate_on_server(purchase: Dictionary) -> bool:
    var http_request = HTTPRequest.new()
    add_child(http_request)

    var body = JSON.stringify({
        "productId": purchase.productId,
        "purchaseToken": purchase.purchaseToken,
        "platform": OS.get_name().to_lower()
    })

    var headers = ["Content-Type: application/json"]
    var error = http_request.request(
        "https://your-server.com/validate",
        headers,
        HTTPClient.METHOD_POST,
        body
    )

    if error != OK:
        http_request.queue_free()
        return false

    var result = await http_request.request_completed
    http_request.queue_free()

    var response_code = result[1]
    var response_body = result[3].get_string_from_utf8()

    if response_code == 200:
        var data = JSON.parse_string(response_body)
        return data.get("valid", false)

    return false
```

### Using Native Verification

```gdscript
func verify_purchase_native(purchase: Dictionary) -> bool:
    var options = {}

    if OS.get_name() == "iOS":
        options["apple"] = {
            "sku": purchase.productId
        }
    elif OS.get_name() == "Android":
        options["google"] = {
            "sku": purchase.productId,
            "packageName": ProjectSettings.get_setting("application/config/package_name"),
            "purchaseToken": purchase.purchaseToken,
            "accessToken": await get_google_access_token(),
            "isSub": purchase.get("type") == "subs"
        }

    var result_json = iap.verify_purchase(JSON.stringify(options))
    var result = JSON.parse_string(result_json)

    return result.get("isValid", false)
```

## Handling Pending Purchases

Some purchases may be in a pending state (e.g., awaiting parental approval):

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "pending":
        # Inform user that purchase is pending
        show_pending_ui(purchase.productId)

        # Store pending purchase for later checking
        save_pending_purchase(purchase)
        return

    if state == "purchased":
        # Check if this was a previously pending purchase
        clear_pending_purchase(purchase.productId)

        # Process normally
        await process_purchase(purchase)
```

## Subscription Status

### Checking Subscription Status

```gdscript
func is_subscription_active(purchase: Dictionary) -> bool:
    var current_time = Time.get_unix_time_from_system() * 1000  # ms

    if OS.get_name() == "iOS":
        var expiration = purchase.get("expirationDateIOS", 0)
        if expiration > 0:
            return expiration > current_time

        # For Sandbox, consider recent purchases as active
        if purchase.get("environmentIOS") == "Sandbox":
            var day_in_ms = 24 * 60 * 60 * 1000
            var transaction_date = purchase.get("transactionDate", 0)
            return (current_time - transaction_date) < day_in_ms

    elif OS.get_name() == "Android":
        # Check auto-renewal status
        var auto_renewing = purchase.get("autoRenewingAndroid", false)
        if auto_renewing != null:
            return auto_renewing

        # Check purchase state
        if purchase.get("purchaseState") == "purchased":
            return true

    return false
```

### Managing Subscriptions

```gdscript
func open_subscription_management():
    var options = {}

    if OS.get_name() == "Android":
        options["packageNameAndroid"] = ProjectSettings.get_setting(
            "application/config/package_name"
        )
        options["skuAndroid"] = "premium_monthly"  # Optional

    iap.deep_link_to_subscriptions(JSON.stringify(options))
```

## Handling Unfinished Transactions

Check for unfinished transactions on app startup:

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        # Check for pending purchases first
        _check_pending_purchases()
        # Then load products
        _load_products()

func _check_pending_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        # Check if already processed
        if await is_already_processed(purchase):
            # Finish the transaction
            var params = {
                "purchase": purchase,
                "isConsumable": is_consumable(purchase.productId)
            }
            iap.finish_transaction(JSON.stringify(params))
        else:
            # Process the purchase
            await process_purchase(purchase)
```

## Complete Example

```gdscript
extends Node

var iap: GodotIap
var products: Array = []
var subscriptions: Array = []
var is_connected: bool = false

# Product IDs
const COINS_100 = "coins_100"
const COINS_500 = "coins_500"
const REMOVE_ADS = "remove_ads"
const PREMIUM_MONTHLY = "premium_monthly"

func _ready():
    if not Engine.has_singleton("GodotIap"):
        print("GodotIap not available")
        return

    iap = Engine.get_singleton("GodotIap")
    _setup_signals()
    _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        is_connected = true
        _check_pending_purchases()
        _load_products()
    else:
        print("Failed to connect: ", result.get("error", ""))

func _check_pending_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())
    for purchase in purchases:
        await _process_purchase(purchase)

func _load_products():
    var product_ids = [COINS_100, COINS_500, REMOVE_ADS]
    iap.fetch_products(JSON.stringify(product_ids), "inapp")

    var sub_ids = [PREMIUM_MONTHLY]
    iap.fetch_subscriptions(JSON.stringify(sub_ids))

func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    _update_store_ui()

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs
    _update_store_ui()

func _on_purchase_updated(purchase: Dictionary):
    await _process_purchase(purchase)

func _process_purchase(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "pending":
        _show_pending_message(purchase.productId)
        return

    if state == "purchased":
        # Verify on server
        var is_valid = await _validate_on_server(purchase)

        if is_valid:
            # Grant content
            _grant_purchase(purchase.productId)

            # Finish transaction
            var is_consumable = purchase.productId in [COINS_100, COINS_500]
            var params = {
                "purchase": purchase,
                "isConsumable": is_consumable
            }
            iap.finish_transaction(JSON.stringify(params))
        else:
            print("Purchase validation failed")

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    match code:
        "USER_CANCELED":
            pass  # Silent
        "ITEM_ALREADY_OWNED":
            _restore_purchases()
        _:
            _show_error(error.get("message", "Purchase failed"))

# Public API
func buy(product_id: String):
    if not is_connected:
        _show_error("Store not connected")
        return

    var params = {"sku": product_id, "type": "inapp"}
    iap.request_purchase(JSON.stringify(params))

func buy_subscription(subscription_id: String):
    if not is_connected:
        _show_error("Store not connected")
        return

    var params = {"sku": subscription_id, "type": "subs"}

    if OS.get_name() == "Android":
        var sub = _find_subscription(subscription_id)
        if sub:
            var offers = sub.get("subscriptionOfferDetailsAndroid", [])
            if offers.size() > 0:
                params["offerToken"] = offers[0].offerToken

    iap.request_purchase(JSON.stringify(params))

func restore():
    _restore_purchases()

# Helper functions
func _find_subscription(subscription_id: String) -> Dictionary:
    for sub in subscriptions:
        if sub.productId == subscription_id:
            return sub
    return {}

func _validate_on_server(purchase: Dictionary) -> bool:
    # Implement server validation
    return true

func _grant_purchase(product_id: String):
    match product_id:
        COINS_100:
            GameState.add_coins(100)
        COINS_500:
            GameState.add_coins(500)
        REMOVE_ADS:
            GameState.set_ads_removed(true)
        PREMIUM_MONTHLY:
            GameState.set_premium(true)

func _restore_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())
    for purchase in purchases:
        await _process_purchase(purchase)

func _update_store_ui():
    # Update your store UI
    pass

func _show_pending_message(product_id: String):
    # Show pending UI
    pass

func _show_error(message: String):
    # Show error dialog
    pass
```

## Testing Purchases

### iOS Testing

1. Create sandbox accounts in App Store Connect
2. Sign out of App Store on device
3. Sign in with sandbox account when prompted during purchase
4. Test with TestFlight builds

### Android Testing

1. Create test accounts in Google Play Console
2. Upload signed APK to internal testing track
3. Add test accounts to the testing track
4. Test with signed builds (not debug builds)

## Next Steps

- [Lifecycle Guide](./lifecycle) for connection management
- [Subscription Offers](./subscription-offers) for promotional pricing
- [Error Handling Guide](./error-handling) for debugging
- [API Reference](../api/) for detailed method documentation
