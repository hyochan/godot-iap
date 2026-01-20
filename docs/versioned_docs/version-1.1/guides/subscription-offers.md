---
title: Subscription Offers
sidebar_label: Subscription Offers
sidebar_position: 4
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Subscription Offers

<IapKitBanner />

This guide explains how to work with subscription offers using the OpenIAP typed API. Subscription offers include introductory pricing, free trials, and promotional discounts available on both iOS and Android platforms.

## Overview

godot-iap provides cross-platform `SubscriptionOffer` and `DiscountOffer` types that normalize the differences between iOS and Android offer systems:

```gdscript
const Types = preload("res://addons/godot-iap/types.gd")

# Cross-platform SubscriptionOffer type
class SubscriptionOffer:
    var id: String
    var display_price: String
    var price: float
    var currency: String
    var type: DiscountOfferType          # INTRODUCTORY, PROMOTIONAL
    var period: SubscriptionPeriod       # Duration of offer period
    var period_count: int                # Number of periods
    var payment_mode: PaymentMode        # FREE_TRIAL, PAY_AS_YOU_GO, PAY_UP_FRONT
    var key_identifier_ios: String       # iOS promotional offer key
    var base_plan_id_android: String     # Android base plan ID
    var offer_token_android: String      # Android offer token (required for purchase)
```

## Offer Types

### DiscountOfferType Enum

```gdscript
enum DiscountOfferType {
    INTRODUCTORY = 0,  # First-time subscriber offers (free trials, intro pricing)
    PROMOTIONAL = 1,   # Limited-time promotional discounts
    ONE_TIME = 2       # One-time discount (for consumables/non-consumables)
}
```

### PaymentMode Enum

```gdscript
enum PaymentMode {
    FREE_TRIAL = 0,     # No charge during offer period
    PAY_AS_YOU_GO = 1,  # Discounted recurring payments
    PAY_UP_FRONT = 2,   # Single discounted payment upfront
    UNKNOWN = 3
}
```

### SubscriptionPeriodUnit Enum

```gdscript
enum SubscriptionPeriodUnit {
    DAY = 0,
    WEEK = 1,
    MONTH = 2,
    YEAR = 3,
    UNKNOWN = 4
}
```

## Platform Differences

| Feature | Android | iOS |
|---------|---------|-----|
| Offer Token | **Required** for all subscription purchases | Not used |
| Base Plan | Must specify via `offer_token_android` | Used by default |
| Introductory Offers | Via offer token | Applied automatically when eligible |
| Promotional Offers | Via offer token | Requires server-signed signature |

:::tip
On Android, you **must** provide `offer_token_android` when purchasing subscriptions. On iOS, the base plan is used automatically, with promotional offers requiring additional signature parameters.
:::

## Fetching Subscriptions with Offers

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

var products: Array = []

func _ready():
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)
    GodotIapPlugin.products_fetched.connect(_on_products_fetched)

    if GodotIapPlugin.init_connection():
        _fetch_subscriptions()

func _fetch_subscriptions():
    var request = Types.ProductRequest.new()
    var sku_list: Array[String] = ["premium_monthly", "premium_yearly"]
    request.skus = sku_list
    request.type = Types.ProductQueryType.SUBS

    products = GodotIapPlugin.fetch_products(request)
    _process_subscription_offers()

func _on_products_fetched(result: Dictionary):
    # Called asynchronously on iOS
    if result.has("products"):
        products = result["products"]
        _process_subscription_offers()
```

## Accessing Subscription Offers

### Android: subscriptionOfferDetailsAndroid

On Android, subscription offers are available in the `subscription_offer_details_android` property:

```gdscript
func _process_subscription_offers():
    for product in products:
        if product.type != Types.ProductType.SUBS:
            continue

        print("Subscription: %s" % product.id)

        # Android: Access offer details
        if product.subscription_offer_details_android:
            for offer in product.subscription_offer_details_android:
                print("  Offer: %s" % (offer.offer_id if offer.offer_id else "Base Plan"))
                print("    Base Plan ID: %s" % offer.base_plan_id)
                print("    Offer Token: %s" % offer.offer_token)

                # Access pricing phases
                if offer.pricing_phases:
                    for phase in offer.pricing_phases.pricing_phase_list:
                        print("    Price: %s (%s)" % [phase.formatted_price, phase.billing_period])
```

### iOS: subscriptionInfoIOS

On iOS, subscription info including introductory offers is available in `subscription_info_ios`:

```gdscript
func _process_ios_subscription(product):
    print("Subscription: %s - %s" % [product.id, product.display_price])

    if product.subscription_info_ios:
        var sub_info = product.subscription_info_ios

        # Check for introductory offer
        if sub_info.introductory_offer:
            var intro = sub_info.introductory_offer
            print("  Introductory Offer:")
            print("    Price: %s" % intro.display_price)
            print("    Payment Mode: %s" % _payment_mode_string(intro.payment_mode))
            print("    Period: %d %s(s)" % [intro.period_count, _period_unit_string(intro.period.unit)])

        # Check for promotional discounts
        if product.discounts_ios:
            for discount in product.discounts_ios:
                print("  Promotional Discount: %s" % discount.id)
                print("    Price: %s" % discount.display_price)

func _payment_mode_string(mode: Types.PaymentMode) -> String:
    match mode:
        Types.PaymentMode.FREE_TRIAL:
            return "Free Trial"
        Types.PaymentMode.PAY_AS_YOU_GO:
            return "Pay As You Go"
        Types.PaymentMode.PAY_UP_FRONT:
            return "Pay Up Front"
        _:
            return "Unknown"

func _period_unit_string(unit: Types.SubscriptionPeriodUnit) -> String:
    match unit:
        Types.SubscriptionPeriodUnit.DAY:
            return "day"
        Types.SubscriptionPeriodUnit.WEEK:
            return "week"
        Types.SubscriptionPeriodUnit.MONTH:
            return "month"
        Types.SubscriptionPeriodUnit.YEAR:
            return "year"
        _:
            return "unknown"
```

## Purchasing Subscriptions with Offers

### Android: Using Offer Tokens

On Android, you **must** provide the `offer_token` when purchasing subscriptions:

```gdscript
func purchase_subscription(product_id: String, offer_token: String = ""):
    var product = _find_product(product_id)
    if not product:
        push_error("Product not found: %s" % product_id)
        return

    var props = Types.RequestPurchaseProps.new()
    props.type = Types.ProductQueryType.SUBS
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # Android setup (required)
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    # Get offer token if not provided
    if offer_token.is_empty():
        offer_token = _get_default_offer_token(product)

    if offer_token.is_empty():
        push_error("No offer token available for subscription")
        return

    props.request.google.offer_token = offer_token

    # iOS setup
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id

    GodotIapPlugin.request_purchase(props)

func _get_default_offer_token(product) -> String:
    if not product.subscription_offer_details_android:
        return ""

    # Return first available offer token (usually base plan)
    for offer in product.subscription_offer_details_android:
        if offer.offer_token:
            return offer.offer_token

    return ""

func _find_product(product_id: String):
    for product in products:
        if product.id == product_id:
            return product
    return null
```

### Selecting Specific Offers

Allow users to choose between different offers:

```gdscript
func get_available_offers(product_id: String) -> Array:
    var product = _find_product(product_id)
    if not product:
        return []

    var offers: Array = []

    if product.subscription_offer_details_android:
        for offer_detail in product.subscription_offer_details_android:
            var offer = {
                "id": offer_detail.offer_id if offer_detail.offer_id else "base_plan",
                "base_plan_id": offer_detail.base_plan_id,
                "offer_token": offer_detail.offer_token,
                "is_base_plan": offer_detail.offer_id == null or offer_detail.offer_id.is_empty()
            }

            # Get pricing info
            if offer_detail.pricing_phases and offer_detail.pricing_phases.pricing_phase_list.size() > 0:
                var first_phase = offer_detail.pricing_phases.pricing_phase_list[0]
                offer["display_price"] = first_phase.formatted_price
                offer["billing_period"] = first_phase.billing_period

            offers.append(offer)

    return offers

func purchase_with_selected_offer(product_id: String, selected_offer: Dictionary):
    purchase_subscription(product_id, selected_offer.get("offer_token", ""))
```

### iOS: Promotional Offers with Signatures

For iOS promotional offers, you need a server-generated signature:

```gdscript
func purchase_with_promotional_offer(product_id: String, offer_id: String):
    # Generate required parameters
    var nonce = _generate_uuid()
    var timestamp = int(Time.get_unix_time_from_system() * 1000)

    # Request signature from your backend server
    var signature_data = await _request_signature_from_server(
        product_id,
        offer_id,
        nonce,
        timestamp
    )

    if not signature_data:
        push_error("Failed to get signature from server")
        return

    var props = Types.RequestPurchaseProps.new()
    props.type = Types.ProductQueryType.SUBS
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # iOS setup with promotional offer
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id
    props.request.apple.with_offer = Types.WithOfferIOS.new()
    props.request.apple.with_offer.identifier = offer_id
    props.request.apple.with_offer.key_identifier = signature_data.key_identifier
    props.request.apple.with_offer.nonce = nonce
    props.request.apple.with_offer.signature = signature_data.signature
    props.request.apple.with_offer.timestamp = timestamp

    # Android fallback
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    GodotIapPlugin.request_purchase(props)

func _request_signature_from_server(product_id: String, offer_id: String, nonce: String, timestamp: int) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)

    var body = JSON.stringify({
        "productId": product_id,
        "offerId": offer_id,
        "nonce": nonce,
        "timestamp": timestamp
    })

    http.request(
        "https://your-backend.com/api/generate-offer-signature",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        body
    )

    var result = await http.request_completed
    http.queue_free()

    if result[1] != 200:
        return {}

    return JSON.parse_string(result[3].get_string_from_utf8())

func _generate_uuid() -> String:
    var hex = "0123456789abcdef"
    var uuid = ""
    for i in range(36):
        if i in [8, 13, 18, 23]:
            uuid += "-"
        elif i == 14:
            uuid += "4"
        elif i == 19:
            uuid += hex[8 + (randi() % 4)]
        else:
            uuid += hex[randi() % 16]
    return uuid
```

## Complete Cross-Platform Example

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

signal subscription_ready(products: Array)
signal purchase_completed(product_id: String)
signal purchase_failed(error: String)

var products: Array = []
var is_connected := false

func _ready():
    _setup_iap()

func _setup_iap():
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)
    GodotIapPlugin.products_fetched.connect(_on_products_fetched)

    is_connected = GodotIapPlugin.init_connection()

    if is_connected:
        _fetch_subscriptions()

func _fetch_subscriptions():
    var request = Types.ProductRequest.new()
    var sku_list: Array[String] = ["premium_monthly", "premium_yearly"]
    request.skus = sku_list
    request.type = Types.ProductQueryType.SUBS

    var fetched = GodotIapPlugin.fetch_products(request)
    if fetched.size() > 0:
        products = fetched
        subscription_ready.emit(products)

func _on_products_fetched(result: Dictionary):
    if result.has("products"):
        products = result["products"]
        subscription_ready.emit(products)

func purchase_subscription(product_id: String, offer_token: String = ""):
    if not is_connected:
        purchase_failed.emit("Not connected to store")
        return

    var product = _find_product(product_id)
    if not product:
        purchase_failed.emit("Product not found")
        return

    var props = Types.RequestPurchaseProps.new()
    props.type = Types.ProductQueryType.SUBS
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # Android
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    var skus: Array[String] = [product_id]
    props.request.google.skus = skus

    # Android requires offer token
    if offer_token.is_empty() and product.subscription_offer_details_android:
        for offer in product.subscription_offer_details_android:
            if offer.offer_token:
                offer_token = offer.offer_token
                break

    if not offer_token.is_empty():
        props.request.google.offer_token = offer_token

    # iOS
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id

    GodotIapPlugin.request_purchase(props)

func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.get("productId", "")
    var state = purchase.get("purchaseState", "")

    if state == "Purchased" or state == "purchased":
        # Finish the transaction
        GodotIapPlugin.finish_transaction_dict(purchase, false)
        purchase_completed.emit(product_id)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "Unknown error")

    if code != "USER_CANCELED" and code != "user-cancelled":
        purchase_failed.emit(message)

func get_subscription_display_info(product_id: String) -> Dictionary:
    var product = _find_product(product_id)
    if not product:
        return {}

    var info = {
        "id": product.id,
        "title": product.title,
        "description": product.description,
        "price": product.display_price,
        "offers": []
    }

    # Android offers
    if product.subscription_offer_details_android:
        for offer in product.subscription_offer_details_android:
            var offer_info = {
                "id": offer.offer_id if offer.offer_id else "base_plan",
                "offer_token": offer.offer_token,
                "is_base_plan": offer.offer_id == null or offer.offer_id.is_empty()
            }

            if offer.pricing_phases and offer.pricing_phases.pricing_phase_list.size() > 0:
                var phase = offer.pricing_phases.pricing_phase_list[0]
                offer_info["price"] = phase.formatted_price
                offer_info["period"] = phase.billing_period

            info["offers"].append(offer_info)

    # iOS introductory offer
    if product.subscription_info_ios and product.subscription_info_ios.introductory_offer:
        var intro = product.subscription_info_ios.introductory_offer
        info["introductory_offer"] = {
            "price": intro.display_price,
            "payment_mode": intro.payment_mode,
            "period_count": intro.period_count
        }

    return info

func _find_product(product_id: String):
    for product in products:
        if product.id == product_id:
            return product
    return null
```

## Displaying Offers in UI

```gdscript
extends Control

const Types = preload("res://addons/godot-iap/types.gd")

@onready var offer_container = $OfferContainer
@onready var iap_manager = $IAPManager

func _ready():
    iap_manager.subscription_ready.connect(_on_subscriptions_ready)

func _on_subscriptions_ready(products: Array):
    for product in products:
        if product.type == Types.ProductType.SUBS:
            _create_subscription_card(product)

func _create_subscription_card(product):
    var card = VBoxContainer.new()

    # Title
    var title = Label.new()
    title.text = product.title
    card.add_child(title)

    # Base price
    var price = Label.new()
    price.text = product.display_price
    card.add_child(price)

    # Show intro offer if available (iOS)
    if product.subscription_info_ios and product.subscription_info_ios.introductory_offer:
        var intro = product.subscription_info_ios.introductory_offer
        var intro_label = Label.new()
        intro_label.text = _format_intro_offer(intro)
        intro_label.add_theme_color_override("font_color", Color.GREEN)
        card.add_child(intro_label)

    # Android offer buttons
    if product.subscription_offer_details_android:
        for offer in product.subscription_offer_details_android:
            var button = Button.new()
            button.text = _format_android_offer(offer)
            button.pressed.connect(func():
                iap_manager.purchase_subscription(product.id, offer.offer_token)
            )
            card.add_child(button)
    else:
        # iOS: Single purchase button
        var button = Button.new()
        button.text = "Subscribe - %s" % product.display_price
        button.pressed.connect(func():
            iap_manager.purchase_subscription(product.id)
        )
        card.add_child(button)

    offer_container.add_child(card)

func _format_intro_offer(intro) -> String:
    match intro.payment_mode:
        Types.PaymentMode.FREE_TRIAL:
            return "Free trial for %d %s(s)" % [intro.period_count, _unit_string(intro.period.unit)]
        Types.PaymentMode.PAY_AS_YOU_GO:
            return "Intro: %s for %d %s(s)" % [intro.display_price, intro.period_count, _unit_string(intro.period.unit)]
        Types.PaymentMode.PAY_UP_FRONT:
            return "Pay %s upfront" % intro.display_price
        _:
            return intro.display_price

func _format_android_offer(offer) -> String:
    var name = "Base Plan" if offer.offer_id == null or offer.offer_id.is_empty() else offer.offer_id

    if offer.pricing_phases and offer.pricing_phases.pricing_phase_list.size() > 0:
        var phase = offer.pricing_phases.pricing_phase_list[0]
        return "%s - %s" % [name, phase.formatted_price]

    return name

func _unit_string(unit: Types.SubscriptionPeriodUnit) -> String:
    match unit:
        Types.SubscriptionPeriodUnit.DAY: return "day"
        Types.SubscriptionPeriodUnit.WEEK: return "week"
        Types.SubscriptionPeriodUnit.MONTH: return "month"
        Types.SubscriptionPeriodUnit.YEAR: return "year"
        _: return "period"
```

## Error Handling

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "")

    match code:
        "USER_CANCELED", "user-cancelled":
            # User cancelled, no action needed
            pass

        "ITEM_ALREADY_OWNED":
            # User already owns this subscription
            GodotIapPlugin.restore_purchases()

        "PURCHASE_ERROR":
            if "offerToken" in message:
                # Android: Offer token issue - re-fetch products
                _fetch_subscriptions()
            else:
                _show_error("Purchase failed: %s" % message)

        "NETWORK_ERROR", "BILLING_UNAVAILABLE":
            _show_retry_dialog()

        _:
            _show_error(message)

func _show_error(message: String):
    # Display error to user
    print("Error: %s" % message)

func _show_retry_dialog():
    # Show retry option to user
    pass
```

## Best Practices

1. **Always use typed API**: Use `Types.ProductRequest`, `Types.RequestPurchaseProps`, etc. instead of raw JSON.

2. **Android requires offer tokens**: Never skip the `offer_token` for Android subscription purchases.

3. **Fetch before purchase**: Always call `fetch_products()` before attempting purchases to get current offer data.

4. **Handle async on iOS**: Use the `products_fetched` signal for iOS asynchronous product fetching.

5. **Validate offers exist**: Check that `subscription_offer_details_android` or `subscription_info_ios` exist before accessing.

6. **Let users choose**: When multiple offers exist, let users select their preferred pricing plan.

7. **Cache products**: Store fetched products to avoid redundant network calls.

## See Also

- [Purchases Guide](./purchases) - General purchase implementation
- [Getting Started](../getting-started/installation) - Setup and initialization
- [API Reference](../api/) - Complete method documentation
