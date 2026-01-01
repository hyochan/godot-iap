---
title: Purchase Flow
sidebar_label: Purchase Flow
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import IapKitLink from '@site/src/uis/IapKitLink';

# Purchase Flow Example

<IapKitBanner />

This example demonstrates a complete in-app purchase implementation for a Godot game using the **type-safe API**.

## Overview

This example shows how to:
- Initialize the IAP connection
- Fetch and display products with typed objects
- Handle purchases with proper verification
- Finish transactions correctly

## Complete Implementation

### IapManager.gd (Autoload)

Create this script and add it as an Autoload singleton in Project Settings.

```gdscript
# iap_manager.gd
extends Node

# Load OpenIAP types for type-safe API
const Types = preload("res://addons/godot-iap/types.gd")

# GodotIapWrapper reference
var iap: Node

# Connection state
var is_connected: bool = false

# Product data - stored as typed objects
var products: Dictionary = {}  # product_id -> Types.ProductAndroid or Types.ProductIOS

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
    _setup_iap_node()
    _initialize_iap()

func _setup_iap_node():
    # Create GodotIapWrapper node dynamically for Autoload
    var wrapper = preload("res://addons/godot-iap/godot_iap.gd").new()
    wrapper.name = "GodotIapWrapper"
    add_child(wrapper)
    iap = wrapper

func _initialize_iap():
    # Connect signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

    # Initialize connection - returns bool
    is_connected = iap.init_connection()

    if is_connected:
        print("IAP connected successfully")
        connection_changed.emit(true)
        _check_pending_purchases()
        _load_products()
    else:
        print("IAP connection failed")
        connection_changed.emit(false)

func _check_pending_purchases():
    # Returns Array of typed purchase objects
    var purchases = iap.get_available_purchases()
    for purchase in purchases:
        await _process_purchase(purchase)

func _load_products():
    # Create typed ProductRequest
    var request = Types.ProductRequest.new()
    request.skus = PRODUCT_IDS.values()
    request.type = Types.ProductQueryType.ALL

    # Returns Array of typed product objects
    var fetched_products = iap.fetch_products(request)
    _process_products(fetched_products)

func _process_products(fetched_products: Array):
    for product in fetched_products:
        # Access typed properties directly
        products[product.id] = product
        print("Loaded: %s - %s" % [product.id, product.display_price])
    products_loaded.emit(fetched_products)

# Signal handlers
func _on_products_fetched(result: Dictionary):
    # iOS async callback
    if result.has("products"):
        for product_dict in result["products"]:
            var id = product_dict.get("id", "")
            products[id] = product_dict
        products_loaded.emit(products.values())

func _on_purchase_updated(purchase: Dictionary):
    await _process_purchase_dict(purchase)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    if code == "USER_CANCELED":
        print("User cancelled purchase")
    else:
        print("Purchase error: ", error.get("message", ""))
        purchase_failed.emit(error)

func _process_purchase(purchase) -> void:
    # Works with both typed objects and dictionaries
    var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")
    var state = purchase.purchase_state if purchase is Object else purchase.get("purchaseState", "")

    print("Processing purchase: %s (state: %s)" % [product_id, state])

    if state == "Pending" or state == "pending":
        print("Purchase pending approval")
        return

    if state != "Purchased" and state != "purchased":
        return

    # Verify purchase on server (recommended for production)
    var is_valid = await _verify_purchase(purchase)
    if not is_valid:
        print("Purchase verification failed")
        return

    # Grant the content
    _grant_purchase(product_id)

    # Finish the transaction with typed input
    var is_consumable = _is_consumable(product_id)
    var purchase_input: Types.PurchaseInput
    if purchase is Object:
        purchase_input = Types.PurchaseInput.new()
        purchase_input.product_id = purchase.product_id
        purchase_input.purchase_token = purchase.purchase_token if "purchase_token" in purchase else ""
        purchase_input.transaction_id = purchase.transaction_id if "transaction_id" in purchase else ""
    else:
        purchase_input = Types.PurchaseInput.from_dict(purchase)

    var result = iap.finish_transaction(purchase_input, is_consumable)
    if result.success:
        print("Transaction finished for: ", product_id)
        purchase_completed.emit(product_id)

func _process_purchase_dict(purchase: Dictionary) -> void:
    await _process_purchase(purchase)

# Public API
func buy_product(product_id: String):
    if not is_connected:
        push_error("IAP not connected")
        return

    # Create typed RequestPurchaseProps
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    # Android configuration
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    props.request.google.skus = [product_id]

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id

    props.type = Types.ProductQueryType.IN_APP

    # Returns typed purchase object or null
    var purchase = iap.request_purchase(props)
    if purchase:
        print("Purchase initiated: ", purchase.product_id)

func restore_purchases():
    if not is_connected:
        push_error("IAP not connected")
        return

    # Returns typed VoidResult
    var result = iap.restore_purchases()
    if result.success:
        print("Restore initiated")

func get_product(product_id: String):
    return products.get(product_id, null)

func get_product_price(product_id: String) -> String:
    var product = get_product(product_id)
    if product == null:
        return "$0.99"
    # Access typed property
    return product.display_price if product.display_price else "$0.99"

# Helper functions
func _is_consumable(product_id: String) -> bool:
    return product_id in [PRODUCT_IDS.coins_100, PRODUCT_IDS.coins_500]

func _verify_purchase(purchase) -> bool:
    # For development, return true
    # For production, use IAPKit for server-side verification
    if OS.is_debug_build():
        return true

    # Production: Verify with IAPKit
    return await _verify_with_iapkit(purchase)

func _verify_with_iapkit(purchase) -> bool:
    var http = HTTPRequest.new()
    add_child(http)

    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer YOUR_IAPKIT_API_KEY"  # Get from iapkit.com
    ]

    var purchase_token = ""
    if purchase is Object:
        purchase_token = purchase.purchase_token if "purchase_token" in purchase else ""
    else:
        purchase_token = purchase.get("purchaseToken", "")

    var body = {}
    if OS.get_name() == "iOS":
        body = { "apple": { "jws": purchase_token } }
    elif OS.get_name() == "Android":
        body = { "google": { "purchaseToken": purchase_token } }

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

const Types = preload("res://addons/godot-iap/types.gd")

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
        # Access typed properties directly
        button.setup(product.id, product.title, product.display_price)
        button.pressed.connect(func(): _on_product_pressed(product.id))
        product_container.add_child(button)

func _on_product_pressed(product_id: String):
    print("Purchasing: ", product_id)
    set_buttons_enabled(false)
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
    IapManager.restore_purchases()
    # Results come through purchase_updated signal
    await get_tree().create_timer(2.0).timeout
    set_buttons_enabled(true)

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
```

### ProductButton.gd

```gdscript
# product_button.gd
extends Button

@onready var title_label: Label = $TitleLabel
@onready var price_label: Label = $PriceLabel

var product_id: String = ""

func setup(id: String, title: String, price: String):
    product_id = id
    title_label.text = title
    price_label.text = price
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

## Type System

### Platform-Specific Types (Sealed Class Pattern)

GDScript doesn't support Union types like Dart's `sealed class`. Functions that return platform-specific types use:

| Return Type | Description |
|-------------|-------------|
| `-> Array` | Array of `Types.ProductAndroid` OR `Types.ProductIOS` |
| `-> Variant` | Typed object OR `null` |

```gdscript
# fetch_products returns Array of typed products
var products = iap.fetch_products(request)
for product in products:
    # On Android: product is Types.ProductAndroid
    # On iOS: product is Types.ProductIOS
    # Both have common properties: id, title, display_price
    print(product.id, " - ", product.display_price)
```

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
