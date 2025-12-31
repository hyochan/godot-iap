---
title: Available Purchases
sidebar_label: Available Purchases
sidebar_position: 3
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Available Purchases (Restore) Example

<IapKitBanner />

This example demonstrates how to implement purchase restoration for non-consumable products and subscriptions.

## Overview

Purchase restoration allows users to:
- Recover purchased content when reinstalling the app
- Sync purchases across multiple devices
- Restore access after clearing app data

:::info Apple Requirement
Apple requires all apps with non-consumable purchases or subscriptions to include a "Restore Purchases" button.
:::

## Complete Implementation

### RestorePurchases.gd

```gdscript
# restore_purchases.gd
extends Node

var iap: GodotIap = null

signal restore_completed(purchases: Array)
signal restore_failed(error: String)
signal restore_progress(current: int, total: int)

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")

func restore_all_purchases() -> Array:
    """Restore all non-consumable purchases and subscriptions"""
    if not iap:
        restore_failed.emit("IAP not available")
        return []

    print("Starting purchase restoration...")

    # Get all available purchases
    var purchases_json = iap.get_available_purchases()
    var purchases = JSON.parse_string(purchases_json)

    if purchases.size() == 0:
        print("No purchases to restore")
        restore_completed.emit([])
        return []

    print("Found %d purchases to restore" % purchases.size())

    var restored_purchases: Array = []
    var total = purchases.size()

    for i in range(total):
        var purchase = purchases[i]
        restore_progress.emit(i + 1, total)

        # Process each purchase
        var result = await _process_restore(purchase)
        if result:
            restored_purchases.append(purchase)

    print("Restored %d purchases" % restored_purchases.size())
    restore_completed.emit(restored_purchases)

    return restored_purchases

func _process_restore(purchase: Dictionary) -> bool:
    var product_id = purchase.productId
    print("Processing: ", product_id)

    # Check if already processed
    if _is_already_granted(product_id):
        print("  Already granted, skipping")
        return true

    # Verify purchase validity
    var is_valid = await _verify_purchase(purchase)
    if not is_valid:
        print("  Verification failed")
        return false

    # Check if subscription is still active
    if _is_subscription(product_id):
        if not _is_subscription_active(purchase):
            print("  Subscription expired")
            return false

    # Grant the content
    _grant_purchase(product_id)
    print("  Restored successfully")

    return true

func _verify_purchase(purchase: Dictionary) -> bool:
    """Verify purchase on your server"""
    # For development
    if OS.is_debug_build():
        return true

    # Production: Implement server verification
    # var response = await your_server.verify(purchase)
    # return response.is_valid

    return true

func _is_already_granted(product_id: String) -> bool:
    """Check if content is already granted"""
    match product_id:
        "com.yourgame.remove_ads":
            return GameState.ads_removed
        "com.yourgame.premium", "com.yourgame.premium_monthly", "com.yourgame.premium_yearly":
            return GameState.is_premium
        _:
            return false

func _is_subscription(product_id: String) -> bool:
    var subscription_ids = [
        "com.yourgame.premium_monthly",
        "com.yourgame.premium_yearly"
    ]
    return product_id in subscription_ids

func _is_subscription_active(purchase: Dictionary) -> bool:
    var current_time = Time.get_unix_time_from_system() * 1000

    if OS.get_name() == "iOS":
        var expiration = purchase.get("expirationDateIOS", 0)
        if expiration > 0:
            return expiration > current_time

        # Sandbox testing
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

func _grant_purchase(product_id: String):
    match product_id:
        "com.yourgame.remove_ads":
            GameState.set_ads_removed(true)

        "com.yourgame.premium", "com.yourgame.premium_monthly", "com.yourgame.premium_yearly":
            GameState.set_premium(true)

        _:
            print("Unknown product: ", product_id)
```

### RestoreUI.gd

```gdscript
# restore_ui.gd
extends Control

@onready var restore_button: Button = $RestoreButton
@onready var progress_label: Label = $ProgressLabel
@onready var status_label: Label = $StatusLabel

var restore_manager: Node

func _ready():
    restore_manager = RestorePurchases.new()
    add_child(restore_manager)

    # Connect signals
    restore_manager.restore_completed.connect(_on_restore_completed)
    restore_manager.restore_failed.connect(_on_restore_failed)
    restore_manager.restore_progress.connect(_on_restore_progress)

    # Connect button
    restore_button.pressed.connect(_on_restore_pressed)

    # Initial state
    progress_label.hide()

func _on_restore_pressed():
    restore_button.disabled = true
    progress_label.show()
    status_label.text = "Restoring purchases..."

    await restore_manager.restore_all_purchases()

func _on_restore_progress(current: int, total: int):
    progress_label.text = "Processing %d of %d..." % [current, total]

func _on_restore_completed(purchases: Array):
    restore_button.disabled = false
    progress_label.hide()

    if purchases.size() > 0:
        status_label.text = "Restored %d purchases!" % purchases.size()
        _show_restored_items(purchases)
    else:
        status_label.text = "No purchases found to restore."
        _show_dialog("No Purchases", "No previous purchases were found for this account.")

func _on_restore_failed(error: String):
    restore_button.disabled = false
    progress_label.hide()
    status_label.text = "Restore failed"

    _show_dialog("Error", "Failed to restore purchases: " + error)

func _show_restored_items(purchases: Array):
    var items = []
    for purchase in purchases:
        items.append("• " + _get_product_name(purchase.productId))

    var message = "Successfully restored:\n\n" + "\n".join(items)
    _show_dialog("Purchases Restored", message)

func _get_product_name(product_id: String) -> String:
    match product_id:
        "com.yourgame.remove_ads":
            return "Remove Ads"
        "com.yourgame.premium":
            return "Premium Upgrade"
        "com.yourgame.premium_monthly":
            return "Premium Monthly"
        "com.yourgame.premium_yearly":
            return "Premium Yearly"
        _:
            return product_id

func _show_dialog(title: String, message: String):
    var dialog = AcceptDialog.new()
    dialog.title = title
    dialog.dialog_text = message
    add_child(dialog)
    dialog.popup_centered()
    dialog.confirmed.connect(dialog.queue_free)
```

## Auto-Restore on Startup

Automatically check for purchases when the app starts:

```gdscript
# main.gd or autoload
extends Node

func _ready():
    # Wait for IAP to initialize
    if IapManager.is_connected:
        _check_purchases_on_startup()
    else:
        IapManager.connection_changed.connect(_on_iap_connected)

func _on_iap_connected(connected: bool):
    if connected:
        _check_purchases_on_startup()

func _check_purchases_on_startup():
    print("Checking for existing purchases...")

    var iap = Engine.get_singleton("GodotIap")
    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        # Only process non-consumables and active subscriptions
        if _should_restore(purchase):
            _restore_silently(purchase)

func _should_restore(purchase: Dictionary) -> bool:
    var product_id = purchase.productId

    # Skip consumables
    if _is_consumable(product_id):
        return false

    # Check subscriptions
    if _is_subscription(product_id):
        return _is_subscription_active(purchase)

    return true

func _restore_silently(purchase: Dictionary):
    # Grant without showing UI
    var product_id = purchase.productId

    match product_id:
        "com.yourgame.remove_ads":
            if not GameState.ads_removed:
                GameState.set_ads_removed(true)
                print("Silently restored: Remove Ads")

        "com.yourgame.premium_monthly", "com.yourgame.premium_yearly":
            if not GameState.is_premium:
                GameState.set_premium(true)
                print("Silently restored: Premium")
```

## Platform-Specific Behavior

### iOS Behavior

```gdscript
func restore_ios():
    # iOS returns all non-consumable purchases ever made
    # Filter by what's still valid

    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        # Check subscription expiration
        if _is_subscription(purchase.productId):
            var expiration = purchase.get("expirationDateIOS", 0)
            var now = Time.get_unix_time_from_system() * 1000

            if expiration > 0 and expiration < now:
                print("Subscription expired: ", purchase.productId)
                continue

        # Verify and grant
        _grant_purchase(purchase.productId)
```

### Android Behavior

```gdscript
func restore_android():
    # Android queries both in-app and subscription purchases
    # Already filtered by purchase state

    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        var state = purchase.get("purchaseState", "")

        if state != "purchased":
            continue

        # Check if acknowledged (unacknowledged = pending completion)
        var acknowledged = purchase.get("isAcknowledgedAndroid", false)

        if not acknowledged:
            # This purchase wasn't properly finished before
            print("Found unfinished purchase: ", purchase.productId)
            # Process and finish it
            await _complete_pending_purchase(purchase)
        else:
            # Already acknowledged, just restore
            _grant_purchase(purchase.productId)
```

## Error Handling

```gdscript
func restore_with_error_handling():
    var iap = Engine.get_singleton("GodotIap")

    if not iap:
        _show_error("Store not available. Please try again later.")
        return

    # Check connection first
    var result = JSON.parse_string(iap.init_connection())
    if not result.get("success", false):
        _show_error("Cannot connect to store. Please check your internet connection.")
        return

    # Get purchases
    var purchases_json = iap.get_available_purchases()
    var purchases = JSON.parse_string(purchases_json)

    if typeof(purchases) != TYPE_ARRAY:
        _show_error("Failed to retrieve purchases.")
        return

    if purchases.size() == 0:
        _show_info("No purchases found for this account.")
        return

    # Process purchases
    var restored = 0
    var failed = 0

    for purchase in purchases:
        var success = await _try_restore(purchase)
        if success:
            restored += 1
        else:
            failed += 1

    # Show result
    if failed > 0:
        _show_warning("Restored %d purchases. %d failed to restore." % [restored, failed])
    elif restored > 0:
        _show_success("Successfully restored %d purchases!" % restored)
    else:
        _show_info("No new purchases to restore.")
```

## Best Practices

1. **Always include restore button**: Required by Apple for apps with non-consumables

2. **Auto-restore on startup**: Check for purchases silently when app starts

3. **Verify purchases**: Always verify on your server in production

4. **Handle subscriptions correctly**: Check expiration dates

5. **Show progress**: For multiple purchases, show restoration progress

6. **Handle errors gracefully**: Network issues, invalid purchases, etc.

## See Also

- [Purchase Flow Example](./purchase-flow) - Basic purchase implementation
- [Subscription Flow Example](./subscription-flow) - Subscription handling
- [Purchases Guide](../guides/purchases) - Detailed documentation
