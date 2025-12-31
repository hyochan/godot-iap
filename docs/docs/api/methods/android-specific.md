---
sidebar_position: 4
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Android-Specific Methods

<IapKitBanner />

Methods available only on Android platform using Google Play Billing Library.

## Purchase Management

### acknowledge_purchase_android

Acknowledge a non-consumable purchase. **Required for all non-consumable purchases within 3 days.**

```gdscript
func acknowledge_purchase_android(purchase_token: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase_token` | `String` | Purchase token from purchase |

**Returns:** JSON string with result

```json
{
  "success": true
}
```

**Example:**
```gdscript
func handle_non_consumable_purchase(purchase: Dictionary):
    # First verify on server
    var verified = await verify_on_server(purchase)
    if verified:
        # Acknowledge the purchase
        var result = JSON.parse_string(
            iap.acknowledge_purchase_android(purchase.purchaseToken)
        )
        if result.get("success", false):
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
func consume_purchase_android(purchase_token: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `purchase_token` | `String` | Purchase token from purchase |

**Returns:** JSON string with result

```json
{
  "success": true
}
```

**Example:**
```gdscript
func handle_consumable_purchase(purchase: Dictionary):
    # First verify on server
    var verified = await verify_on_server(purchase)
    if verified:
        # Grant the item
        add_coins(100)

        # Consume the purchase
        var result = JSON.parse_string(
            iap.consume_purchase_android(purchase.purchaseToken)
        )
        if result.get("success", false):
            print("Purchase consumed, can buy again")
```

---

## Storefront

### get_storefront_android

Get the user's country code based on Google Play settings.

```gdscript
func get_storefront_android() -> String
```

**Returns:** JSON string with country info

```json
{
  "success": true,
  "countryCode": "US"
}
```

**Example:**
```gdscript
func get_user_country():
    var result = JSON.parse_string(iap.get_storefront_android())
    if result.get("success", false):
        return result.get("countryCode", "")
    return ""
```

---

### get_package_name_android

Get the app's package name.

```gdscript
func get_package_name_android() -> String
```

**Returns:** Package name as string

**Example:**
```gdscript
func log_app_info():
    var package = iap.get_package_name_android()
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
func check_alternative_billing_availability_android() -> String
```

**Returns:** JSON string with availability

```json
{
  "success": true,
  "isAvailable": true
}
```

---

### show_alternative_billing_dialog_android

Show the alternative billing information dialog to the user.

```gdscript
func show_alternative_billing_dialog_android() -> String
```

**Returns:** JSON string with result

```json
{
  "success": true,
  "userAccepted": true
}
```

---

### create_alternative_billing_token_android

Create a token for reporting alternative billing transactions.

```gdscript
func create_alternative_billing_token_android() -> String
```

**Returns:** JSON string with token

```json
{
  "success": true,
  "token": "external_transaction_token_here"
}
```

---

## Billing Programs API (Android 8.2.0+)

Modern API for external billing and alternative payment options.

### is_billing_program_available_android

Check if a specific billing program is available.

```gdscript
func is_billing_program_available_android(billing_program: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `billing_program` | `String` | Program type (see table below) |

**Billing Programs:**
| Program | Description |
|---------|-------------|
| `external-offer` | External offer program |
| `external-content-link` | External content link |
| `external-payments` | External payments (user choice) |
| `user-choice-billing` | User choice billing |

**Returns:** JSON string with availability

```json
{
  "success": true,
  "isAvailable": true,
  "billingProgram": "external-offer"
}
```

**Example:**
```gdscript
func check_external_offer_availability():
    var result = JSON.parse_string(
        iap.is_billing_program_available_android("external-offer")
    )
    if result.get("isAvailable", false):
        show_external_offer_button()
```

---

### launch_external_link_android

Launch an external link for billing programs.

```gdscript
func launch_external_link_android(params_json: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `params_json` | `String` | JSON object with link parameters |

**Parameters Object:**
```json
{
  "billingProgram": "external-offer",
  "launchMode": "launch-in-external-browser-or-app",
  "linkType": "link-to-digital-content-offer",
  "linkUri": "https://your-store.com/offer"
}
```

**Launch Modes:**
| Mode | Description |
|------|-------------|
| `launch-in-external-browser-or-app` | Open in browser or app |
| `caller-will-launch-link` | App handles the launch |
| `unspecified` | Default behavior |

**Link Types:**
| Type | Description |
|------|-------------|
| `link-to-digital-content-offer` | Link to digital content |
| `link-to-app-download` | Link to app download |
| `unspecified` | Default behavior |

**Returns:** JSON string with result

```json
{
  "success": true,
  "launched": true
}
```

**Example:**
```gdscript
func open_external_offer():
    var params = {
        "billingProgram": "external-offer",
        "launchMode": "launch-in-external-browser-or-app",
        "linkType": "link-to-digital-content-offer",
        "linkUri": "https://your-store.com/special-offer"
    }
    var result = JSON.parse_string(
        iap.launch_external_link_android(JSON.stringify(params))
    )
    if result.get("launched", false):
        print("External link opened")
```

---

### create_billing_program_reporting_details_android

Create reporting details for external transactions.

```gdscript
func create_billing_program_reporting_details_android(billing_program: String) -> String
```

**Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `billing_program` | `String` | Billing program type |

**Returns:** JSON string with token

```json
{
  "success": true,
  "billingProgram": "external-offer",
  "externalTransactionToken": "token_for_reporting"
}
```

**Example:**
```gdscript
func get_reporting_token():
    var result = JSON.parse_string(
        iap.create_billing_program_reporting_details_android("external-offer")
    )
    if result.get("success", false):
        var token = result.get("externalTransactionToken", "")
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

var iap: GodotIap

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.user_choice_billing_android.connect(_on_user_choice_billing)

func _on_purchase_updated(purchase: Dictionary):
    var state = purchase.get("purchaseState", "")
    var is_acknowledged = purchase.get("isAcknowledged", false)

    if state == "purchased" and not is_acknowledged:
        await handle_purchase(purchase)

func handle_purchase(purchase: Dictionary):
    # Verify on server
    var verified = await verify_on_server(purchase)
    if not verified:
        return

    var product_id = purchase.productId
    var purchase_token = purchase.purchaseToken

    if is_consumable(product_id):
        # Consume the purchase
        grant_consumable(product_id)
        iap.consume_purchase_android(purchase_token)
    else:
        # Acknowledge non-consumable
        grant_non_consumable(product_id)
        iap.acknowledge_purchase_android(purchase_token)

func _on_purchase_error(error: Dictionary):
    var code = error.get("code", "")

    match code:
        "USER_CANCELED":
            print("User canceled")
        "ITEM_ALREADY_OWNED":
            # Restore the purchase
            var purchases = JSON.parse_string(iap.get_available_purchases())
            for p in purchases:
                if not p.get("isAcknowledged", false):
                    handle_purchase(p)
        "ITEM_NOT_OWNED":
            print("Item not owned")
        _:
            print("Error: ", error.get("message", ""))

func _on_user_choice_billing(data: Dictionary):
    # Handle user choice billing
    var token = data.get("externalTransactionToken", "")
    # Implement your external billing flow
```
