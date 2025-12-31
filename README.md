# godot-iap

<div align="center">
  <img src="https://github.com/user-attachments/assets/cc7f363a-43a9-470c-bde7-2f63985a9f46"" width="200" alt="godot-iap logo" />

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Godot 4.3+](https://img.shields.io/badge/Godot-4.3+-blue?style=flat-square&logo=godot-engine)](https://godotengine.org)
[![OpenIAP](https://img.shields.io/badge/OpenIAP-Compliant-green?style=flat-square)](https://openiap.dev)

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

var iap: GodotIap

func _ready():
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _initialize()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _initialize():
    var result = JSON.parse_string(iap.init_connection())
    if result.get("success", false):
        var product_ids = ["coins_100", "premium"]
        iap.fetch_products(JSON.stringify(product_ids), "inapp")

func _on_products_fetched(products_dict):
    if products_dict.get("success", false):
        var products = JSON.parse_string(products_dict.get("productsJson", "[]"))
        for product in products:
            print("Product: ", product.productId, " - ", product.localizedPrice)

func _on_purchase_updated(purchase: Dictionary):
    if purchase.purchaseState == "purchased":
        # Verify on your server, then finish
        iap.finish_transaction(JSON.stringify(purchase), true)

func _on_purchase_error(error: Dictionary):
    print("Error: ", error.code, " - ", error.message)

func buy(product_id: String):
    var params = {"sku": product_id, "type": "inapp"}
    iap.request_purchase(JSON.stringify(params))
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
