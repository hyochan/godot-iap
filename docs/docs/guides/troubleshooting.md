---
title: Troubleshooting
sidebar_label: Troubleshooting
sidebar_position: 5
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Troubleshooting

<IapKitBanner />

This guide covers common issues you might encounter when implementing in-app purchases with GodotIap and how to resolve them.

## Prerequisites Checklist

Before diving into troubleshooting, ensure you have completed these essential steps:

### App Store Setup (iOS)

- [ ] **Agreements**: Completed all agreements, tax, and banking information in App Store Connect
- [ ] **Sandbox Account**: Created sandbox testing accounts in "Users and Roles"
- [ ] **Device Setup**: Signed into iOS device with sandbox account
- [ ] **Products Created**: Set up In-App Purchase products with status "Ready to Submit"
- [ ] **StoreKit Capability**: Added StoreKit capability in Xcode

### Google Play Setup (Android)

- [ ] **Play Console**: Completed all required information in Google Play Console
- [ ] **Test Accounts**: Added test accounts to your app's testing track
- [ ] **Signed Build**: Using signed APK/AAB (not debug builds)
- [ ] **Upload**: Uploaded at least one version to internal testing
- [ ] **Products Active**: Products are set to "Active" status

## Common Issues

### `fetch_products()` Returns Empty Array

This is one of the most common issues. Here are the potential causes and solutions:

#### 1. Connection Not Established

```gdscript
var is_connected: bool = false

func _initialize():
    var result = JSON.parse_string(iap.init_connection())

    if result.get("success", false):
        is_connected = true
        # Only fetch products AFTER successful connection
        _load_products()
    else:
        print("Connection failed: ", result.get("error", ""))

func _load_products():
    if not is_connected:
        print("Cannot fetch products - not connected")
        return

    var product_ids = ["coins_100", "premium"]
    iap.fetch_products(JSON.stringify(product_ids), "inapp")
```

#### 2. Product IDs Don't Match

Ensure your product IDs exactly match those configured in the stores:

```gdscript
# Wrong: Using different IDs
var product_ids = ["my_product_1", "my_product_2"]

# Correct: Using exact IDs from store
var product_ids = ["com.yourapp.coins_100", "com.yourapp.premium"]
```

#### 3. Products Not Approved (iOS)

Products need time to propagate through Apple's systems:

- Wait up to 24 hours after creating products
- Ensure products are in "Ready to Submit" status
- Test with sandbox accounts

#### 4. App Not Uploaded to Play Console (Android)

For Android, your app must be uploaded to Play Console:

```bash
# Export signed APK from Godot
# Upload to Play Console internal testing track
```

### Plugin Not Found

#### 1. Check if Singleton Exists

```gdscript
func _ready():
    if not Engine.has_singleton("GodotIap"):
        print("GodotIap plugin not available!")
        print("Make sure the plugin is enabled in export settings")
        return

    iap = Engine.get_singleton("GodotIap")
```

#### 2. Verify Export Settings

**Android:**
1. Go to Project → Export
2. Select Android preset
3. Scroll to "Plugins"
4. Ensure "GodotIap" is checked

**iOS:**
1. Build the plugin using `swift build`
2. Copy framework to your Xcode project
3. Ensure framework is linked

### Purchase Flow Issues

#### 1. Purchases Not Completing

Always handle purchase updates and finish transactions:

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")

    if state == "purchased":
        # Validate receipt on your server
        var is_valid = await validate_on_server(purchase)

        if is_valid:
            # Grant purchase to user
            grant_purchase(purchase.productId)

            # ALWAYS finish the transaction
            var params = {
                "purchase": purchase,
                "isConsumable": is_consumable(purchase.productId)
            }
            iap.finish_transaction(JSON.stringify(params))
```

**Important - Transaction Acknowledgment Requirements:**

- **iOS**: Unfinished transactions remain in the queue indefinitely until `finish_transaction` is called
- **Android**: Purchases must be acknowledged within **3 days (72 hours)** or they will be **automatically refunded**

#### 2. `purchase_updated` Signal Triggering on App Restart

This happens when transactions are not properly finished. The store replays unfinished transactions on app startup.

**Problem**: Your `purchase_updated` signal fires automatically every time the app starts.

**Cause**: You didn't call `finish_transaction` after processing the purchase.

**Solution**: Always call `finish_transaction` after successfully processing:

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    if purchase.purchaseState == "purchased":
        # 1. Validate on server
        var is_valid = await validate_on_server(purchase)
        if not is_valid:
            print("Invalid purchase")
            return

        # 2. Process the purchase
        await process_purchase(purchase)

        # 3. FINISH THE TRANSACTION
        var params = {
            "purchase": purchase,
            "isConsumable": is_consumable(purchase.productId)
        }
        iap.finish_transaction(JSON.stringify(params))
```

**Handle pending transactions on startup:**

```gdscript
func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        # Check for pending purchases FIRST
        _check_pending_purchases()
        # Then load products
        _load_products()

func _check_pending_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())

    for purchase in purchases:
        if await is_already_processed(purchase):
            # Just finish the transaction
            var params = {"purchase": purchase, "isConsumable": false}
            iap.finish_transaction(JSON.stringify(params))
        else:
            # Process then finish
            await process_purchase(purchase)
            var params = {"purchase": purchase, "isConsumable": is_consumable(purchase.productId)}
            iap.finish_transaction(JSON.stringify(params))
```

### Connection Issues

#### 1. Network Connectivity

Handle network errors gracefully:

```gdscript
func _initialize():
    var result = JSON.parse_string(iap.init_connection())

    if not result.get("success", false):
        var error = result.get("error", "")

        if "network" in error.to_lower():
            show_retry_dialog("Network error. Please check your connection.")
        else:
            show_error("Failed to connect to store: " + error)

func show_retry_dialog(message: String):
    # Show dialog with retry button
    # On retry: call _initialize() again
    pass
```

#### 2. Store Service Unavailable

Sometimes store services are temporarily unavailable:

```gdscript
func handle_store_unavailable():
    var dialog = AcceptDialog.new()
    dialog.title = "Store Unavailable"
    dialog.dialog_text = "The store is temporarily unavailable. Please try again later."
    add_child(dialog)
    dialog.popup_centered()
```

### Platform-Specific Issues

#### iOS Issues

1. **Invalid Product ID Error**

```gdscript
# Ensure:
# - Signed in with sandbox account on device
# - Product IDs match exactly (case-sensitive)
# - App bundle ID matches App Store Connect
# - Products are in "Ready to Submit" status
```

2. **StoreKit Configuration**

```
# In Xcode:
# - Add StoreKit capability
# - For iOS 15+, ensure SwiftUI is available
```

3. **Sandbox Testing**

```gdscript
# For iOS sandbox testing:
# 1. Sign out of App Store on device
# 2. Don't sign in until prompted during purchase
# 3. Use sandbox account credentials when prompted
```

#### Android Issues

1. **Billing Client Setup**

```gradle
// android/build.gradle.kts
dependencies {
    implementation("com.android.billingclient:billing:7.0.0")
}
```

2. **License Testing**

```gdscript
# For Android testing:
# 1. Add your test account email to Google Play Console
# 2. Go to Settings → License testing
# 3. Add the Gmail accounts
# 4. Testers can purchase without being charged
```

3. **Version Code Issues**

```gdscript
# Ensure:
# - App is uploaded to Play Console (at least internal track)
# - Version code matches or exceeds uploaded version
# - Test device uses account added to testing track
```

4. **Service Disconnected**

```gdscript
func _on_purchase_error(error: Dictionary):
    if error.get("code") == "SERVICE_DISCONNECTED":
        # Attempt to reconnect
        var result = JSON.parse_string(iap.init_connection())
        if result.get("success", false):
            print("Reconnected to Google Play")
```

## Debugging Tips

### 1. Enable Verbose Logging

```gdscript
func _on_purchase_updated(purchase: Dictionary):
    print("=== Purchase Updated ===")
    print(JSON.stringify(purchase, "\t"))
    print("========================")

func _on_purchase_error(error: Dictionary):
    print("=== Purchase Error ===")
    print(JSON.stringify(error, "\t"))
    print("======================")

func _on_products_fetched(products: Array):
    print("=== Products Fetched ===")
    for product in products:
        print(JSON.stringify(product, "\t"))
    print("========================")
```

### 2. Monitor Connection State

```gdscript
var is_connected: bool = false

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    is_connected = result.get("success", false)

    print("Connection state: ", "Connected" if is_connected else "Disconnected")

    if not is_connected:
        print("Connection error: ", result.get("error", "Unknown"))
```

### 3. Check Device Logs

**Android (adb logcat):**
```bash
adb logcat | grep -i "GodotIap\|BillingClient\|Purchase"
```

**iOS (Xcode Console):**
Look for StoreKit-related logs in Xcode's debug console.

## Testing Strategies

### 1. Staged Testing Approach

1. **Development**: Test IAP logic without actual store calls
2. **Sandbox Testing**: Use store sandbox/test accounts
3. **Internal Testing**: Test with real store in closed testing
4. **Production**: Final verification in live environment

### 2. Test Different Scenarios

```gdscript
# Test scenarios to cover:
var test_scenarios = [
    "successful_purchase",
    "user_cancelled",
    "network_error",
    "item_already_owned",
    "product_unavailable",
    "pending_purchase",
    "restore_purchases"
]
```

### 3. Device Testing Matrix

Test on various devices:

- **iOS**: Different iPhone/iPad models, iOS versions
- **Android**: Different manufacturers, Android versions, Play Services versions

## Error Code Reference

| Code | Description | Recommended Action |
|------|-------------|-------------------|
| `USER_CANCELED` | User cancelled purchase | No action needed |
| `NETWORK_ERROR` | Network connectivity issue | Show retry option |
| `ITEM_UNAVAILABLE` | Product not available | Check product setup |
| `ITEM_ALREADY_OWNED` | User already owns product | Restore purchase |
| `ITEM_NOT_OWNED` | Item not owned | Check purchase status |
| `PAYMENT_INVALID` | Payment method issue | Direct to settings |
| `PAYMENT_NOT_ALLOWED` | Payments disabled | Show message |
| `BILLING_UNAVAILABLE` | Store unavailable | Show retry later |
| `DEVELOPER_ERROR` | Configuration error | Check setup |

## Getting Help

If you're still experiencing issues:

1. **Check logs**: Review device logs and console output
2. **Search issues**: Check the [GitHub issues](https://github.com/hyochan/godot-iap/issues)
3. **Minimal reproduction**: Create a minimal example that reproduces the issue
4. **Report bug**: File a detailed issue with reproduction steps

### Bug Report Template

```markdown
**Environment:**
- godot-iap version: x.x.x
- Godot version: x.x.x
- Platform: iOS/Android
- OS version: x.x.x
- Device: Device model

**Description:**
Clear description of the issue

**Steps to reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected behavior:**
What should happen

**Actual behavior:**
What actually happens

**Logs:**
Relevant logs and error messages
```

## See Also

- [Error Handling Guide](./error-handling) - Error handling best practices
- [Purchases Guide](./purchases) - Purchase implementation
- [API Reference](../api/) - Detailed method documentation
