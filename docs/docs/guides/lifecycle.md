---
title: Lifecycle
sidebar_label: Lifecycle
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Lifecycle

<IapKitBanner />

For complete understanding of the in-app purchase lifecycle, flow diagrams, and state management, please visit:

**[Lifecycle Documentation - openiap.dev](https://openiap.dev/docs/lifecycle)**

![Purchase Flow](https://openiap.dev/purchase-flow.png)

The Open IAP specification provides detailed documentation on:

- Complete purchase flow
- State transitions and management
- Connection lifecycle
- Error recovery patterns
- Platform-specific considerations

## Implementation with GodotIap

## Connection Management

Understanding the connection lifecycle is crucial for reliable IAP implementation.

### Connection States

The connection can be in several states:

- **Disconnected**: Initial state, no connection to store
- **Connecting**: Attempting to establish connection
- **Connected**: Successfully connected, ready for operations
- **Error**: Connection failed

### Basic Connection Flow

```gdscript
extends Node

var iap: GodotIap
var is_connected: bool = false

func _ready():
    if not Engine.has_singleton("GodotIap"):
        print("GodotIap not available")
        return

    iap = Engine.get_singleton("GodotIap")
    _setup_signals()
    _initialize_connection()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _initialize_connection():
    var result = JSON.parse_string(iap.init_connection())

    if result.get("success", false):
        is_connected = true
        print("Connected to store")
        _load_products()
    else:
        print("Failed to connect: ", result.get("error", ""))

func _load_products():
    if is_connected:
        var product_ids = ["coins_100", "premium"]
        iap.fetch_products(JSON.stringify(product_ids), "inapp")
```

### Handling Connection States

```gdscript
var connection_error: String = ""

func _initialize_connection():
    var result = JSON.parse_string(iap.init_connection())

    if result.get("success", false):
        is_connected = true
        connection_error = ""
        _on_connected()
    else:
        is_connected = false
        connection_error = result.get("error", "Unknown error")
        _on_connection_failed()

func _on_connected():
    print("Store connected, loading products...")
    _load_products()

func _on_connection_failed():
    print("Connection failed: ", connection_error)
    # Show retry UI to user
    show_retry_button()

func retry_connection():
    print("Retrying connection...")
    _initialize_connection()
```

## Component Lifecycle Integration

### Scene Lifecycle

```gdscript
extends Node

var iap: GodotIap

func _ready():
    # Initialize IAP when scene loads
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()

func _exit_tree():
    # Clean up when scene is removed
    if iap:
        # Disconnect signals if needed
        if iap.purchase_updated.is_connected(_on_purchase_updated):
            iap.purchase_updated.disconnect(_on_purchase_updated)
        if iap.purchase_error.is_connected(_on_purchase_error):
            iap.purchase_error.disconnect(_on_purchase_error)

        # End connection
        iap.end_connection()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        _load_products()

func _on_purchase_updated(purchase: Dictionary):
    # Handle purchase updates
    pass

func _on_purchase_error(error: Dictionary):
    # Handle purchase errors
    pass

func _on_products_fetched(products: Array):
    # Handle fetched products
    pass
```

### Autoload Pattern (Recommended)

For persistent IAP management, use an Autoload singleton:

```gdscript
# iap_manager.gd - Add this as an Autoload
extends Node

var iap: GodotIap
var is_connected: bool = false
var products: Array = []
var subscriptions: Array = []

signal iap_connected
signal iap_disconnected
signal iap_error(error: Dictionary)
signal products_loaded(products: Array)
signal purchase_completed(purchase: Dictionary)
signal purchase_failed(error: Dictionary)

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()
    else:
        push_warning("GodotIap singleton not available")

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)
    iap.subscriptions_fetched.connect(_on_subscriptions_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        is_connected = true
        iap_connected.emit()
    else:
        iap_error.emit({"message": result.get("error", "")})

func _on_purchase_updated(purchase: Dictionary):
    purchase_completed.emit(purchase)

func _on_purchase_error(error: Dictionary):
    purchase_failed.emit(error)

func _on_products_fetched(fetched_products: Array):
    products = fetched_products
    products_loaded.emit(products)

func _on_subscriptions_fetched(fetched_subs: Array):
    subscriptions = fetched_subs

# Public API
func load_products(product_ids: Array):
    if is_connected:
        iap.fetch_products(JSON.stringify(product_ids), "inapp")

func load_subscriptions(sub_ids: Array):
    if is_connected:
        iap.fetch_subscriptions(JSON.stringify(sub_ids))

func buy(product_id: String, type: String = "inapp"):
    if is_connected:
        var params = {"sku": product_id, "type": type}
        iap.request_purchase(JSON.stringify(params))

func restore():
    if is_connected:
        return JSON.parse_string(iap.get_available_purchases())
    return []
```

Usage in other scenes:

```gdscript
# In any scene
extends Control

func _ready():
    # Connect to the autoload signals
    IapManager.products_loaded.connect(_on_products_loaded)
    IapManager.purchase_completed.connect(_on_purchase_completed)

    # Wait for connection
    if IapManager.is_connected:
        _load_store()
    else:
        IapManager.iap_connected.connect(_on_iap_connected)

func _on_iap_connected():
    _load_store()

func _load_store():
    IapManager.load_products(["coins_100", "premium"])

func _on_products_loaded(products: Array):
    update_store_ui(products)

func _on_purchase_completed(purchase: Dictionary):
    handle_purchase(purchase)
```

## Best Practices

### Do

1. **Initialize early**: Connect to store as early as possible in app lifecycle
2. **Handle connection states**: Provide feedback to users about connection status
3. **Use Autoload for persistence**: Keep IAP manager as singleton
4. **Clean up properly**: Always remove listeners and end connections

```gdscript
# Good: Using Autoload pattern
func _ready():
    if IapManager.is_connected:
        load_store()
```

### Don't

1. **Initialize repeatedly**: Don't call init_connection/end_connection for every operation
2. **Ignore connection state**: Don't attempt store operations when disconnected
3. **Forget cleanup**: Always clean up listeners to prevent issues

```gdscript
# Bad: Initializing for every operation
func bad_purchase_flow(product_id: String):
    iap.init_connection()  # Don't do this
    iap.request_purchase(JSON.stringify({"sku": product_id}))
    iap.end_connection()   # Don't do this

# Good: Use existing connection
func good_purchase_flow(product_id: String):
    if is_connected:
        iap.request_purchase(JSON.stringify({"sku": product_id}))
```

## Purchase Flow Best Practices

### Purchase Verification and Security

1. **Server-side verification recommended**: For production apps, verify purchases on your secure server before granting content.

2. **Finish transactions after verification**: Always call `finish_transaction` after successfully verifying a purchase.

3. **Never trust client-side data**: Always verify purchases server-side before granting premium content.

### Purchase State Management

4. **Handle all purchase states**: Including pending, failed, restored, and cancelled purchases.

5. **Handle pending purchases**: Some purchases may require approval and remain in pending state.

6. **Restore purchases properly**: Implement purchase restoration for non-consumable products and subscriptions.

### Error Handling and User Experience

7. **Implement comprehensive error handling**: Provide meaningful feedback for different error scenarios.

8. **Graceful degradation**: Your app should work even if purchases fail.

9. **User feedback**: Keep users informed about purchase status.

### Testing and Development

10. **Test thoroughly**: Use real devices and official test accounts.

11. **Monitor purchase flow**: Log important events for debugging.

## Common Pitfalls and Solutions

### Transaction Management Issues

**Not finishing transactions:**

```gdscript
# Wrong - forgetting to finish transaction
func handle_purchase(purchase: Dictionary):
    var verified = await validate_receipt(purchase)
    # Missing: finish_transaction call
```

**Always finish transactions after validation:**

```gdscript
# Correct - always finish transaction
func handle_purchase(purchase: Dictionary):
    var verified = await validate_receipt(purchase)
    if verified:
        grant_content(purchase.productId)
        var params = {
            "purchase": purchase,
            "isConsumable": is_consumable(purchase.productId)
        }
        iap.finish_transaction(JSON.stringify(params))
```

### Security Issues

**Trusting client-side validation:**

```gdscript
# Wrong - never trust client-side validation alone
func handle_purchase(purchase: Dictionary):
    grant_premium_feature()  # Not secure
```

**Always validate server-side:**

```gdscript
# Correct - validate on secure server
func handle_purchase(purchase: Dictionary):
    var is_valid = await your_api.validate_receipt(purchase.purchaseToken)
    if is_valid:
        grant_premium_feature()
        finish_transaction(purchase)
```

### App Lifecycle Issues

**Not handling app restarts:**

Purchases can complete after app restart, so always check for pending purchases on launch:

```gdscript
# Correct - check for purchases on app launch
func _ready():
    # After connection established
    if is_connected:
        check_pending_purchases()

func check_pending_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())
    for purchase in purchases:
        await process_purchase(purchase)
```

### Connection Management Issues

**Initializing connection repeatedly:**

```gdscript
# Wrong - don't initialize for every operation
func purchase_product(sku: String):
    iap.init_connection()  # Don't do this
    iap.request_purchase(...)
    iap.end_connection()   # Don't do this
```

**Maintain single connection:**

```gdscript
# Correct - use existing connection
func purchase_product(sku: String):
    if is_connected:
        iap.request_purchase(...)
    else:
        print("Store not connected")
```

## Next Steps

- Review [Purchase Implementation Guide](./purchases) for detailed code examples
- Check out [Error Handling Guide](./error-handling) for debugging tips
- See [API Reference](../api/) for detailed method documentation
