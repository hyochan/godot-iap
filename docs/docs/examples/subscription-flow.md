---
title: Subscription Flow
sidebar_label: Subscription Flow
sidebar_position: 2
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Subscription Flow Example

<IapKitBanner />

This example demonstrates how to implement subscription purchases with proper offer handling for both iOS and Android.

## Overview

This example covers:
- Fetching subscription products with offer details
- Displaying subscription options to users
- Handling platform-specific offer requirements
- Managing subscription status

## Complete Implementation

### SubscriptionManager.gd

```gdscript
# subscription_manager.gd
extends Node

var iap: GodotIap = null
var subscriptions: Array = []
var is_connected: bool = false

# Subscription IDs
const SUBSCRIPTION_IDS = {
    "monthly": "com.yourgame.premium_monthly",
    "yearly": "com.yourgame.premium_yearly"
}

signal subscriptions_loaded(subscriptions: Array)
signal subscription_purchased(subscription_id: String)
signal subscription_error(error: Dictionary)
signal subscription_status_changed(is_active: bool)

func _ready():
    _initialize()

func _initialize():
    if not Engine.has_singleton("GodotIap"):
        push_warning("GodotIap not available")
        return

    iap = Engine.get_singleton("GodotIap")

    # Connect signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

    # iOS-specific
    if OS.get_name() == "iOS":
        iap.subscription_status_changed_ios.connect(_on_subscription_status_changed_ios)

    # Initialize connection
    var result = JSON.parse_string(iap.init_connection())
    is_connected = result.get("success", false)

    if is_connected:
        _check_subscription_status()
        _load_subscriptions()

func _load_subscriptions():
    var sub_ids = SUBSCRIPTION_IDS.values()
    iap.fetch_subscriptions(JSON.stringify(sub_ids))

func _check_subscription_status():
    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        if _is_subscription(purchase.productId):
            if _is_subscription_active(purchase):
                GameState.set_premium(true)
                subscription_status_changed.emit(true)
                return

    GameState.set_premium(false)
    subscription_status_changed.emit(false)

# Signal handlers
func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs

    for sub in subscriptions:
        print("Subscription: ", sub.productId)
        _print_subscription_details(sub)

    subscriptions_loaded.emit(subscriptions)

func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.productId

    if not _is_subscription(product_id):
        return

    var state = purchase.get("purchaseState", "")

    if state == "purchased":
        await _process_subscription_purchase(purchase)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    if code != "USER_CANCELED":
        subscription_error.emit(error)

func _on_subscription_status_changed_ios(status: Dictionary):
    var state = status.get("state", "")

    match state:
        "subscribed":
            GameState.set_premium(true)
            subscription_status_changed.emit(true)
        "expired", "revoked":
            GameState.set_premium(false)
            subscription_status_changed.emit(false)
        "inGracePeriod", "inBillingRetryPeriod":
            # Still has access but there's a billing issue
            GameState.set_premium(true)
            # Show warning to user
            print("Subscription billing issue - grace period active")

func _process_subscription_purchase(purchase: Dictionary):
    # Verify on server
    var is_valid = await _verify_subscription(purchase)

    if not is_valid:
        print("Subscription verification failed")
        return

    # Grant premium access
    GameState.set_premium(true)

    # Finish transaction
    var params = {
        "purchase": purchase,
        "isConsumable": false
    }
    iap.finish_transaction(JSON.stringify(params))

    subscription_purchased.emit(purchase.productId)
    subscription_status_changed.emit(true)

# Public API
func purchase_subscription(subscription_id: String):
    if not is_connected:
        push_error("Not connected to store")
        return

    var subscription = _find_subscription(subscription_id)
    if not subscription:
        push_error("Subscription not found: ", subscription_id)
        return

    var params = {
        "sku": subscription_id,
        "type": "subs"
    }

    # Android: Must include offer token
    if OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() == 0:
            push_error("No subscription offers available")
            return

        # Use first offer (or let user choose)
        params["offerToken"] = offers[0].offerToken

    iap.request_purchase(JSON.stringify(params))

func purchase_subscription_with_offer(subscription_id: String, offer_index: int):
    """Purchase with a specific offer (Android only)"""
    if OS.get_name() != "Android":
        purchase_subscription(subscription_id)
        return

    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return

    var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
    if offer_index >= offers.size():
        push_error("Invalid offer index")
        return

    var params = {
        "sku": subscription_id,
        "type": "subs",
        "offerToken": offers[offer_index].offerToken
    }

    iap.request_purchase(JSON.stringify(params))

func restore_subscriptions() -> bool:
    if not is_connected:
        return false

    var purchases = JSON.parse_string(iap.get_available_purchases())
    var found_active = false

    for purchase in purchases:
        if _is_subscription(purchase.productId):
            if _is_subscription_active(purchase):
                GameState.set_premium(true)
                found_active = true

    subscription_status_changed.emit(found_active)
    return found_active

func manage_subscriptions():
    """Open subscription management in platform settings"""
    var options = {}

    if OS.get_name() == "Android":
        options["packageNameAndroid"] = ProjectSettings.get_setting(
            "application/config/package_name"
        )

    iap.deep_link_to_subscriptions(JSON.stringify(options))

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

func get_subscription_offers(subscription_id: String) -> Array:
    """Get all available offers for a subscription (Android)"""
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return []

    return subscription.get("subscriptionOfferDetailsAndroid", [])

func has_free_trial(subscription_id: String) -> bool:
    var subscription = _find_subscription(subscription_id)
    if not subscription:
        return false

    if OS.get_name() == "iOS":
        var sub_info = subscription.get("subscriptionInfoIOS", {})
        var intro = sub_info.get("introductoryOffer", null)
        if intro:
            return intro.get("paymentMode", "") == "free-trial"

    elif OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        for offer in offers:
            var phases = offer.get("pricingPhases", {}).get("pricingPhaseList", [])
            for phase in phases:
                if phase.get("priceAmountMicros", 1) == 0:
                    return true

    return false

# Helper functions
func _find_subscription(subscription_id: String) -> Dictionary:
    for sub in subscriptions:
        if sub.productId == subscription_id:
            return sub
    return {}

func _is_subscription(product_id: String) -> bool:
    return product_id in SUBSCRIPTION_IDS.values()

func _is_subscription_active(purchase: Dictionary) -> bool:
    var current_time = Time.get_unix_time_from_system() * 1000

    if OS.get_name() == "iOS":
        var expiration = purchase.get("expirationDateIOS", 0)
        if expiration > 0:
            return expiration > current_time

        # Sandbox: Consider recent purchases as active
        if purchase.get("environmentIOS") == "Sandbox":
            var day_ms = 24 * 60 * 60 * 1000
            var tx_date = purchase.get("transactionDate", 0)
            return (current_time - tx_date) < day_ms

    elif OS.get_name() == "Android":
        var auto_renewing = purchase.get("autoRenewingAndroid", null)
        if auto_renewing != null:
            return auto_renewing

        if purchase.get("purchaseState") == "purchased":
            return true

    return false

func _verify_subscription(purchase: Dictionary) -> bool:
    # For development, return true
    # For production, use IAPKit for server-side verification
    if OS.is_debug_build():
        return true

    # Production: Verify with IAPKit
    return await _verify_with_iapkit(purchase)

func _verify_with_iapkit(purchase: Dictionary) -> bool:
    var http = HTTPRequest.new()
    add_child(http)

    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer YOUR_IAPKIT_API_KEY"  # Get from iapkit.com
    ]

    var body = {}
    if OS.get_name() == "iOS":
        body = { "apple": { "jws": purchase.get("purchaseToken", "") } }
    elif OS.get_name() == "Android":
        body = { "google": { "purchaseToken": purchase.get("purchaseToken", "") } }

    http.request(
        "https://api.iapkit.com/v1/verify",
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
    )

    var response = await http.request_completed
    http.queue_free()

    if response[1] != 200:
        return false

    var result = JSON.parse_string(response[3].get_string_from_utf8())
    if result is Dictionary:
        var state = result.get("state", "")
        # For subscriptions, check entitled or active states
        return state == "entitled"

    return false

func _print_subscription_details(subscription: Dictionary):
    print("  Title: ", subscription.get("title", ""))
    print("  Price: ", get_subscription_price(subscription.productId))

    if OS.get_name() == "iOS":
        var sub_info = subscription.get("subscriptionInfoIOS", {})
        var intro = sub_info.get("introductoryOffer", null)
        if intro:
            print("  Intro Offer: ", intro.get("paymentMode", ""), " - ", intro.get("displayPrice", ""))

    elif OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        print("  Offers: ", offers.size())
        for i in range(offers.size()):
            var offer = offers[i]
            var offer_id = offer.get("offerId", "Base Plan")
            print("    [%d] %s" % [i, offer_id if offer_id else "Base Plan"])
```

### SubscriptionUI.gd

```gdscript
# subscription_ui.gd
extends Control

@onready var monthly_button: Button = $MonthlyButton
@onready var yearly_button: Button = $YearlyButton
@onready var restore_button: Button = $RestoreButton
@onready var manage_button: Button = $ManageButton
@onready var status_label: Label = $StatusLabel
@onready var trial_label: Label = $TrialLabel

func _ready():
    # Connect to SubscriptionManager
    SubscriptionManager.subscriptions_loaded.connect(_on_subscriptions_loaded)
    SubscriptionManager.subscription_purchased.connect(_on_subscription_purchased)
    SubscriptionManager.subscription_error.connect(_on_subscription_error)
    SubscriptionManager.subscription_status_changed.connect(_on_status_changed)

    # Connect buttons
    monthly_button.pressed.connect(_on_monthly_pressed)
    yearly_button.pressed.connect(_on_yearly_pressed)
    restore_button.pressed.connect(_on_restore_pressed)
    manage_button.pressed.connect(_on_manage_pressed)

    # Initial state
    _update_ui()

func _on_subscriptions_loaded(subscriptions: Array):
    # Update button prices
    monthly_button.text = "Monthly - %s" % SubscriptionManager.get_subscription_price(
        SubscriptionManager.SUBSCRIPTION_IDS.monthly
    )

    yearly_button.text = "Yearly - %s" % SubscriptionManager.get_subscription_price(
        SubscriptionManager.SUBSCRIPTION_IDS.yearly
    )

    # Check for free trial
    if SubscriptionManager.has_free_trial(SubscriptionManager.SUBSCRIPTION_IDS.monthly):
        trial_label.text = "Free trial available!"
        trial_label.show()
    else:
        trial_label.hide()

func _on_subscription_purchased(subscription_id: String):
    _set_buttons_enabled(true)
    _update_ui()
    _show_dialog("Success", "Subscription activated!")

func _on_subscription_error(error: Dictionary):
    _set_buttons_enabled(true)
    _show_dialog("Error", error.get("message", "Subscription failed"))

func _on_status_changed(is_active: bool):
    _update_ui()

func _on_monthly_pressed():
    _set_buttons_enabled(false)
    SubscriptionManager.purchase_subscription(
        SubscriptionManager.SUBSCRIPTION_IDS.monthly
    )

func _on_yearly_pressed():
    _set_buttons_enabled(false)
    SubscriptionManager.purchase_subscription(
        SubscriptionManager.SUBSCRIPTION_IDS.yearly
    )

func _on_restore_pressed():
    _set_buttons_enabled(false)
    var restored = await SubscriptionManager.restore_subscriptions()
    _set_buttons_enabled(true)

    if restored:
        _show_dialog("Restored", "Subscription restored successfully!")
    else:
        _show_dialog("Not Found", "No active subscription found.")

func _on_manage_pressed():
    SubscriptionManager.manage_subscriptions()

func _update_ui():
    var is_premium = GameState.is_premium

    if is_premium:
        status_label.text = "Premium Active"
        monthly_button.hide()
        yearly_button.hide()
        manage_button.show()
    else:
        status_label.text = "Free Account"
        monthly_button.show()
        yearly_button.show()
        manage_button.hide()

func _set_buttons_enabled(enabled: bool):
    monthly_button.disabled = not enabled
    yearly_button.disabled = not enabled
    restore_button.disabled = not enabled

func _show_dialog(title: String, message: String):
    var dialog = AcceptDialog.new()
    dialog.title = title
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)
```

### Offer Selection (Android)

For apps that want to let users choose between different offers:

```gdscript
# offer_selection_ui.gd
extends Control

@onready var offer_container: VBoxContainer = $OfferContainer

var subscription_id: String = ""

func show_offers(sub_id: String):
    subscription_id = sub_id
    _display_offers()

func _display_offers():
    # Clear existing
    for child in offer_container.get_children():
        child.queue_free()

    # Get offers
    var offers = SubscriptionManager.get_subscription_offers(subscription_id)

    for i in range(offers.size()):
        var offer = offers[i]
        var button = Button.new()
        button.text = _format_offer(offer)
        button.pressed.connect(func(): _on_offer_selected(i))
        offer_container.add_child(button)

func _format_offer(offer: Dictionary) -> String:
    var offer_id = offer.get("offerId", null)
    var phases = offer.get("pricingPhases", {}).get("pricingPhaseList", [])

    var text = "Base Plan" if not offer_id else offer_id

    if phases.size() > 0:
        var price = phases[0].get("formattedPrice", "")
        var period = phases[0].get("billingPeriod", "")
        text += " - %s / %s" % [price, _format_period(period)]

    return text

func _format_period(iso_period: String) -> String:
    match iso_period:
        "P1M": return "month"
        "P1Y": return "year"
        "P1W": return "week"
        _: return iso_period

func _on_offer_selected(offer_index: int):
    SubscriptionManager.purchase_subscription_with_offer(subscription_id, offer_index)
    hide()
```

## Testing

### iOS Sandbox Testing

1. Create sandbox accounts in App Store Connect
2. Configure subscription durations for testing:
   - Monthly → 5 minutes in sandbox
   - Yearly → 1 hour in sandbox
3. Test subscription lifecycle (purchase, renewal, expiration)

### Android Testing

1. Add test accounts in Google Play Console → License testing
2. Upload signed build to internal testing track
3. Test subscriptions won't charge real money

## Server-Side Verification

For production apps, we recommend using <IapKitLink>IAPKit</IapKitLink> for server-side subscription verification. The example above includes `_verify_with_iapkit()` which validates subscriptions through IAPKit's API.

IAPKit provides:
- **Subscription status tracking** with automatic renewal detection
- **Grace period handling** for billing issues
- **Cross-platform verification** for iOS and Android

Get your API key at <IapKitLink>iapkit.com</IapKitLink>.

## See Also

- [Subscription Offers Guide](../guides/subscription-offers) - Detailed offer documentation
- [Purchase Flow Example](./purchase-flow) - Basic purchase implementation
- [iOS-Specific Methods](../api/methods/ios-specific) - iOS subscription APIs
- [Android-Specific Methods](../api/methods/android-specific) - Android subscription APIs
- <IapKitLink>IAPKit Dashboard</IapKitLink> - Server-side verification service
