---
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# API Reference

<IapKitBanner />

Complete API documentation for Godot IAP. The plugin provides a unified interface for iOS and Android in-app purchases.

## Getting the Plugin Instance

```gdscript
var iap: GodotIap

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
```

## Signals

The plugin emits the following signals:

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `purchase_updated` | `Dictionary` | Emitted when a purchase is updated |
| `purchase_error` | `Dictionary` | Emitted when a purchase error occurs |
| `products_fetched` | `Dictionary` | Emitted when products are fetched |
| `promoted_product_ios` | `String` | (iOS) Emitted when a promoted product is selected |
| `user_choice_billing_android` | `Dictionary` | (Android) Emitted for user choice billing |
| `developer_provided_billing_android` | `Dictionary` | (Android) Emitted for developer provided billing |

## Core Methods

### Connection

| Method | Returns | Description |
|--------|---------|-------------|
| [`init_connection()`](./methods/core-methods#init_connection) | `String` | Initialize the billing connection |
| [`end_connection()`](./methods/core-methods#end_connection) | `String` | End the billing connection |

### Products

| Method | Returns | Description |
|--------|---------|-------------|
| [`fetch_products(skus_json, type)`](./methods/core-methods#fetch_products) | `String` | Fetch product details |
| [`fetch_subscriptions(skus_json)`](./methods/core-methods#fetch_subscriptions) | `String` | Fetch subscription details |

### Purchases

| Method | Returns | Description |
|--------|---------|-------------|
| [`request_purchase(params_json)`](./methods/core-methods#request_purchase) | `String` | Request a purchase |
| [`request_subscription(params_json)`](./methods/core-methods#request_subscription) | `String` | Request a subscription |
| [`finish_transaction(purchase_json, is_consumable)`](./methods/core-methods#finish_transaction) | `String` | Finish a transaction |
| [`get_available_purchases()`](./methods/core-methods#get_available_purchases) | `String` | Get available purchases |
| [`restore_purchases()`](./methods/core-methods#restore_purchases) | `String` | Restore previous purchases |

### Subscriptions

| Method | Returns | Description |
|--------|---------|-------------|
| [`get_active_subscriptions(ids_json)`](./methods/core-methods#get_active_subscriptions) | `String` | Get active subscriptions |
| [`has_active_subscriptions(ids_json)`](./methods/core-methods#has_active_subscriptions) | `String` | Check for active subscriptions |

### Utility

| Method | Returns | Description |
|--------|---------|-------------|
| [`deep_link_to_subscriptions(options_json)`](./methods/unified-apis#deep_link_to_subscriptions) | `String` | Open subscription management |
| [`verify_purchase(props_json)`](./methods/unified-apis#verify_purchase) | `String` | Verify a purchase |

## iOS-Specific Methods

| Method | Returns | Description |
|--------|---------|-------------|
| [`sync_ios()`](./methods/ios-specific#sync_ios) | `String` | Sync transactions |
| [`clear_transaction_ios()`](./methods/ios-specific#clear_transaction_ios) | `String` | Clear finished transactions |
| [`get_pending_transactions_ios()`](./methods/ios-specific#get_pending_transactions_ios) | `String` | Get pending transactions |
| [`present_code_redemption_sheet_ios()`](./methods/ios-specific#present_code_redemption_sheet_ios) | `String` | Present offer code sheet |
| [`show_manage_subscriptions_ios()`](./methods/ios-specific#show_manage_subscriptions_ios) | `String` | Show subscription management |
| [`begin_refund_request_ios(transaction_id)`](./methods/ios-specific#begin_refund_request_ios) | `String` | Begin refund request |
| [`current_entitlement_ios(sku)`](./methods/ios-specific#current_entitlement_ios) | `String` | Get current entitlement |
| [`latest_transaction_ios(sku)`](./methods/ios-specific#latest_transaction_ios) | `String` | Get latest transaction |
| [`get_storefront_ios()`](./methods/ios-specific#get_storefront_ios) | `String` | Get storefront info |
| [`subscription_status_ios(sku)`](./methods/ios-specific#subscription_status_ios) | `String` | Get subscription status |
| [`is_eligible_for_intro_offer_ios(group_id)`](./methods/ios-specific#is_eligible_for_intro_offer_ios) | `String` | Check intro offer eligibility |
| [`get_app_transaction_ios()`](./methods/ios-specific#get_app_transaction_ios) | `String` | Get app transaction |
| [`get_promoted_product_ios()`](./methods/ios-specific#get_promoted_product_ios) | `String` | Get promoted product |
| [`request_purchase_on_promoted_product_ios()`](./methods/ios-specific#request_purchase_on_promoted_product_ios) | `String` | Purchase promoted product |
| [`get_receipt_data_ios()`](./methods/ios-specific#get_receipt_data_ios) | `String` | Get receipt data |
| [`is_transaction_verified_ios(transaction_id)`](./methods/ios-specific#is_transaction_verified_ios) | `String` | Check transaction verification |
| [`get_transaction_jws_ios(transaction_id)`](./methods/ios-specific#get_transaction_jws_ios) | `String` | Get transaction JWS |

### External Purchase APIs (iOS 18.2+)

| Method | Returns | Description |
|--------|---------|-------------|
| [`can_present_external_purchase_notice_ios()`](./methods/ios-specific#can_present_external_purchase_notice_ios) | `String` | Check if can present notice |
| [`present_external_purchase_notice_sheet_ios()`](./methods/ios-specific#present_external_purchase_notice_sheet_ios) | `String` | Present external purchase notice |
| [`present_external_purchase_link_ios(url)`](./methods/ios-specific#present_external_purchase_link_ios) | `String` | Present external purchase link |

## Android-Specific Methods

| Method | Returns | Description |
|--------|---------|-------------|
| [`acknowledge_purchase_android(purchase_token)`](./methods/android-specific#acknowledge_purchase_android) | `String` | Acknowledge a purchase |
| [`consume_purchase_android(purchase_token)`](./methods/android-specific#consume_purchase_android) | `String` | Consume a purchase |
| [`get_storefront_android()`](./methods/android-specific#get_storefront_android) | `String` | Get storefront info |
| [`get_package_name_android()`](./methods/android-specific#get_package_name_android) | `String` | Get package name |

### Alternative Billing (Deprecated)

| Method | Returns | Description |
|--------|---------|-------------|
| [`check_alternative_billing_availability_android()`](./methods/android-specific#check_alternative_billing_availability_android) | `String` | Check availability |
| [`show_alternative_billing_dialog_android()`](./methods/android-specific#show_alternative_billing_dialog_android) | `String` | Show billing dialog |
| [`create_alternative_billing_token_android()`](./methods/android-specific#create_alternative_billing_token_android) | `String` | Create billing token |

### Billing Programs API (Android 8.2.0+)

| Method | Returns | Description |
|--------|---------|-------------|
| [`is_billing_program_available_android(program)`](./methods/android-specific#is_billing_program_available_android) | `String` | Check program availability |
| [`launch_external_link_android(params_json)`](./methods/android-specific#launch_external_link_android) | `String` | Launch external link |
| [`create_billing_program_reporting_details_android(program)`](./methods/android-specific#create_billing_program_reporting_details_android) | `String` | Create reporting details |

## Response Format

All methods return JSON strings. Parse them using `JSON.parse_string()`:

```gdscript
var result_json = iap.init_connection()
var result = JSON.parse_string(result_json)

if result.get("success", false):
    print("Success!")
else:
    print("Error: ", result.get("error", "Unknown error"))
```

### Common Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `success` | `bool` | Whether the operation succeeded |
| `error` | `String` | Error message if failed |
| `status` | `String` | Status indicator (e.g., "pending") |

## Next Steps

- [Core Methods](./methods/core-methods)
- [iOS-Specific Methods](./methods/ios-specific)
- [Android-Specific Methods](./methods/android-specific)
