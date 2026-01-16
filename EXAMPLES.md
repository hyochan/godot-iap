# Godot IAP Examples

This guide provides step-by-step tutorials for implementing in-app purchases in your Godot game using the type-safe API.

## Table of Contents

1. [Setup](#1-setup)
2. [Basic Purchase Flow](#2-basic-purchase-flow)
3. [Subscription Implementation](#3-subscription-implementation)
4. [Restoring Purchases](#4-restoring-purchases)
5. [Complete Store UI](#5-complete-store-ui)

---

## 1. Setup

### 1.1 Loading Types

All examples use the OpenIAP type system for type safety:

```gdscript
# Load OpenIAP types at the top of your script
const Types = preload("res://addons/godot-iap/types.gd")
```

### 1.2 Scene-Based Setup

Add `GodotIapWrapper` as a child node in your scene:

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

# Reference to GodotIapWrapper node (add as child in scene)
@onready var iap = $GodotIapWrapper

func _ready():
    # Connect signals
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

    # Initialize connection
    if iap.init_connection():
        print("IAP connected!")
```

### 1.3 Autoload Setup

For global access, create an Autoload singleton:

```gdscript
# iap_manager.gd - Add as Autoload in Project Settings
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

var iap: Node
var is_connected: bool = false

func _ready():
    _setup_iap_node()
    _initialize_iap()

func _setup_iap_node():
    # Create GodotIapWrapper node dynamically
    var wrapper = preload("res://addons/godot-iap/godot_iap.gd").new()
    wrapper.name = "GodotIapWrapper"
    add_child(wrapper)
    iap = wrapper

func _initialize_iap():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

    is_connected = iap.init_connection()
```

---

## 2. Basic Purchase Flow

### 2.1 Fetching Products

```gdscript
const PRODUCT_IDS = {
    "coins_100": "com.yourgame.coins_100",
    "coins_500": "com.yourgame.coins_500",
    "remove_ads": "com.yourgame.remove_ads"
}

var products: Dictionary = {}  # product_id -> product object

func fetch_products():
    # Create typed ProductRequest
    var request = Types.ProductRequest.new()
    request.skus = PRODUCT_IDS.values()
    request.type = Types.ProductQueryType.ALL

    # Returns Array of Types.ProductAndroid or Types.ProductIOS
    var fetched = iap.fetch_products(request)

    for product in fetched:
        # Access typed properties directly
        products[product.id] = product
        print("Product: %s - %s" % [product.title, product.display_price])
```

### 2.2 Making a Purchase

```gdscript
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
```

### 2.3 Handling Purchase Results

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var product_id = purchase.get("productId", "")
    var state = purchase.get("purchaseState", "")

    print("Purchase updated: %s (state: %s)" % [product_id, state])

    match state:
        "Purchased", "purchased":
            await _process_successful_purchase(purchase)
        "Pending", "pending":
            print("Purchase pending approval")
        _:
            print("Purchase state: ", state)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "")

    if code == "USER_CANCELED":
        print("User cancelled purchase")
    else:
        print("Purchase error: %s - %s" % [code, message])

func _process_successful_purchase(purchase: Dictionary):
    var product_id = purchase.get("productId", "")

    # Grant content to user
    _grant_purchase(product_id)

    # Finish the transaction
    var is_consumable = _is_consumable(product_id)
    var result = iap.finish_transaction_dict(purchase, is_consumable)

    if result.success:
        print("Transaction finished for: ", product_id)

func _grant_purchase(product_id: String):
    match product_id:
        "com.yourgame.coins_100":
            GameState.add_coins(100)
        "com.yourgame.coins_500":
            GameState.add_coins(500)
        "com.yourgame.remove_ads":
            GameState.set_ads_removed(true)

func _is_consumable(product_id: String) -> bool:
    var consumables = ["com.yourgame.coins_100", "com.yourgame.coins_500"]
    return product_id in consumables
```

---

## 3. Subscription Implementation

### 3.1 Fetching Subscriptions

```gdscript
const SUBSCRIPTION_IDS = {
    "monthly": "com.yourgame.premium_monthly",
    "yearly": "com.yourgame.premium_yearly"
}

var subscriptions: Array = []

func fetch_subscriptions():
    var request = Types.ProductRequest.new()
    var skus: Array[String] = []
    for sku in SUBSCRIPTION_IDS.values():
        skus.append(sku)
    request.skus = skus
    request.type = Types.ProductQueryType.SUBS

    subscriptions = iap.fetch_products(request)

    for sub in subscriptions:
        print("Subscription: %s - %s" % [sub.title, get_subscription_price(sub)])
```

### 3.2 Getting Subscription Price

```gdscript
func get_subscription_price(subscription) -> String:
    # Typed object access
    if subscription is Object and subscription.display_price:
        return subscription.display_price

    # Dictionary fallback for iOS
    if OS.get_name() == "iOS":
        return subscription.get("displayPrice", "$9.99")

    # Android: Extract from subscription offers
    elif OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() > 0:
            var phases = offers[0].get("pricingPhases", {})
            var phase_list = phases.get("pricingPhaseList", [])
            if phase_list.size() > 0:
                return phase_list[0].get("formattedPrice", "$9.99")

    return "$9.99"
```

### 3.3 Purchasing a Subscription

```gdscript
func purchase_subscription(subscription_id: String):
    if not is_connected:
        push_error("Not connected to store")
        return

    var subscription = _find_subscription(subscription_id)
    if not subscription:
        push_error("Subscription not found")
        return

    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.type = Types.ProductQueryType.SUBS

    # Android configuration with offer token (required)
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    props.request.google.skus = [subscription_id]

    if OS.get_name() == "Android":
        var offers = subscription.get("subscriptionOfferDetailsAndroid", [])
        if offers.size() > 0:
            var sub_offers: Array[Types.SubscriptionOfferAndroid] = []
            var offer = Types.SubscriptionOfferAndroid.new()
            offer.sku = subscription_id
            offer.offer_token = offers[0].get("offerToken", "")
            sub_offers.append(offer)
            props.request.google.subscription_offers = sub_offers

    # iOS configuration
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = subscription_id

    iap.request_purchase(props)

func _find_subscription(subscription_id: String):
    for sub in subscriptions:
        var sub_id = sub.id if sub is Object else sub.get("id", "")
        if sub_id == subscription_id:
            return sub
    return null
```

### 3.4 Checking Subscription Status

```gdscript
func check_subscription_status() -> bool:
    var purchases = iap.get_available_purchases()

    for purchase in purchases:
        var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")

        if product_id in SUBSCRIPTION_IDS.values():
            if _is_subscription_active(purchase):
                GameState.set_premium(true)
                return true

    GameState.set_premium(false)
    return false

func _is_subscription_active(purchase) -> bool:
    var current_time = Time.get_unix_time_from_system() * 1000

    if OS.get_name() == "iOS":
        var expiration = 0
        if purchase is Object:
            expiration = purchase.expiration_date if "expiration_date" in purchase else 0
        else:
            expiration = purchase.get("expirationDateIOS", 0)

        if expiration > 0:
            return expiration > current_time

        # Sandbox testing: Consider recent purchases as active
        var environment = purchase.get("environmentIOS", "") if purchase is Dictionary else ""
        if environment == "Sandbox":
            var tx_date = purchase.get("transactionDate", 0)
            return (current_time - tx_date) < (24 * 60 * 60 * 1000)  # 1 day

    elif OS.get_name() == "Android":
        var auto_renewing = null
        if purchase is Object:
            auto_renewing = purchase.auto_renewing if "auto_renewing" in purchase else null
        else:
            auto_renewing = purchase.get("autoRenewingAndroid", null)

        if auto_renewing != null:
            return auto_renewing

        var state = purchase.get("purchaseState", "") if purchase is Dictionary else ""
        return state == "purchased" or state == "Purchased"

    return false
```

### 3.5 Opening Subscription Management

```gdscript
func manage_subscriptions():
    var options = Types.DeepLinkOptions.new()

    if OS.get_name() == "Android":
        options.package_name_android = ProjectSettings.get_setting(
            "application/config/package_name"
        )

    iap.deep_link_to_subscriptions(options)
```

---

## 4. Restoring Purchases

### 4.1 Basic Restore

```gdscript
func restore_purchases():
    if not is_connected:
        push_error("IAP not connected")
        return

    # Get all available (unfinished) purchases
    var purchases = iap.get_available_purchases()

    print("Found %d purchases to restore" % purchases.size())

    for purchase in purchases:
        await _process_restore(purchase)

func _process_restore(purchase):
    var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")

    print("Restoring: ", product_id)

    # Skip consumables (they can't be restored)
    if _is_consumable(product_id):
        return

    # Check subscriptions
    if _is_subscription(product_id):
        if not _is_subscription_active(purchase):
            print("Subscription expired, skipping")
            return

    # Grant content
    _grant_purchase(product_id)
    print("Restored: ", product_id)
```

### 4.2 Restore with UI Feedback

```gdscript
signal restore_completed(count: int)
signal restore_failed(error: String)

func restore_with_feedback():
    if not is_connected:
        restore_failed.emit("Store not available")
        return

    var purchases = iap.get_available_purchases()

    if purchases.size() == 0:
        restore_completed.emit(0)
        return

    var restored_count = 0

    for purchase in purchases:
        var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")

        if _is_consumable(product_id):
            continue

        if _is_subscription(product_id) and not _is_subscription_active(purchase):
            continue

        _grant_purchase(product_id)
        restored_count += 1

    restore_completed.emit(restored_count)

# In your UI:
func _on_restore_button_pressed():
    restore_button.disabled = true
    status_label.text = "Restoring..."

    IapManager.restore_completed.connect(_on_restore_done)
    IapManager.restore_failed.connect(_on_restore_error)
    IapManager.restore_with_feedback()

func _on_restore_done(count: int):
    restore_button.disabled = false
    if count > 0:
        status_label.text = "Restored %d purchases!" % count
    else:
        status_label.text = "No purchases to restore"

func _on_restore_error(error: String):
    restore_button.disabled = false
    status_label.text = "Restore failed: " + error
```

---

## 5. Complete Store UI

### 5.1 Store Manager (Autoload)

```gdscript
# store_manager.gd
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

var iap: Node
var is_connected: bool = false
var products: Dictionary = {}

const PRODUCT_IDS = {
    "coins_100": "com.yourgame.coins_100",
    "coins_500": "com.yourgame.coins_500",
    "remove_ads": "com.yourgame.remove_ads",
    "premium_monthly": "com.yourgame.premium_monthly"
}

signal connection_changed(connected: bool)
signal products_loaded(products: Array)
signal purchase_completed(product_id: String)
signal purchase_failed(error: Dictionary)

func _ready():
    _setup_iap()

func _setup_iap():
    var wrapper = preload("res://addons/godot-iap/godot_iap.gd").new()
    wrapper.name = "GodotIapWrapper"
    add_child(wrapper)
    iap = wrapper

    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

    is_connected = iap.init_connection()
    connection_changed.emit(is_connected)

    if is_connected:
        _fetch_products()
        _check_pending_purchases()

func _fetch_products():
    var request = Types.ProductRequest.new()
    request.skus = PRODUCT_IDS.values()
    request.type = Types.ProductQueryType.ALL

    var fetched = iap.fetch_products(request)
    _process_fetched_products(fetched)

func _process_fetched_products(fetched: Array):
    for product in fetched:
        products[product.id] = product
    products_loaded.emit(products.values())

func _check_pending_purchases():
    var purchases = iap.get_available_purchases()
    for purchase in purchases:
        await _process_purchase(purchase)

func _on_products_fetched(result: Dictionary):
    if result.has("products"):
        for product_dict in result["products"]:
            products[product_dict.get("id", "")] = product_dict
        products_loaded.emit(products.values())

func _on_purchase_updated(purchase: Dictionary):
    await _process_purchase_dict(purchase)

func _on_purchase_error(error: Dictionary):
    if error.get("code", "") != "USER_CANCELED":
        purchase_failed.emit(error)

func _process_purchase(purchase):
    var product_id = purchase.product_id if purchase is Object else purchase.get("productId", "")
    var state = purchase.purchase_state if purchase is Object else purchase.get("purchaseState", "")

    if state != "Purchased" and state != "purchased":
        return

    _grant_purchase(product_id)

    var is_consumable = _is_consumable(product_id)

    if purchase is Object:
        var input = Types.PurchaseInput.new()
        input.product_id = purchase.product_id
        input.purchase_token = purchase.purchase_token if "purchase_token" in purchase else ""
        input.transaction_id = purchase.transaction_id if "transaction_id" in purchase else ""
        iap.finish_transaction(input, is_consumable)
    else:
        iap.finish_transaction_dict(purchase, is_consumable)

    purchase_completed.emit(product_id)

func _process_purchase_dict(purchase: Dictionary):
    await _process_purchase(purchase)

func _grant_purchase(product_id: String):
    match product_id:
        "com.yourgame.coins_100":
            GameState.add_coins(100)
        "com.yourgame.coins_500":
            GameState.add_coins(500)
        "com.yourgame.remove_ads":
            GameState.set_ads_removed(true)
        "com.yourgame.premium_monthly":
            GameState.set_premium(true)

func _is_consumable(product_id: String) -> bool:
    return product_id in [PRODUCT_IDS.coins_100, PRODUCT_IDS.coins_500]

# Public API
func buy(product_id: String):
    if not is_connected:
        purchase_failed.emit({"code": "NOT_CONNECTED", "message": "Store not available"})
        return

    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()

    props.request.google = Types.RequestPurchaseAndroidProps.new()
    props.request.google.skus = [product_id]

    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id

    props.type = Types.ProductQueryType.IN_APP

    iap.request_purchase(props)

func get_product(product_id: String):
    return products.get(product_id, null)

func get_price(product_id: String) -> String:
    var product = get_product(product_id)
    if product == null:
        return "$0.99"
    return product.display_price if product is Object else product.get("displayPrice", "$0.99")

func restore():
    var result = iap.restore_purchases()
    return result.success if result else false
```

### 5.2 Store UI

```gdscript
# store_ui.gd
extends Control

@onready var product_list: VBoxContainer = $ProductList
@onready var loading_label: Label = $LoadingLabel
@onready var restore_button: Button = $RestoreButton

var product_button_scene = preload("res://ui/product_button.tscn")

func _ready():
    StoreManager.connection_changed.connect(_on_connection_changed)
    StoreManager.products_loaded.connect(_on_products_loaded)
    StoreManager.purchase_completed.connect(_on_purchase_completed)
    StoreManager.purchase_failed.connect(_on_purchase_failed)

    restore_button.pressed.connect(_on_restore_pressed)

    if StoreManager.is_connected:
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
    for child in product_list.get_children():
        child.queue_free()

    for product in products:
        var button = product_button_scene.instantiate()
        var product_id = product.id if product is Object else product.get("id", "")
        var title = product.title if product is Object else product.get("title", "")
        var price = product.display_price if product is Object else product.get("displayPrice", "")

        button.setup(product_id, title, price)
        button.pressed.connect(func(): _on_product_pressed(product_id))
        product_list.add_child(button)

func _on_product_pressed(product_id: String):
    _set_buttons_enabled(false)
    StoreManager.buy(product_id)

func _on_purchase_completed(product_id: String):
    _set_buttons_enabled(true)
    _show_dialog("Success", "Purchase completed!")

func _on_purchase_failed(error: Dictionary):
    _set_buttons_enabled(true)
    _show_dialog("Error", error.get("message", "Purchase failed"))

func _on_restore_pressed():
    _set_buttons_enabled(false)
    StoreManager.restore()
    await get_tree().create_timer(2.0).timeout
    _set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool):
    for child in product_list.get_children():
        if child is Button:
            child.disabled = not enabled
    restore_button.disabled = not enabled

func _show_dialog(title: String, message: String):
    var dialog = AcceptDialog.new()
    dialog.title = title
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)
```

### 5.3 Product Button

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

---

## Best Practices

1. **Always finish transactions**: Call `finish_transaction` or `finish_transaction_dict` after processing purchases
2. **Check pending purchases on startup**: Process any purchases that weren't finished
3. **Include restore button**: Required by Apple for non-consumable purchases
4. **Verify purchases server-side**: For production apps, verify receipts on your server
5. **Handle errors gracefully**: Show user-friendly messages for failures
6. **Test on real devices**: Sandbox/test mode required for IAP testing

## See Also

- [Full Documentation](https://hyochan.github.io/godot-iap)
- [API Reference](https://hyochan.github.io/godot-iap/api)
- [OpenIAP Specification](https://openiap.dev)
