---
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# API Reference

<IapKitBanner />

Complete API documentation for Godot IAP. The plugin provides a unified interface for iOS and Android in-app purchases with **type-safe APIs**.

## Getting Started

```gdscript
# Load OpenIAP types for type-safe API
const Types = preload("res://addons/godot-iap/types.gd")

func _ready():
    # GodotIapPlugin is an autoload singleton
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)

    if GodotIapPlugin.init_connection():
        _fetch_products()
```

## Type System

All API methods use typed parameters and return typed objects from `types.gd`.

### Platform-Specific Types (Sealed Class Pattern)

GDScript doesn't support Union types like Dart's `sealed class`. For functions returning platform-specific types:

| Return Type | Description | Example |
|-------------|-------------|---------|
| `-> Array` | Array of `Types.ProductAndroid` OR `Types.ProductIOS` | `fetch_products()` |
| `-> Variant` | Typed object OR `null` | `request_purchase()` |
| `-> Types.X` | Same type on all platforms | `finish_transaction()` |

```gdscript
# Returns Array of typed products
var products = GodotIapPlugin.fetch_products(request)
for product in products:
    # product is Types.ProductAndroid on Android, Types.ProductIOS on iOS
    print(product.id, " - ", product.display_price)
```

## Signals

The plugin emits the following signals:

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `purchase_updated` | `Dictionary` | Emitted when a purchase is updated |
| `purchase_error` | `Dictionary` | Emitted when a purchase error occurs |
| `products_fetched` | `Dictionary` | Emitted when products are fetched (iOS async) |
| `promoted_product_ios` | `String` | (iOS) Emitted when a promoted product is selected |
| `user_choice_billing_android` | `Dictionary` | (Android) Emitted for user choice billing |
| `developer_provided_billing_android` | `Dictionary` | (Android) Emitted for developer provided billing |

## Core Methods

### Connection

| Method | Returns | Description |
|--------|---------|-------------|
| [`init_connection()`](./methods/core-methods#init_connection) | `bool` | Initialize the billing connection |
| [`end_connection()`](./methods/core-methods#end_connection) | `Types.VoidResult` | End the billing connection |

### Products

| Method | Returns | Description |
|--------|---------|-------------|
| [`fetch_products(request)`](./methods/core-methods#fetch_products) | `Array` | Fetch product details (`ProductAndroid[]` or `ProductIOS[]`) |

### Purchases

| Method | Returns | Description |
|--------|---------|-------------|
| [`request_purchase(props)`](./methods/core-methods#request_purchase) | `Variant` | Request a purchase (`PurchaseAndroid`, `PurchaseIOS`, or `null`) |
| [`finish_transaction(purchase, is_consumable)`](./methods/core-methods#finish_transaction) | `Types.VoidResult` | Finish a transaction |
| [`get_available_purchases()`](./methods/core-methods#get_available_purchases) | `Array` | Get available purchases (`PurchaseAndroid[]` or `PurchaseIOS[]`) |
| [`restore_purchases()`](./methods/core-methods#restore_purchases) | `Types.VoidResult` | Restore previous purchases |

### Subscriptions

| Method | Returns | Description |
|--------|---------|-------------|
| [`get_active_subscriptions(ids)`](./methods/core-methods#get_active_subscriptions) | `Array` | Get active subscriptions (`ActiveSubscription[]`) |
| [`has_active_subscriptions(ids)`](./methods/core-methods#has_active_subscriptions) | `bool` | Check for active subscriptions |

### Utility

| Method | Returns | Description |
|--------|---------|-------------|
| [`deep_link_to_subscriptions(options)`](./methods/unified-apis#deep_link_to_subscriptions) | `Types.VoidResult` | Open subscription management |
| [`verify_purchase(props)`](./methods/unified-apis#verify_purchase) | `Variant` | Verify a purchase |

## iOS-Specific Methods

| Method | Returns | Description |
|--------|---------|-------------|
| [`sync_ios()`](./methods/ios-specific#sync_ios) | `Types.VoidResult` | Sync transactions |
| [`clear_transaction_ios()`](./methods/ios-specific#clear_transaction_ios) | `Types.VoidResult` | Clear finished transactions |
| [`get_pending_transactions_ios()`](./methods/ios-specific#get_pending_transactions_ios) | `Array` | Get pending transactions (`TransactionIOS[]`) |
| [`present_code_redemption_sheet_ios()`](./methods/ios-specific#present_code_redemption_sheet_ios) | `Types.VoidResult` | Present offer code sheet |
| [`show_manage_subscriptions_ios()`](./methods/ios-specific#show_manage_subscriptions_ios) | `Types.VoidResult` | Show subscription management |
| [`begin_refund_request_ios(transaction_id)`](./methods/ios-specific#begin_refund_request_ios) | `Types.RefundRequestResultIOS` | Begin refund request |
| [`current_entitlement_ios(sku)`](./methods/ios-specific#current_entitlement_ios) | `Variant` | Get current entitlement (`TransactionIOS` or `null`) |
| [`latest_transaction_ios(sku)`](./methods/ios-specific#latest_transaction_ios) | `Variant` | Get latest transaction (`TransactionIOS` or `null`) |
| [`get_storefront_ios()`](./methods/ios-specific#get_storefront_ios) | `Variant` | Get storefront info (`StorefrontIOS` or `null`) |
| [`subscription_status_ios(sku)`](./methods/ios-specific#subscription_status_ios) | `Array` | Get subscription status (`SubscriptionStatusIOS[]`) |
| [`is_eligible_for_intro_offer_ios(group_id)`](./methods/ios-specific#is_eligible_for_intro_offer_ios) | `bool` | Check intro offer eligibility |
| [`get_app_transaction_ios()`](./methods/ios-specific#get_app_transaction_ios) | `Variant` | Get app transaction (`AppTransactionIOS` or `null`) |
| [`get_promoted_product_ios()`](./methods/ios-specific#get_promoted_product_ios) | `Variant` | Get promoted product (`ProductIOS` or `null`) |
| [`get_receipt_data_ios()`](./methods/ios-specific#get_receipt_data_ios) | `String` | Get receipt data |
| [`is_transaction_verified_ios(transaction_id)`](./methods/ios-specific#is_transaction_verified_ios) | `bool` | Check transaction verification |
| [`get_transaction_jws_ios(transaction_id)`](./methods/ios-specific#get_transaction_jws_ios) | `String` | Get transaction JWS |

### External Purchase APIs (iOS 18.2+)

| Method | Returns | Description |
|--------|---------|-------------|
| [`can_present_external_purchase_notice_ios()`](./methods/ios-specific#can_present_external_purchase_notice_ios) | `bool` | Check if can present notice |
| [`present_external_purchase_notice_sheet_ios()`](./methods/ios-specific#present_external_purchase_notice_sheet_ios) | `Types.VoidResult` | Present external purchase notice |
| [`present_external_purchase_link_ios(url)`](./methods/ios-specific#present_external_purchase_link_ios) | `Types.VoidResult` | Present external purchase link |

## Android-Specific Methods

| Method | Returns | Description |
|--------|---------|-------------|
| [`acknowledge_purchase_android(token)`](./methods/android-specific#acknowledge_purchase_android) | `Types.VoidResult` | Acknowledge a purchase |
| [`consume_purchase_android(token)`](./methods/android-specific#consume_purchase_android) | `Types.VoidResult` | Consume a purchase |
| [`get_storefront_android()`](./methods/android-specific#get_storefront_android) | `String` | Get storefront info (country code) |
| [`get_package_name_android()`](./methods/android-specific#get_package_name_android) | `String` | Get package name |

### Alternative Billing (Deprecated)

| Method | Returns | Description |
|--------|---------|-------------|
| [`check_alternative_billing_availability_android()`](./methods/android-specific#check_alternative_billing_availability_android) | `Types.BoolResult` | Check availability |
| [`show_alternative_billing_dialog_android()`](./methods/android-specific#show_alternative_billing_dialog_android) | `Variant` | Show billing dialog |
| [`create_alternative_billing_token_android()`](./methods/android-specific#create_alternative_billing_token_android) | `Variant` | Create billing token |

### Billing Programs API (Android 8.2.0+)

| Method | Returns | Description |
|--------|---------|-------------|
| [`is_billing_program_available_android(program)`](./methods/android-specific#is_billing_program_available_android) | `bool` | Check program availability |
| [`launch_external_link_android(params)`](./methods/android-specific#launch_external_link_android) | `Types.VoidResult` | Launch external link |
| [`create_billing_program_reporting_details_android(program)`](./methods/android-specific#create_billing_program_reporting_details_android) | `Variant` | Create reporting details |

## Next Steps

- [Core Methods](./methods/core-methods)
- [iOS-Specific Methods](./methods/ios-specific)
- [Android-Specific Methods](./methods/android-specific)
