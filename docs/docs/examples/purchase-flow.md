---
title: Purchase Flow
sidebar_label: Purchase Flow
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Purchase Flow Example

<IapKitBanner />

This example demonstrates a complete in-app purchase implementation for a Godot game.

## Overview

This example shows how to:
- Initialize the IAP connection
- Fetch and display products
- Handle purchases with proper verification
- Finish transactions correctly

## Complete Implementation

### IapManager.gd (Autoload)

Create this script and add it as an Autoload singleton in Project Settings.

```gdscript
# iap_manager.gd
extends Node

# IAP reference
var iap: GodotIap = null
var is_connected: bool = false

# Product data
var products: Array = []
var subscriptions: Array = []

# Product IDs
const PRODUCT_IDS = {
    "coins_100": "com.yourgame.coins_100",
    "coins_500": "com.yourgame.coins_500",
    "remove_ads": "com.yourgame.remove_ads",
    "premium_monthly": "com.yourgame.premium_monthly"
}

# Signals for other scripts to connect to
signal connection_changed(connected: bool)
signal products_loaded(products: Array)
signal purchase_completed(product_id: String)
signal purchase_failed(error: Dictionary)

func _ready():
    _initialize_iap()

func _initialize_iap():
    if not Engine.has_singleton("GodotIap"):
        push_warning("GodotIap singleton not available")
        return

    iap = Engine.get_singleton("GodotIap")

    # Connect signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

    # Initialize connection
    var result = JSON.parse_string(iap.init_connection())
    is_connected = result.get("success", false)

    if is_connected:
        print("IAP connected successfully")
        connection_changed.emit(true)
        _check_pending_purchases()
        _load_products()
    else:
        print("IAP connection failed: ", result.get("error", ""))
        connection_changed.emit(false)

func _check_pending_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        await _process_purchase(purchase)

func _load_products():
    # Load in-app products
    var inapp_ids = [
        PRODUCT_IDS.coins_100,
        PRODUCT_IDS.coins_500,
        PRODUCT_IDS.remove_ads
    ]
    iap.fetch_products(JSON.stringify(inapp_ids), "inapp")

    # Load subscriptions
    var sub_ids = [PRODUCT_IDS.premium_monthly]
    iap.fetch_subscriptions(JSON.stringify(sub_ids))

# Signal handlers
func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    print("Loaded %d products" % products.size())
    products_loaded.emit(products)

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs
    print("Loaded %d subscriptions" % subscriptions.size())

func _on_purchase_updated(purchase: Dictionary):
    await _process_purchase(purchase)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    if code == "USER_CANCELED":
        print("User cancelled purchase")
    else:
        print("Purchase error: ", error.get("message", ""))
        purchase_failed.emit(error)

func _process_purchase(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    var product_id = purchase.productId

    print("Processing purchase: ", product_id, " state: ", state)

    if state == "pending":
        print("Purchase pending approval")
        return

    if state != "purchased":
        return

    # Verify purchase on server (recommended for production)
    var is_valid = await _verify_purchase(purchase)

    if not is_valid:
        print("Purchase verification failed")
        return

    # Grant the content
    _grant_purchase(product_id)

    # Finish the transaction
    var is_consumable = _is_consumable(product_id)
    var params = {
        "purchase": purchase,
        "isConsumable": is_consumable
    }

    var result = JSON.parse_string(iap.finish_transaction(JSON.stringify(params)))
    if result.get("success", false):
        print("Transaction finished for: ", product_id)
        purchase_completed.emit(product_id)

# Public API
func buy_product(product_id: String):
    if not is_connected:
        push_error("IAP not connected")
        return

    var params = {
        "sku": product_id,
        "type": "inapp"
    }

    iap.request_purchase(JSON.stringify(params))

func buy_subscription(subscription_id: String):
    if not is_connected:
        push_error("IAP not connected")
        return

    var params = {
        "sku": subscription_id,
        "type": "subs"
    }

    # Android: Add offer token
    if OS.get_name() == "Android":
        var sub = _find_subscription(subscription_id)
        if sub:
            var offers = sub.get("subscriptionOfferDetailsAndroid", [])
            if offers.size() > 0:
                params["offerToken"] = offers[0].offerToken

    iap.request_purchase(JSON.stringify(params))

func restore_purchases():
    if not is_connected:
        push_error("IAP not connected")
        return

    var purchases = JSON.parse_string(iap.get_available_purchases())
    var restored_count = 0

    for purchase in purchases:
        var is_valid = await _verify_purchase(purchase)
        if is_valid:
            _grant_purchase(purchase.productId)
            restored_count += 1

    return restored_count

func get_product(product_id: String) -> Dictionary:
    for product in products:
        if product.productId == product_id:
            return product
    return {}

func get_product_price(product_id: String) -> String:
    var product = get_product(product_id)
    if product.is_empty():
        return "$0.99"

    return product.get("localizedPrice", "$0.99")

# Helper functions
func _find_subscription(subscription_id: String) -> Dictionary:
    for sub in subscriptions:
        if sub.productId == subscription_id:
            return sub
    return {}

func _is_consumable(product_id: String) -> bool:
    return product_id in [PRODUCT_IDS.coins_100, PRODUCT_IDS.coins_500]

func _verify_purchase(purchase: Dictionary) -> bool:
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
        return state == "entitled" or state == "ready-to-consume"

    return false

func _grant_purchase(product_id: String):
    match product_id:
        PRODUCT_IDS.coins_100:
            GameState.add_coins(100)
            print("Granted 100 coins")

        PRODUCT_IDS.coins_500:
            GameState.add_coins(500)
            print("Granted 500 coins")

        PRODUCT_IDS.remove_ads:
            GameState.set_ads_removed(true)
            print("Ads removed")

        PRODUCT_IDS.premium_monthly:
            GameState.set_premium(true)
            print("Premium activated")

        _:
            print("Unknown product: ", product_id)
```

### StoreUI.gd (Store Interface)

```gdscript
# store_ui.gd
extends Control

@onready var product_container: VBoxContainer = $ProductContainer
@onready var loading_label: Label = $LoadingLabel
@onready var restore_button: Button = $RestoreButton

# Product button scene (create this in the editor)
var product_button_scene = preload("res://ui/product_button.tscn")

func _ready():
    # Connect to IapManager signals
    IapManager.connection_changed.connect(_on_connection_changed)
    IapManager.products_loaded.connect(_on_products_loaded)
    IapManager.purchase_completed.connect(_on_purchase_completed)
    IapManager.purchase_failed.connect(_on_purchase_failed)

    restore_button.pressed.connect(_on_restore_pressed)

    # Check if already connected
    if IapManager.is_connected:
        loading_label.text = "Loading products..."
    else:
        loading_label.text = "Connecting to store..."

func _on_connection_changed(connected: bool):
    if connected:
        loading_label.text = "Loading products..."
    else:
        loading_label.text = "Store unavailable"

func _on_products_loaded(products: Array):
    loading_label.hide()
    _display_products(products)

func _display_products(products: Array):
    # Clear existing buttons
    for child in product_container.get_children():
        child.queue_free()

    # Create button for each product
    for product in products:
        var button = product_button_scene.instantiate()
        button.setup(product)
        button.pressed.connect(func(): _on_product_pressed(product.productId))
        product_container.add_child(button)

func _on_product_pressed(product_id: String):
    print("Purchasing: ", product_id)

    # Show loading state
    set_buttons_enabled(false)

    # Request purchase
    IapManager.buy_product(product_id)

func _on_purchase_completed(product_id: String):
    set_buttons_enabled(true)
    show_success_dialog("Purchase successful!")

func _on_purchase_failed(error: Dictionary):
    set_buttons_enabled(true)

    var code = error.get("code", "")
    if code != "USER_CANCELED":
        show_error_dialog(error.get("message", "Purchase failed"))

func _on_restore_pressed():
    set_buttons_enabled(false)
    var count = await IapManager.restore_purchases()
    set_buttons_enabled(true)

    if count > 0:
        show_success_dialog("Restored %d purchases" % count)
    else:
        show_info_dialog("No purchases to restore")

func set_buttons_enabled(enabled: bool):
    for child in product_container.get_children():
        if child is Button:
            child.disabled = not enabled
    restore_button.disabled = not enabled

func show_success_dialog(message: String):
    var dialog = AcceptDialog.new()
    dialog.title = "Success"
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)

func show_error_dialog(message: String):
    var dialog = AcceptDialog.new()
    dialog.title = "Error"
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)

func show_info_dialog(message: String):
    var dialog = AcceptDialog.new()
    dialog.title = "Info"
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)
```

### ProductButton.gd

```gdscript
# product_button.gd
extends Button

@onready var title_label: Label = $TitleLabel
@onready var price_label: Label = $PriceLabel
@onready var description_label: Label = $DescriptionLabel

var product_data: Dictionary = {}

func setup(product: Dictionary):
    product_data = product

    title_label.text = product.get("title", "Product")
    price_label.text = product.get("localizedPrice", "$0.99")
    description_label.text = product.get("description", "")
```

### GameState.gd (Autoload)

```gdscript
# game_state.gd
extends Node

var coins: int = 0
var ads_removed: bool = false
var is_premium: bool = false

const SAVE_PATH = "user://game_state.save"

func _ready():
    load_state()

func add_coins(amount: int):
    coins += amount
    save_state()

func remove_coins(amount: int) -> bool:
    if coins >= amount:
        coins -= amount
        save_state()
        return true
    return false

func set_ads_removed(value: bool):
    ads_removed = value
    save_state()

func set_premium(value: bool):
    is_premium = value
    save_state()

func save_state():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        var data = {
            "coins": coins,
            "ads_removed": ads_removed,
            "is_premium": is_premium
        }
        file.store_string(JSON.stringify(data))
        file.close()

func load_state():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file:
            var data = JSON.parse_string(file.get_as_text())
            if data:
                coins = data.get("coins", 0)
                ads_removed = data.get("ads_removed", false)
                is_premium = data.get("is_premium", false)
            file.close()
```

## Usage

1. Add `GameState` and `IapManager` as Autoloads in Project Settings
2. Create the `StoreUI` scene with the required nodes
3. Create a `ProductButton` scene for displaying products
4. Call `IapManager.buy_product()` when user taps a product

## Testing

### iOS Testing
1. Create sandbox test accounts in App Store Connect
2. Sign out of App Store on device
3. Launch game and make a purchase
4. Sign in with sandbox account when prompted

### Android Testing
1. Upload signed APK to Google Play Console (internal testing)
2. Add your test account to license testers
3. Install the app from Play Store
4. Test purchases (won't be charged)

## Server-Side Verification

For production apps, we recommend using <IapKitLink>IAPKit</IapKitLink> for server-side purchase verification. The example above includes `_verify_with_iapkit()` which calls IAPKit's verification API.

Get your API key at <IapKitLink>iapkit.com</IapKitLink>.

## See Also

- [Subscription Flow Example](./subscription-flow) - Subscription implementation
- [Available Purchases Example](./available-purchases) - Purchase restoration
- [Purchases Guide](../guides/purchases) - Detailed purchase documentation
- <IapKitLink>IAPKit Dashboard</IapKitLink> - Server-side verification service
