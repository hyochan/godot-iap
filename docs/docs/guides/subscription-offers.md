---
title: Subscription Offers
sidebar_label: Subscription Offers
sidebar_position: 4
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Subscription Offers

<IapKitBanner />

This guide explains how to handle subscription offers (pricing plans) when purchasing subscriptions on iOS and Android platforms.

## Overview

Subscription offers represent different pricing plans for the same subscription product:

- **Base Plan**: The standard pricing for a subscription
- **Introductory Offers**: Special pricing for new subscribers (free trial, discounted period)
- **Promotional Offers**: Limited-time discounts configured in the app stores

## Platform Differences

At a glance:

- **Android**: Subscription offers are required when purchasing subscriptions. You must pass `offerToken` from `fetch_subscriptions()`.
- **iOS**: Base plan is used by default. Promotional discounts are optional via `withOffer`.

:::tip
Always fetch subscriptions first; offers only exist after `fetch_subscriptions()`.
:::

## Android Subscription Offers

Android requires explicit specification of subscription offers when purchasing. Each offer is identified by an `offerToken` obtained from `fetch_subscriptions()`.

### Required for Android Subscriptions

Unlike iOS, Android subscriptions **must** include `offerToken` in the purchase request. Without it, the purchase may fail with:

```text
The number of skus must match the number of offerTokens
```

### Getting Offer Tokens

```gdscript
var iap: GodotIap
var subscriptions: Array = []

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        iap.subscriptions_fetched.connect(_on_subscriptions_fetched)
        _initialize()

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        # Fetch subscriptions
        var sub_ids = ["premium_monthly", "premium_yearly"]
        iap.fetch_subscriptions(JSON.stringify(sub_ids))

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs

    for sub in subscriptions:
        print("Subscription: ", sub.productId)

        # Access offer details (Android)
        var offers = sub.get("subscriptionOfferDetailsAndroid", [])
        for offer in offers:
            print("  Offer Token: ", offer.offerToken)
            print("  Base Plan ID: ", offer.basePlanId)
            print("  Offer ID: ", offer.get("offerId", "Base Plan"))
```

### Purchase with Offers

```gdscript
func purchase_subscription(subscription_id: String):
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        print("Subscription not found")
        return

    var params = {
        "sku": subscription_id,
        "type": "subs"
    }

    # Android: Add offer token
    if OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() > 0:
            # Use the first available offer (base plan)
            params["offerToken"] = offers[0].offerToken
        else:
            print("No subscription offers available")
            return

    iap.request_purchase(JSON.stringify(params))

func _find_subscription(subscription_id: String) -> Dictionary:
    for sub in subscriptions:
        if sub.productId == subscription_id:
            return sub
    return {}
```

### Understanding Offer Details

Each `subscriptionOfferDetailsAndroid` item contains:

```gdscript
# Android Subscription Offer Structure
{
    "basePlanId": "monthly-base",      # Base plan identifier
    "offerId": "free-trial-7d",        # Offer identifier (null for base plan)
    "offerTags": ["introductory"],     # Tags associated with the offer
    "offerToken": "AEuhp4...",         # Token required for purchase
    "pricingPhases": {
        "pricingPhaseList": [
            {
                "billingPeriod": "P1M",
                "formattedPrice": "$9.99",
                "priceAmountMicros": 9990000,
                "priceCurrencyCode": "USD",
                "recurrenceMode": 1
            }
        ]
    }
}
```

### Selecting Specific Offers

```gdscript
func get_offers_for_subscription(subscription_id: String) -> Array:
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return []

    return subscription.get("subscriptionOfferDetailsAndroid", [])

func get_base_plan_offer(subscription_id: String) -> Dictionary:
    var offers = get_offers_for_subscription(subscription_id)
    for offer in offers:
        # Base plan has no offerId
        if offer.get("offerId", null) == null:
            return offer
    return offers[0] if offers.size() > 0 else {}

func get_introductory_offer(subscription_id: String) -> Dictionary:
    var offers = get_offers_for_subscription(subscription_id)
    for offer in offers:
        var offer_id = offer.get("offerId", "")
        if "intro" in offer_id or "trial" in offer_id:
            return offer
    return {}

func purchase_with_specific_offer(subscription_id: String, offer_type: String):
    var offer: Dictionary

    match offer_type:
        "base":
            offer = get_base_plan_offer(subscription_id)
        "introductory":
            offer = get_introductory_offer(subscription_id)
        _:
            offer = get_base_plan_offer(subscription_id)

    if offer.is_empty():
        print("No suitable offer found")
        return

    var params = {
        "sku": subscription_id,
        "type": "subs",
        "offerToken": offer.offerToken
    }

    iap.request_purchase(JSON.stringify(params))
```

## iOS Subscription Offers

iOS handles subscription offers differently - the base plan is used by default, and promotional offers are optional.

### Base Plan (Default)

For standard subscription purchases, no special offer specification is needed:

```gdscript
func purchase_subscription_ios(subscription_id: String):
    var params = {
        "sku": subscription_id,
        "type": "subs"
    }
    iap.request_purchase(JSON.stringify(params))
```

### Introductory Offers

iOS automatically applies introductory prices (free trials, intro pricing) configured in App Store Connect. No additional code is needed - users will see the introductory offer when eligible.

To check if a subscription has an introductory offer:

```gdscript
func check_introductory_offer(subscription_id: String):
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return

    var sub_info = subscription.get("subscriptionInfoIOS", {})
    var intro_offer = sub_info.get("introductoryOffer", null)

    if intro_offer:
        var payment_mode = intro_offer.get("paymentMode", "")
        var display_price = intro_offer.get("displayPrice", "")
        var period = intro_offer.get("period", {})
        var period_count = intro_offer.get("periodCount", 1)

        match payment_mode:
            "free-trial":
                print("Free trial: %d %s(s)" % [period_count, period.get("unit", "day")])
            "pay-as-you-go":
                print("Intro price: %s for %d %s(s)" % [display_price, period_count, period.get("unit", "month")])
            "pay-up-front":
                print("Pay upfront: %s for first %d %s(s)" % [display_price, period_count, period.get("unit", "month")])
    else:
        print("No introductory offer available")
```

### Promotional Offers (Optional)

iOS supports promotional offers through the `withOffer` parameter. These are server-to-server offers that require signature generation from your backend.

#### Getting Available Promotional Offers

```gdscript
func get_promotional_offers(subscription_id: String) -> Array:
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return []

    var discounts = subscription.get("discountsIOS", [])

    for discount in discounts:
        print("Offer: ", discount.identifier)
        print("  Price: ", discount.localizedPrice)
        print("  Payment Mode: ", discount.paymentMode)
        print("  Period: ", discount.subscriptionPeriod)
        print("  Number of Periods: ", discount.numberOfPeriods)

    return discounts
```

#### Applying Promotional Offers

To apply a promotional offer, you need to generate a signature on your backend server:

```gdscript
func purchase_with_promotional_offer(subscription_id: String, offer_id: String):
    # 1. Generate signature on your backend
    var nonce = generate_uuid()
    var timestamp = Time.get_unix_time_from_system() * 1000

    var signature_data = await request_signature_from_server(
        subscription_id,
        offer_id,
        nonce,
        timestamp
    )

    # 2. Purchase with the promotional offer
    var params = {
        "sku": subscription_id,
        "type": "subs",
        "withOffer": {
            "identifier": offer_id,
            "keyIdentifier": signature_data.key_identifier,
            "nonce": nonce,
            "signature": signature_data.signature,
            "timestamp": timestamp
        }
    }

    iap.request_purchase(JSON.stringify(params))

func request_signature_from_server(product_id: String, offer_id: String, nonce: String, timestamp: int) -> Dictionary:
    var http = HTTPRequest.new()
    add_child(http)

    var body = JSON.stringify({
        "productId": product_id,
        "offerId": offer_id,
        "nonce": nonce,
        "timestamp": timestamp
    })

    http.request(
        "https://your-backend.com/generate-offer-signature",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        body
    )

    var result = await http.request_completed
    http.queue_free()

    var response = JSON.parse_string(result[3].get_string_from_utf8())
    return response

func generate_uuid() -> String:
    # Generate a UUID v4 compliant string
    # Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    # where x is any hex digit and y is one of 8, 9, A, or B
    var hex = "0123456789abcdef"
    var uuid = ""
    for i in range(36):
        if i in [8, 13, 18, 23]:
            uuid += "-"
        elif i == 14:
            uuid += "4"  # Version 4
        elif i == 19:
            uuid += hex[8 + (randi() % 4)]  # Variant: 8, 9, a, or b
        else:
            uuid += hex[randi() % 16]
    return uuid
```

## Cross-Platform Implementation

```gdscript
extends Node

var iap: GodotIap
var subscriptions: Array = []

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        iap.subscriptions_fetched.connect(_on_subscriptions_fetched)
        iap.purchase_updated.connect(_on_purchase_updated)
        iap.purchase_error.connect(_on_purchase_error)
        _initialize()

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        var sub_ids = ["premium_monthly", "premium_yearly"]
        iap.fetch_subscriptions(JSON.stringify(sub_ids))

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs
    update_subscription_ui()

func purchase_subscription(subscription_id: String):
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        show_error("Subscription not found")
        return

    var params = {
        "sku": subscription_id,
        "type": "subs"
    }

    # Platform-specific handling
    if OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() == 0:
            show_error("No subscription offers available")
            return

        # Use first offer (or let user choose)
        params["offerToken"] = offers[0].offerToken

    elif OS.get_name() == "iOS":
        # iOS: Base plan is used by default
        # Add promotional offer if needed
        pass

    iap.request_purchase(JSON.stringify(params))

func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.productId
    var state = purchase.get("purchaseState", "")

    if state == "purchased":
        # Verify and grant subscription
        await verify_and_grant_subscription(purchase)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    match code:
        "USER_CANCELED":
            pass
        _:
            show_error(error.get("message", "Purchase failed"))

# Helper functions
func _find_subscription(subscription_id: String) -> Dictionary:
    for sub in subscriptions:
        if sub.productId == subscription_id:
            return sub
    return {}

func get_subscription_price(subscription_id: String) -> String:
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return "$9.99"

    if OS.get_name() == "iOS":
        return subscription.get("displayPrice", "$9.99")

    elif OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() > 0:
            var phases = offers[0].get("pricingPhases", {})
            var phase_list = phases.get("pricingPhaseList", [])
            if phase_list.size() > 0:
                return phase_list[0].get("formattedPrice", "$9.99")

    return "$9.99"

func update_subscription_ui():
    # Update your UI with subscription info
    pass

func verify_and_grant_subscription(purchase: Dictionary):
    # Verify on server and grant access
    pass

func show_error(message: String):
    # Show error dialog
    pass
```

## Displaying Offer Information

```gdscript
func display_subscription_options(subscription_id: String):
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return

    print("=== %s ===" % subscription.get("title", subscription_id))

    if OS.get_name() == "iOS":
        # iOS: Show base price and intro offer if available
        print("Price: ", subscription.get("displayPrice", ""))

        var sub_info = subscription.get("subscriptionInfoIOS", {})
        var intro = sub_info.get("introductoryOffer", null)
        if intro:
            print("Intro Offer: ", _format_ios_intro_offer(intro))

        var discounts = subscription.get("discountsIOS", [])
        for discount in discounts:
            print("Promo: ", discount.identifier, " - ", discount.localizedPrice)

    elif OS.get_name() == "Android":
        # Android: Show each offer
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        for offer in offers:
            var offer_name = offer.get("offerId", "Base Plan") if offer.get("offerId") else "Base Plan"
            var phases = offer.get("pricingPhases", {}).get("pricingPhaseList", [])
            if phases.size() > 0:
                print("%s: %s" % [offer_name, phases[0].get("formattedPrice", "")])

func _format_ios_intro_offer(intro: Dictionary) -> String:
    var mode = intro.get("paymentMode", "")
    var price = intro.get("displayPrice", "Free")
    var count = intro.get("periodCount", 1)
    var unit = intro.get("period", {}).get("unit", "day")

    match mode:
        "free-trial":
            return "Free for %d %s(s)" % [count, unit]
        "pay-as-you-go":
            return "%s for %d %s(s)" % [price, count, unit]
        "pay-up-front":
            return "%s upfront for %d %s(s)" % [price, count, unit]
        _:
            return price
```

## Error Handling

### Android Errors

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    if code == "PURCHASE_ERROR":
        # Check if it's an offer-related error
        var message = error.get("message", "")
        if "offerToken" in message:
            print("Subscription offer error - check offer token")
            # Re-fetch subscriptions and try again
            refetch_and_retry()
```

### iOS Errors

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    if code == "UNKNOWN":
        var message = error.get("message", "")
        if "signature" in message or "offer" in message:
            print("Promotional offer error - check signature")
```

## Best Practices

1. **Always fetch subscriptions first**: Offers are only available after `fetch_subscriptions()`.

2. **Handle platform differences**: Android requires offers, iOS makes them optional.

3. **Validate offers exist**: Check that offers exist before attempting purchase.

4. **User selection**: Allow users to choose between different pricing plans when multiple offers are available.

5. **Error recovery**: Provide fallback to base plan if selected offer fails.

6. **Cache subscription data**: Avoid fetching subscriptions on every purchase attempt.

## See Also

- [Purchases Guide](./purchases) - General purchase implementation
- [API Reference](../api/) - Detailed method documentation
- [Android-Specific Methods](../api/methods/android-specific) - Android billing details
- [iOS-Specific Methods](../api/methods/ios-specific) - iOS StoreKit details
