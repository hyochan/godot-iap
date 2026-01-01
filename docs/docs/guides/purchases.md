---
title: Purchases
sidebar_label: Purchases
sidebar_position: 2
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Purchases

<IapKitBanner />

This guide covers the complete purchase flow for in-app purchases in Godot using the **type-safe API**.

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

const Types = preload("res://addons/godot-iap/types.gd")

@onready var iap = $GodotIapWrapper

var products: Array = []

func _ready():
    _setup_signals()
    _initialize()

func _setup_signals():
    # Core purchase signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.connected.connect(_on_connected)

func _initialize():
    if iap.init_connection():
        _load_products()

func _load_products():
    var request = Types.ProductRequest.new()
    var skus: Array[String] = ["coins_100", "coins_500", "remove_ads"]
    request.skus = skus
    request.type = Types.ProductQueryType.ALL

    # Returns Array of Types.ProductAndroid or Types.ProductIOS
    products = iap.fetch_products(request)
    for product in products:
        print("Product: ", product.id, " - ", product.display_price)

func _on_connected():
    print("Store connected")

func _on_products_fetched(result: Dictionary):
    # Handle async products fetch (iOS)
    if result.has("products"):
        for product_dict in result["products"]:
            print("Fetched: ", product_dict.get("id", ""))
```

### 2. Handle Purchase Updates

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    var product_id = purchase.get("productId", "")

    print("Purchase updated: ", product_id, " state: ", state)

    match state:
        "purchased", "Purchased":
            # Validate on server first
            var is_valid = await validate_on_server(purchase)

            if is_valid:
                # Grant the content
                grant_purchase(product_id)

                # Finish the transaction
                _finish_transaction(purchase)
            else:
                print("Purchase validation failed")

        "pending", "Pending":
            # Payment is pending (e.g., parental approval)
            print("Purchase pending: ", product_id)
            show_pending_message()

        _:
            print("Unknown purchase state: ", state)

func _finish_transaction(purchase: Dictionary):
    var is_consumable = is_consumable_product(purchase.get("productId", ""))
    var result = iap.finish_transaction_dict(purchase, is_consumable)
    if result.success:
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
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    # Returns typed purchase object or null
    var purchase = iap.request_purchase(props)

    if purchase:
        print("Purchase initiated for: ", purchase.product_id)
    # Purchase result comes via purchase_updated signal

func buy_subscription(subscription_id: String, offer_token: String = ""):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [subscription_id]
    props.request.google.skus = skus

    # Android: Add offer token if available
    if OS.get_name() == "Android" and offer_token != "":
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

## Platform Differences

### iOS

- Single SKU per purchase
- Uses typed `RequestPurchaseIOSProps`

```gdscript
func buy_ios(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id
    props.request.apple.quantity = 1  # Optional
    props.request.apple.app_account_token = "user-123"  # Optional

    iap.request_purchase(props)
```

### Android

- Supports multiple SKUs
- Subscriptions require offer token

```gdscript
func buy_android(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus
    props.request.google.obfuscated_account_id = "user-123"  # Optional
    props.request.google.obfuscated_profile_id = "profile-456"  # Optional

    iap.request_purchase(props)

func buy_android_subscription(subscription_id: String, subscription):
    # Get offer token from subscription details
    var offer_details = []
    if subscription is Object:
        offer_details = subscription.subscription_offer_details
    else:
        offer_details = subscription.get("subscriptionOfferDetailsAndroid", [])

    if offer_details.size() == 0:
        print("No subscription offers available")
        return

    var offer_token = offer_details[0].get("offerToken", "")

    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [subscription_id]
    props.request.google.skus = skus

    # Required for Android subscriptions
    var offers: Array[Types.SubscriptionOfferAndroid] = []
    var offer = Types.SubscriptionOfferAndroid.new()
    offer.sku = subscription_id
    offer.offer_token = offer_token
    offers.append(offer)
    props.request.google.subscription_offers = offers

    iap.request_purchase(props)
```

## Product Types

### Consumable Products

Consumable products can be purchased multiple times (e.g., coins, gems):

```gdscript
func buy_consumable(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    iap.request_purchase(props)

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    if state == "purchased" or state == "Purchased":
        # Grant consumable content
        add_coins(get_coin_amount(purchase.get("productId", "")))

        # Finish as consumable (allows repurchase)
        var result = iap.finish_transaction_dict(purchase, true)
        if result.success:
            print("Consumable purchase finished")
```

### Non-Consumable Products

Non-consumable products are purchased once (e.g., premium features):

```gdscript
func buy_non_consumable(product_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    iap.request_purchase(props)

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    if state == "purchased" or state == "Purchased":
        # Grant permanent content
        unlock_feature(purchase.get("productId", ""))

        # Finish as non-consumable
        var result = iap.finish_transaction_dict(purchase, false)
        if result.success:
            print("Non-consumable purchase finished")
```

### Subscriptions

Subscriptions require special handling, especially on Android:

```gdscript
func buy_subscription(subscription_id: String):
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = subscription_id

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [subscription_id]
    props.request.google.skus = skus

    if OS.get_name() == "Android":
        # Find the subscription details
        var subscription = find_subscription(subscription_id)
        if not subscription:
            print("Subscription not found")
            return

        var offer_details = []
        if subscription is Object:
            offer_details = subscription.subscription_offer_details
        else:
            offer_details = subscription.get("subscriptionOfferDetailsAndroid", [])

        if offer_details.size() == 0:
            print("No subscription offers available")
            return

        var offers: Array[Types.SubscriptionOfferAndroid] = []
        var offer = Types.SubscriptionOfferAndroid.new()
        offer.sku = subscription_id
        offer.offer_token = offer_details[0].get("offerToken", "")
        offers.append(offer)
        props.request.google.subscription_offers = offers

    iap.request_purchase(props)
```

## Getting Product Information

### Display Products

```gdscript
func display_products():
    for product in products:
        # Access typed properties
        var title = product.title if product is Object else product.get("title", "")
        var price = product.display_price if product is Object else product.get("displayPrice", "")
        var description = product.description if product is Object else product.get("description", "")

        print("Title: ", title)
        print("Price: ", price)
        print("Description: ", description)
        print("---")

func get_product_price(product_id: String) -> String:
    for product in products:
        var id = product.id if product is Object else product.get("id", "")
        if id == product_id:
            return product.display_price if product is Object else product.get("displayPrice", "$0.99")
    return "$0.99"  # Default price
```

## Purchase Restoration

Implement purchase restoration for non-consumable products and subscriptions:

```gdscript
func restore_purchases():
    # Returns Array of typed purchase objects
    var purchases = iap.get_available_purchases()

    if purchases.size() == 0:
        show_message("No purchases to restore")
        return

    var restored_count = 0

    for purchase in purchases:
        var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")

        # Validate on server
        var is_valid = await validate_on_server_typed(purchase)

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
        "productId": purchase.get("productId", ""),
        "purchaseToken": purchase.get("purchaseToken", ""),
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
    var props = Types.VerifyPurchaseProps.new()

    if OS.get_name() == "iOS":
        props.apple = Types.VerifyPurchasePropsIOS.new()
        props.apple.sku = purchase.get("productId", "")
    elif OS.get_name() == "Android":
        props.google = Types.VerifyPurchasePropsAndroid.new()
        props.google.sku = purchase.get("productId", "")
        props.google.package_name = ProjectSettings.get_setting("application/config/package_name")
        props.google.purchase_token = purchase.get("purchaseToken", "")
        props.google.access_token = await get_google_access_token()
        props.google.is_sub = purchase.get("type", "") == "subs"

    var result = iap.verify_purchase(props)
    return result != null and result.is_valid
```

## Handling Pending Purchases

Some purchases may be in a pending state (e.g., awaiting parental approval):

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "pending" or state == "Pending":
        # Inform user that purchase is pending
        show_pending_ui(purchase.get("productId", ""))

        # Store pending purchase for later checking
        save_pending_purchase(purchase)
        return

    if state == "purchased" or state == "Purchased":
        # Check if this was a previously pending purchase
        clear_pending_purchase(purchase.get("productId", ""))

        # Process normally
        await process_purchase(purchase)
```

## Subscription Status

### Checking Subscription Status

```gdscript
func is_subscription_active(purchase) -> bool:
    var current_time = Time.get_unix_time_from_system() * 1000  # ms

    if OS.get_name() == "iOS":
        var expiration = 0
        if purchase is Object:
            expiration = purchase.expiration_date if "expiration_date" in purchase else 0
        else:
            expiration = purchase.get("expirationDateIOS", 0)

        if expiration > 0:
            return expiration > current_time

        # For Sandbox, consider recent purchases as active
        var environment = ""
        var transaction_date = 0
        if purchase is Object:
            environment = purchase.environment if "environment" in purchase else ""
            transaction_date = purchase.transaction_date if "transaction_date" in purchase else 0
        else:
            environment = purchase.get("environmentIOS", "")
            transaction_date = purchase.get("transactionDate", 0)

        if environment == "Sandbox":
            var day_in_ms = 24 * 60 * 60 * 1000
            return (current_time - transaction_date) < day_in_ms

    elif OS.get_name() == "Android":
        # Check auto-renewal status
        var auto_renewing = null
        if purchase is Object:
            auto_renewing = purchase.auto_renewing if "auto_renewing" in purchase else null
        else:
            auto_renewing = purchase.get("autoRenewingAndroid", null)

        if auto_renewing != null:
            return auto_renewing

        # Check purchase state
        var purchase_state = ""
        if purchase is Object:
            purchase_state = purchase.purchase_state if "purchase_state" in purchase else ""
        else:
            purchase_state = purchase.get("purchaseState", "")

        if purchase_state == "purchased" or purchase_state == "Purchased":
            return true

    return false
```

### Managing Subscriptions

```gdscript
func open_subscription_management():
    var options = Types.DeepLinkOptions.new()

    if OS.get_name() == "Android":
        options.package_name_android = ProjectSettings.get_setting(
            "application/config/package_name"
        )
        options.sku_android = "premium_monthly"  # Optional

    iap.deep_link_to_subscriptions(options)
```

## Handling Unfinished Transactions

Check for unfinished transactions on app startup:

```gdscript
func _ready():
    _setup_signals()
    _initialize()

func _initialize():
    if iap.init_connection():
        # Check for pending purchases first
        _check_pending_purchases()
        # Then load products
        _load_products()

func _check_pending_purchases():
    var purchases = iap.get_available_purchases()

    for purchase in purchases:
        var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")

        # Check if already processed
        if await is_already_processed(purchase):
            # Finish the transaction
            var is_consumable = is_consumable_product(product_id)
            if purchase is Object:
                var input = Types.PurchaseInput.new()
                input.product_id = product_id
                input.purchase_token = purchase.purchase_token if "purchase_token" in purchase else ""
                iap.finish_transaction(input, is_consumable)
            else:
                iap.finish_transaction_dict(purchase, is_consumable)
        else:
            # Process the purchase
            await process_purchase(purchase)
```

## Complete Example

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

@onready var iap = $GodotIapWrapper

var products: Array = []
var subscriptions: Array = []
var is_connected: bool = false

# Product IDs
const COINS_100 = "coins_100"
const COINS_500 = "coins_500"
const REMOVE_ADS = "remove_ads"
const PREMIUM_MONTHLY = "premium_monthly"

func _ready():
    _setup_signals()
    _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.connected.connect(_on_connected)

func _initialize():
    is_connected = iap.init_connection()
    if is_connected:
        _check_pending_purchases()
        _load_products()

func _on_connected():
    is_connected = true

func _check_pending_purchases():
    var purchases = iap.get_available_purchases()
    for purchase in purchases:
        await _process_purchase_typed(purchase)

func _load_products():
    var request = Types.ProductRequest.new()
    var skus: Array[String] = [COINS_100, COINS_500, REMOVE_ADS, PREMIUM_MONTHLY]
    request.skus = skus
    request.type = Types.ProductQueryType.ALL

    products = iap.fetch_products(request)
    _update_store_ui()

func _on_products_fetched(result: Dictionary):
    # Handle async products fetch (iOS)
    if result.has("products"):
        for product_dict in result["products"]:
            print("Fetched: ", product_dict.get("id", ""))
    _update_store_ui()

func _on_purchase_updated(purchase: Dictionary):
    await _process_purchase(purchase)

func _process_purchase(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "pending" or state == "Pending":
        _show_pending_message(purchase.get("productId", ""))
        return

    if state == "purchased" or state == "Purchased":
        # Verify on server
        var is_valid = await _validate_on_server(purchase)

        if is_valid:
            # Grant content
            _grant_purchase(purchase.get("productId", ""))

            # Finish transaction
            var is_consumable = purchase.get("productId", "") in [COINS_100, COINS_500]
            var result = iap.finish_transaction_dict(purchase, is_consumable)
            if result.success:
                print("Transaction finished")
        else:
            print("Purchase validation failed")

func _process_purchase_typed(purchase) -> void:
    var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")
    var state = ""
    if purchase is Object:
        state = purchase.purchase_state if "purchase_state" in purchase else ""
    else:
        state = purchase.get("purchaseState", "")

    if state == "purchased" or state == "Purchased":
        _grant_purchase(product_id)

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

    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.IN_APP

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = product_id

    iap.request_purchase(props)

func buy_subscription(subscription_id: String):
    if not is_connected:
        _show_error("Store not connected")
        return

    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [subscription_id]
    props.request.google.skus = skus

    props.request.apple = Types.RequestPurchaseIOSProps.new()
    props.request.apple.sku = subscription_id

    if OS.get_name() == "Android":
        var sub = _find_subscription(subscription_id)
        if sub:
            var offers = sub.subscription_offer_details if sub is Object else sub.get("subscriptionOfferDetailsAndroid", [])
            if offers.size() > 0:
                var sub_offers: Array[Types.SubscriptionOfferAndroid] = []
                var offer = Types.SubscriptionOfferAndroid.new()
                offer.sku = subscription_id
                offer.offer_token = offers[0].get("offerToken", offers[0].offerToken if offers[0] is Object else "")
                sub_offers.append(offer)
                props.request.google.subscription_offers = sub_offers

    iap.request_purchase(props)

func restore():
    _restore_purchases()

# Helper functions
func _find_subscription(subscription_id: String):
    for sub in subscriptions:
        var id = sub.id if sub is Object else sub.get("id", "")
        if id == subscription_id:
            return sub
    return null

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
    var purchases = iap.get_available_purchases()
    for purchase in purchases:
        await _process_purchase_typed(purchase)

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
