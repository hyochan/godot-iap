---
sidebar_position: 4
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Android-Specific Methods

<IapKitBanner />

Methods available only on Android platform using Google Play Billing Library. All methods use typed parameters and return typed objects.

## Setup

```gdscript
# Load OpenIAP types
const Types = preload("res://addons/godot-iap/types.gd")
```

## Purchase Management

### acknowledge_purchase_android

Acknowledge a non-consumable purchase. **Required for all non-consumable purchases within 3 days.**

```gdscript
func acknowledge_purchase_android(purchase_token: String) -> Types.VoidResult
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase_token` | `String` | Purchase token from purchase |

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func handle_non_consumable_purchase(purchase):
    # First verify on server
    var verified = await verify_on_server(purchase)
    if verified:
        # Acknowledge the purchase
        var result = GodotIapPlugin.acknowledge_purchase_android(purchase.purchase_token)
        if result.success:
            # Grant the content
            unlock_premium_content()
```

:::warning Important
Non-consumable purchases that aren't acknowledged within 3 days will be automatically refunded by Google Play.
:::

---

### consume_purchase_android

Consume a consumable purchase. This allows the product to be purchased again.

```gdscript
func consume_purchase_android(purchase_token: String) -> Types.VoidResult
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase_token` | `String` | Purchase token from purchase |

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func handle_consumable_purchase(purchase):
    # First verify on server
    var verified = await verify_on_server(purchase)
    if verified:
        # Grant the item
        add_coins(100)

        # Consume the purchase
        var result = GodotIapPlugin.consume_purchase_android(purchase.purchase_token)
        if result.success:
            print("Purchase consumed, can buy again")
```

---

## Storefront

### get_storefront_android

Get the user's country code based on Google Play settings.

```gdscript
func get_storefront_android() -> String
```

**Returns:** `String` - Country code (e.g., "US", "KR")

**Example:**
```gdscript
func get_user_country() -> String:
    return GodotIapPlugin.get_storefront_android()
```

---

### get_package_name_android

Get the app's package name.

```gdscript
func get_package_name_android() -> String
```

**Returns:** `String` - Package name

**Example:**
```gdscript
func log_app_info():
    var package = GodotIapPlugin.get_package_name_android()
    print("Package: ", package)  # e.g., "com.yourcompany.game"
```

---

## Alternative Billing (Deprecated)

:::warning Deprecated
These methods are deprecated in favor of the Billing Programs API. They may be removed in future versions.
:::

### check_alternative_billing_availability_android

Check if alternative billing is available for this user/region.

```gdscript
func check_alternative_billing_availability_android() -> Types.BoolResult
```

**Returns:** `Types.BoolResult`

---

### show_alternative_billing_dialog_android

Show the alternative billing information dialog to the user.

```gdscript
func show_alternative_billing_dialog_android() -> Variant
```

**Returns:** `Variant` - `Types.AlternativeBillingDialogResultAndroid` or `null`

---

### create_alternative_billing_token_android

Create a token for reporting alternative billing transactions.

```gdscript
func create_alternative_billing_token_android() -> Variant
```

**Returns:** `Variant` - `Types.AlternativeBillingTokenAndroid` or `null`

---

## Billing Programs API (Android 8.2.0+)

Modern API for external billing and alternative payment options.

### is_billing_program_available_android

Check if a specific billing program is available.

```gdscript
func is_billing_program_available_android(billing_program: Types.BillingProgramAndroid) -> bool
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `billing_program` | `Types.BillingProgramAndroid` | Program type enum |

**Billing Programs:**
| Program | Description |
|---------|-------------|
| `EXTERNAL_OFFER` | External offer program |
| `EXTERNAL_CONTENT_LINK` | External content link |
| `EXTERNAL_PAYMENTS` | External payments (user choice) |
| `USER_CHOICE_BILLING` | User choice billing |

**Returns:** `bool`

**Example:**
```gdscript
func check_external_offer_availability():
    if GodotIapPlugin.is_billing_program_available_android(Types.BillingProgramAndroid.EXTERNAL_OFFER):
        show_external_offer_button()
```

---

### launch_external_link_android

Launch an external link for billing programs.

```gdscript
func launch_external_link_android(params: Types.ExternalLinkParamsAndroid) -> Types.VoidResult
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `params` | `Types.ExternalLinkParamsAndroid` | Link parameters |

**Returns:** `Types.VoidResult`

**Example:**
```gdscript
func open_external_offer():
    var params = Types.ExternalLinkParamsAndroid.new()
    params.billing_program = Types.BillingProgramAndroid.EXTERNAL_OFFER
    params.launch_mode = Types.ExternalLaunchModeAndroid.LAUNCH_IN_BROWSER
    params.link_type = Types.ExternalLinkTypeAndroid.DIGITAL_CONTENT
    params.link_uri = "https://your-store.com/special-offer"

    var result = GodotIapPlugin.launch_external_link_android(params)
    if result.success:
        print("External link opened")
```

---

### create_billing_program_reporting_details_android

Create reporting details for external transactions.

```gdscript
func create_billing_program_reporting_details_android(billing_program: Types.BillingProgramAndroid) -> Variant
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `billing_program` | `Types.BillingProgramAndroid` | Billing program type |

**Returns:** `Variant` - `Types.BillingProgramReportingDetailsAndroid` or `null`

**Example:**
```gdscript
func get_reporting_token():
    var result = GodotIapPlugin.create_billing_program_reporting_details_android(
        Types.BillingProgramAndroid.EXTERNAL_OFFER
    )
    if result:
        var token = result.external_transaction_token
        # Use this token when reporting external transactions to Google
        report_external_transaction(token)
```

---

## Signals

### user_choice_billing_android

Emitted when user chooses an alternative billing option.

```gdscript
func _on_user_choice_billing(data: Dictionary):
    var products = data.get("products", [])
    var external_token = data.get("externalTransactionToken", "")

    # Handle external billing flow
    for product in products:
        process_external_purchase(product, external_token)
```

---

### developer_provided_billing_android

Emitted for developer-provided billing options.

```gdscript
func _on_developer_provided_billing(data: Dictionary):
    # Handle developer billing flow
    pass
```

---

## Complete Example

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

func _ready():
    _setup_signals()
    if GodotIapPlugin.init_connection():
        _check_pending_purchases()

func _setup_signals():
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)
    GodotIapPlugin.user_choice_billing_android.connect(_on_user_choice_billing)

func _check_pending_purchases():
    var purchases = GodotIapPlugin.get_available_purchases()
    for purchase in purchases:
        if not purchase.is_acknowledged:
            await handle_purchase(purchase)

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    var is_acknowledged = purchase.get("isAcknowledged", false)

    if (state == "purchased" or state == "Purchased") and not is_acknowledged:
        await handle_purchase_dict(purchase)

func handle_purchase_dict(purchase: Dictionary):
    # Verify on server
    var verified = await verify_on_server(purchase)
    if not verified:
        return

    var product_id = purchase.get("productId", "")
    var purchase_token = purchase.get("purchaseToken", "")

    if is_consumable(product_id):
        # Grant and consume
        grant_consumable(product_id)
        GodotIapPlugin.consume_purchase_android(purchase_token)
    else:
        # Grant and acknowledge
        grant_non_consumable(product_id)
        GodotIapPlugin.acknowledge_purchase_android(purchase_token)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    match code:
        "USER_CANCELED":
            print("User canceled")
        "ITEM_ALREADY_OWNED":
            # Restore the purchase
            var purchases = GodotIapPlugin.get_available_purchases()
            for p in purchases:
                if not p.is_acknowledged:
                    await handle_purchase(p)
        "ITEM_NOT_OWNED":
            print("Item not owned")
        _:
            print("Error: ", error.get("message", ""))

func _on_user_choice_billing(data: Dictionary):
    # Handle user choice billing
    var token = data.get("externalTransactionToken", "")
    # Implement your external billing flow
```
