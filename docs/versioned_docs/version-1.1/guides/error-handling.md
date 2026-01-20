---
title: Error Handling
sidebar_label: Error Handling
sidebar_position: 3
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Error Handling

<IapKitBanner />

This guide covers best practices for handling errors in your GodotIap implementation.

## Overview

GodotIap provides comprehensive error handling through standardized error codes and messages. All errors are returned as structured dictionaries with consistent properties across iOS and Android platforms.

## Error Structure

```gdscript
# Error Dictionary Structure
{
    "code": "USER_CANCELED",
    "message": "User cancelled the purchase",
    "debugMessage": "Additional debug information",  # Optional
    "domain": "SKErrorDomain"  # iOS only
}
```

## Common Error Codes

| Code | Description | Recommended Action |
|------|-------------|-------------------|
| `USER_CANCELED` | User cancelled purchase | No action needed |
| `NETWORK_ERROR` | Network connectivity issue | Show retry option |
| `ITEM_UNAVAILABLE` | Product not available | Check product setup |
| `ITEM_ALREADY_OWNED` | User already owns product | Restore purchase |
| `ITEM_NOT_OWNED` | Item not owned (consume/acknowledge) | Check purchase status |
| `PAYMENT_INVALID` | Payment information invalid | Direct to payment settings |
| `PAYMENT_NOT_ALLOWED` | Payments disabled on device | Show message |
| `BILLING_UNAVAILABLE` | Billing service unavailable | Show retry option |
| `DEVELOPER_ERROR` | Configuration error | Check setup |
| `UNKNOWN` | Unknown error | Log for investigation |

## Basic Error Handling

```gdscript
extends Node

var iap: GodotIap

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        iap.purchase_error.connect(_on_purchase_error)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")
    var message = error.get("message", "")

    match code:
        "USER_CANCELED":
            # User cancelled - no action needed
            print("Purchase cancelled by user")

        "NETWORK_ERROR":
            # Network issue - offer retry
            show_error_with_retry("Network error. Please check your connection.")

        "ITEM_UNAVAILABLE":
            # Product not available
            show_error("This product is currently unavailable.")

        "ITEM_ALREADY_OWNED":
            # User already owns this
            show_error("You already own this product.")
            restore_purchases()

        "PAYMENT_INVALID":
            # Payment method issue
            show_error("Payment was invalid. Please check your payment method.")

        "PAYMENT_NOT_ALLOWED":
            # Payments disabled
            show_error("Payments are not allowed on this device.")

        "BILLING_UNAVAILABLE":
            # Store unavailable
            show_error("Store is temporarily unavailable. Please try again later.")

        _:
            # Generic error
            show_error("Purchase failed: " + message)
            log_error(error)
```

## Error Recovery Strategies

### Retry Logic

Implement exponential backoff for transient errors:

```gdscript
var retry_count: int = 0
var max_retries: int = 3

func purchase_with_retry(product_id: String):
    retry_count = 0
    _attempt_purchase(product_id)

func _attempt_purchase(product_id: String):
    var params = {"sku": product_id, "type": "inapp"}
    iap.request_purchase(JSON.stringify(params))

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    # Only retry on transient errors
    if code in ["NETWORK_ERROR", "BILLING_UNAVAILABLE"]:
        if retry_count < max_retries:
            retry_count += 1
            var delay = pow(2, retry_count)  # Exponential backoff
            print("Retrying in %d seconds..." % delay)
            await get_tree().create_timer(delay).timeout
            _attempt_purchase(last_product_id)
        else:
            show_error("Purchase failed after multiple attempts. Please try again later.")
    else:
        # Non-retriable error
        handle_error(error)
```

### Graceful Degradation

Provide fallback experiences:

```gdscript
func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    match code:
        "BILLING_UNAVAILABLE", "PAYMENT_NOT_ALLOWED":
            # Redirect to alternative purchase method
            show_web_purchase_option()

        "ITEM_UNAVAILABLE":
            # Show alternative products
            show_alternative_products()

        "ITEM_ALREADY_OWNED":
            # Restore purchase
            restore_purchases()

        _:
            show_generic_error(error)

func show_web_purchase_option():
    # Open web browser for purchase
    OS.shell_open("https://your-store.com/purchase")
```

## Platform-Specific Error Handling

### iOS-Specific Errors

```gdscript
func handle_ios_error(error: Dictionary):
    var code = error.get("code", "")
    var domain = error.get("domain", "")

    if domain == "SKErrorDomain":
        match code:
            "0":  # SKErrorUnknown
                log_error("Unknown StoreKit error")
            "1":  # SKErrorClientInvalid
                show_error("This device is not allowed to make purchases")
            "2":  # SKErrorPaymentCancelled
                pass  # User cancelled
            "3":  # SKErrorPaymentInvalid
                show_error("Invalid payment information")
            "4":  # SKErrorPaymentNotAllowed
                show_error("Payments are not allowed on this device")
            "5":  # SKErrorStoreProductNotAvailable
                show_error("Product not available in your region")
```

### Android-Specific Errors

```gdscript
func handle_android_error(error: Dictionary):
    var code = error.get("code", "")

    match code:
        "SERVICE_TIMEOUT":
            show_error_with_retry("Connection timeout. Please try again.")

        "FEATURE_NOT_SUPPORTED":
            show_error("This feature is not supported on your device.")

        "SERVICE_DISCONNECTED":
            # Attempt to reconnect
            reconnect_to_store()

        "SERVICE_UNAVAILABLE":
            show_error_with_retry("Store service unavailable. Please try again.")

        "BILLING_UNAVAILABLE":
            show_error("Google Play Billing is not available.")

        "DEVELOPER_ERROR":
            # Log for debugging
            log_error(error)
            show_error("Configuration error. Please contact support.")

func reconnect_to_store():
    # Re-initialize connection
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        print("Reconnected to store")
    else:
        show_error("Failed to reconnect to store")
```

## User-Friendly Messages

Convert technical errors to user-friendly messages:

```gdscript
func get_user_friendly_message(error: Dictionary) -> String:
    var code = error.get("code", "")

    match code:
        "USER_CANCELED":
            return ""  # Don't show message for user cancellation

        "NETWORK_ERROR":
            return "Please check your internet connection and try again."

        "ITEM_UNAVAILABLE":
            return "This item is currently unavailable. Please try again later."

        "ITEM_ALREADY_OWNED":
            return "You already own this item. Tap 'Restore Purchases' to restore it."

        "PAYMENT_INVALID":
            return "There was an issue with your payment method. Please check your settings."

        "PAYMENT_NOT_ALLOWED":
            return "Purchases are not allowed on this device."

        "BILLING_UNAVAILABLE":
            return "The store is temporarily unavailable. Please try again later."

        _:
            return "Something went wrong. Please try again later."

func show_error_if_needed(error: Dictionary):
    var message = get_user_friendly_message(error)
    if message != "":
        show_error_dialog(message)
```

## Logging and Analytics

Track errors for debugging and analytics:

```gdscript
func log_error(error: Dictionary):
    var log_data = {
        "error_code": error.get("code", ""),
        "error_message": error.get("message", ""),
        "debug_message": error.get("debugMessage", ""),
        "platform": OS.get_name(),
        "timestamp": Time.get_unix_time_from_system()
    }

    # Log to console
    print("IAP Error: ", JSON.stringify(log_data))

    # Send to analytics service
    send_to_analytics("iap_error", log_data)

func send_to_analytics(event_name: String, data: Dictionary):
    # Implement your analytics integration
    # Example: Firebase, custom backend, etc.
    pass
```

## Complete Error Handler

```gdscript
extends Node

var iap: GodotIap
var last_product_id: String = ""
var retry_count: int = 0
const MAX_RETRIES = 3

signal purchase_error_handled(error: Dictionary)

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        iap.purchase_error.connect(_on_purchase_error)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    # Log all errors
    log_error(error)

    # Handle based on error type
    match code:
        "USER_CANCELED":
            # Silent - user intentionally cancelled
            pass

        "NETWORK_ERROR", "SERVICE_TIMEOUT", "SERVICE_UNAVAILABLE":
            _handle_transient_error(error)

        "ITEM_ALREADY_OWNED":
            _handle_already_owned(error)

        "BILLING_UNAVAILABLE", "PAYMENT_NOT_ALLOWED":
            _handle_billing_unavailable(error)

        "DEVELOPER_ERROR":
            _handle_developer_error(error)

        _:
            _handle_generic_error(error)

    purchase_error_handled.emit(error)

func _handle_transient_error(error: Dictionary):
    if retry_count < MAX_RETRIES:
        retry_count += 1
        show_retry_dialog(
            "Connection issue",
            "Please check your connection and try again.",
            func(): _retry_purchase()
        )
    else:
        show_error_dialog("Unable to complete purchase. Please try again later.")
        retry_count = 0

func _handle_already_owned(error: Dictionary):
    show_info_dialog(
        "Already Owned",
        "You already own this item. Would you like to restore your purchases?",
        func(): restore_purchases()
    )

func _handle_billing_unavailable(error: Dictionary):
    show_error_dialog(
        "Purchases are currently unavailable. Please try again later or visit our website."
    )

func _handle_developer_error(error: Dictionary):
    # Don't expose technical details to user
    push_error("IAP Developer Error: " + JSON.stringify(error))
    show_error_dialog("An error occurred. Please contact support.")

func _handle_generic_error(error: Dictionary):
    var message = get_user_friendly_message(error)
    if message != "":
        show_error_dialog(message)

func _retry_purchase():
    if last_product_id != "":
        var params = {"sku": last_product_id, "type": "inapp"}
        iap.request_purchase(JSON.stringify(params))

# Helper functions
func show_error_dialog(message: String):
    # Implement your dialog system
    pass

func show_info_dialog(title: String, message: String, confirm_callback: Callable):
    # Implement your dialog system
    pass

func show_retry_dialog(title: String, message: String, retry_callback: Callable):
    # Implement your dialog system
    pass

func restore_purchases():
    var purchases = JSON.parse_string(iap.get_available_purchases())
    for purchase in purchases:
        # Process each purchase
        pass

func log_error(error: Dictionary):
    print("IAP Error: ", JSON.stringify(error))

func get_user_friendly_message(error: Dictionary) -> String:
    var code = error.get("code", "")
    match code:
        "NETWORK_ERROR":
            return "Please check your internet connection."
        "ITEM_UNAVAILABLE":
            return "This item is not available."
        "PAYMENT_INVALID":
            return "Payment method issue."
        _:
            return "Something went wrong."
```

## Best Practices

### 1. Always Handle Errors

Never leave IAP operations without error handling:

```gdscript
# Bad - no error handling
func buy(product_id: String):
    iap.request_purchase(JSON.stringify({"sku": product_id}))

# Good - proper error handling
func buy(product_id: String):
    if not is_connected:
        show_error("Store not connected")
        return

    last_product_id = product_id
    var result = JSON.parse_string(
        iap.request_purchase(JSON.stringify({"sku": product_id}))
    )

    if not result.get("success", false):
        handle_immediate_error(result)
```

### 2. Don't Expose Technical Details

```gdscript
# Bad - exposing technical error
func _on_purchase_error(error: Dictionary):
    show_error(error.get("debugMessage", ""))

# Good - user-friendly message
func _on_purchase_error(error: Dictionary):
    var user_message = get_user_friendly_message(error)
    if user_message != "":
        show_error(user_message)

    # Log technical details for debugging
    log_error(error)
```

### 3. Handle Platform Differences

```gdscript
func _on_purchase_error(error: Dictionary):
    if OS.get_name() == "iOS":
        handle_ios_error(error)
    elif OS.get_name() == "Android":
        handle_android_error(error)
    else:
        handle_generic_error(error)
```

## See Also

- [Troubleshooting](./troubleshooting) - Common issues and solutions
- [API Reference](../api/) - Detailed method documentation
- [Purchases Guide](./purchases) - Purchase implementation
