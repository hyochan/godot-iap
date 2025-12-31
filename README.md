# godot-iap

<div align="center">
  <img src="https://github.com/user-attachments/assets/cc7f363a-43a9-470c-bde7-2f63985a9f46"" width="200" alt="godot-iap logo" />

[![CI](https://img.shields.io/github/actions/workflow/status/hyochan/godot-iap/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/hyochan/godot-iap/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hyochan/godot-iap?style=flat-square)](https://github.com/hyochan/godot-iap/releases)
[![Godot 4.3+](https://img.shields.io/badge/Godot-4.3+-blue?style=flat-square&logo=godot-engine)](https://godotengine.org)
[![OpenIAP](https://img.shields.io/badge/OpenIAP-Compliant-green?style=flat-square)](https://openiap.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A comprehensive in-app purchase plugin for Godot 4.x that conforms to the <a href="https://openiap.dev">Open IAP specification</a>

<a href="https://openiap.dev"><img src="https://github.com/hyodotdev/openiap/blob/main/logo.png?raw=true" alt="Open IAP" height="40" /></a>

</div>

## About

This is an In-App Purchase plugin for Godot Engine, built following the [OpenIAP specification](https://openiap.dev). This project has been inspired by [expo-iap](https://github.com/hyochan/expo-iap), [flutter_inapp_purchase](https://github.com/nicholasmuir/flutter_inapp_purchase), [kmp-iap](https://github.com/nicholasmuir/kmp-iap), and [react-native-iap](https://github.com/dooboolab-community/react-native-iap).

We are trying to share the same experience of in-app purchase in Godot Engine as in other cross-platform frameworks. Native code is powered by [openiap-apple](https://github.com/hyodotdev/openiap/tree/main/packages/apple) and [openiap-google](https://github.com/hyodotdev/openiap/tree/main/packages/google) modules.

We will keep working on it as time goes by just like we did in other IAP libraries.

## Documentation

Visit the documentation site for installation guides, API reference, and examples:

### **[hyochan.github.io/godot-iap](https://hyochan.github.io/godot-iap)**

## Installation

1. Download `godot-iap-{version}.zip` from [GitHub Releases](https://github.com/hyochan/godot-iap/releases)
2. Extract and copy `addons/godot-iap/` to your project's `addons/` folder
3. Enable the plugin in **Project → Project Settings → Plugins**

See the [Installation Guide](https://hyochan.github.io/godot-iap/getting-started/installation) for more details.

## Quick Start

```gdscript
extends Node

# Load OpenIAP types for type-safe API
const Types = preload("res://addons/godot-iap/types.gd")

func _ready():
    # Connect signals
    GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
    GodotIapPlugin.purchase_error.connect(_on_purchase_error)

    # Initialize connection
    if GodotIapPlugin.init_connection():
        _fetch_products()

func _fetch_products():
    # Create typed ProductRequest
    var request = Types.ProductRequest.new()
    request.skus = ["coins_100", "premium"]
    request.type = Types.ProductQueryType.ALL

    # Returns Array of typed products (Types.ProductAndroid or Types.ProductIOS)
    var products = GodotIapPlugin.fetch_products(request)
    for product in products:
        # Access typed properties directly
        print("Product: ", product.id, " - ", product.display_price)

func _on_purchase_updated(purchase: Dictionary):
    if purchase.get("purchaseState") == "Purchased":
        # Finish transaction with typed PurchaseInput
        var purchase_input = Types.PurchaseInput.from_dict(purchase)
        GodotIapPlugin.finish_transaction(purchase_input, true)  # true = consumable

func _on_purchase_error(error: Dictionary):
    print("Error: ", error.get("code"), " - ", error.get("message"))

func buy(product_id: String):
    # Create typed RequestPurchaseProps
    var props = Types.RequestPurchaseProps.new()
    props.request = Types.RequestPurchasePropsByPlatforms.new()
    props.request.google = Types.RequestPurchaseAndroidProps.new()
    props.request.google.skus = [product_id]
    props.request.apple = Types.RequestPurchaseIosProps.new()
    props.request.apple.sku = product_id
    props.type = Types.ProductQueryType.IN_APP

    # Returns typed purchase object or null
    var purchase = GodotIapPlugin.request_purchase(props)
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
