---
title: godot-iap
sidebar_label: Introduction
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';
import useBaseUrl from '@docusaurus/useBaseUrl';

# godot-iap

<IapKitBanner />

:::info Version
This documentation is for **godot-iap v1.0-beta** which includes StoreKit 2 for iOS and Google Play Billing v8+ for Android. Native code is powered by [openiap](https://openiap.dev).
:::

A comprehensive in-app purchase plugin for Godot 4.x that **conforms to the [Open IAP specification](https://openiap.dev)**.

<div style={{textAlign: 'center', margin: '2rem 0'}}>
  <img src={useBaseUrl('/img/icon.png')} alt="Godot IAP Logo" style={{maxWidth: '200px', height: 'auto'}} />
</div>

## What is godot-iap?

This is an **In App Purchase** plugin for Godot Engine. This project has been inspired by [expo-iap](https://github.com/hyochan/expo-iap), [flutter_inapp_purchase](https://github.com/hyochan/flutter_inapp_purchase) and [react-native-iap](https://github.com/hyochan/react-native-iap). We are trying to share the same experience of **in-app-purchase** in **Godot Engine** as in other cross-platform frameworks.

We will keep working on it as time goes by just like we did in **expo-iap**, **flutter_inapp_purchase**, **kmp-iap** and **react-native-iap**.

## Key Features

- **Cross-Platform**: Unified GDScript API for both iOS and Android
- **StoreKit 2 Support**: Full StoreKit 2 support for iOS 15.0+
- **Billing Client v8+**: Latest Android Google Play Billing features
- **Type-safe**: Complete type safety with GDScript's static typing
- **Signal-based**: Event-driven architecture with Godot signals
- **OpenIAP Compliant**: Follows the standardized [OpenIAP specification](https://openiap.dev)

## What this library does

- **Product Management**: Fetch and manage consumable and non-consumable products
- **Purchase Flow**: Handle complete purchase workflows with proper error handling
- **Subscription Support**: Full subscription lifecycle management
- **Receipt Validation**: Validate purchases on both platforms
- **Store Communication**: Direct communication with App Store and Google Play
- **Error Recovery**: Comprehensive error handling and recovery mechanisms

## Platform Support

| Feature                  | iOS | Android |
| ------------------------ | --- | ------- |
| Products & Subscriptions | ✅  | ✅      |
| Purchase Flow            | ✅  | ✅      |
| Receipt Validation       | ✅  | ✅      |
| Subscription Management  | ✅  | ✅      |
| Promotional Offers       | ✅  | N/A     |
| StoreKit 2               | ✅  | N/A     |
| Billing Client v8+       | N/A | ✅      |

## Version Information

- **Current Version**: 1.0-beta
- **Godot Compatibility**: Godot 4.3+
- **iOS Requirements**: iOS 15.0+ (via [openiap](https://openiap.dev))
- **Android Requirements**: API level 24+ (via [openiap](https://openiap.dev))

## Quick Start

Get started with godot-iap in minutes:

```gdscript
extends Node

var iap: GodotIap

func _ready():
    # Get the plugin instance
    if Engine.has_singleton("GodotIap"):
        iap = Engine.get_singleton("GodotIap")
        _setup_signals()
        _init_connection()

func _setup_signals():
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)
    iap.products_fetched.connect(_on_products_fetched)

func _init_connection():
    var result = iap.init_connection()
    print("Init connection: ", result)
```

### Fetch Products

```gdscript
func _on_init_success():
    var product_ids = ["your.product.id", "your.premium.subscription"]
    var skus_json = JSON.stringify(product_ids)
    iap.fetch_products(skus_json, "inapp")  # or "subs" for subscriptions

func _on_products_fetched(products_dict):
    if products_dict.get("success", false):
        var products_json = products_dict.get("productsJson", "[]")
        var products = JSON.parse_string(products_json)
        for product in products:
            print("Product: ", product.title, " - ", product.displayPrice)
```

### Handle Purchases

```gdscript
func purchase_product(product_id: String):
    var params = {
        "sku": product_id,
        "ios": { "quantity": 1 },
        "android": { "skus": [product_id] }
    }
    iap.request_purchase(JSON.stringify(params))

func _on_purchase_updated(purchase_dict):
    var product_id = purchase_dict.get("productId", "")
    var purchase_state = purchase_dict.get("purchaseState", "")

    if purchase_state == "purchased":
        # Verify on your server, then finish
        iap.finish_transaction(JSON.stringify(purchase_dict), true)

func _on_purchase_error(error_dict):
    print("Error: ", error_dict.get("code"), " - ", error_dict.get("message"))
```

## Start Building Today

<div className="next-steps-grid-intro">
  <a href="/godot-iap/getting-started/installation" className="next-step-card-intro gradient-purple">
    <div className="next-step-icon-intro">🚀</div>
    <h3 className="next-step-title-intro">Quick Start</h3>
    <p className="next-step-desc-intro">Get up and running with godot-iap in minutes</p>
    <span className="next-step-arrow-intro">→</span>
  </a>

  <a href="/godot-iap/guides/purchases" className="next-step-card-intro gradient-pink">
    <div className="next-step-icon-intro">📚</div>
    <h3 className="next-step-title-intro">Guides</h3>
    <p className="next-step-desc-intro">Step-by-step tutorials and best practices</p>
    <span className="next-step-arrow-intro">→</span>
  </a>

  <a href="/godot-iap/api" className="next-step-card-intro gradient-blue">
    <div className="next-step-icon-intro">⚡</div>
    <h3 className="next-step-title-intro">API Reference</h3>
    <p className="next-step-desc-intro">Complete API documentation with examples</p>
    <span className="next-step-arrow-intro">→</span>
  </a>

  <a href="/godot-iap/examples/purchase-flow" className="next-step-card-intro gradient-green">
    <div className="next-step-icon-intro">💻</div>
    <h3 className="next-step-title-intro">Examples</h3>
    <p className="next-step-desc-intro">Production-ready code samples</p>
    <span className="next-step-arrow-intro">→</span>
  </a>
</div>

<style>{`
  .next-steps-grid-intro {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1.5rem;
    margin: 2rem 0;
  }

  .next-step-card-intro {
    display: block;
    padding: 2rem;
    border-radius: 12px;
    color: white;
    text-decoration: none;
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    position: relative;
    overflow: hidden;
  }

  /* Light mode gradients */
  .gradient-purple {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  }

  .gradient-pink {
    background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
    box-shadow: 0 4px 12px rgba(240, 147, 251, 0.3);
  }

  .gradient-blue {
    background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
    box-shadow: 0 4px 12px rgba(79, 172, 254, 0.3);
  }

  .gradient-green {
    background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
    box-shadow: 0 4px 12px rgba(67, 233, 123, 0.3);
  }

  /* Dark mode - much darker backgrounds with subtle gradients */
  [data-theme='dark'] .gradient-purple {
    background: linear-gradient(135deg, #4a3d7a 0%, #5a4685 100%);
    box-shadow: 0 4px 12px rgba(74, 61, 122, 0.3);
    border: 1px solid rgba(139, 159, 232, 0.3);
  }

  [data-theme='dark'] .gradient-pink {
    background: linear-gradient(135deg, #7a3d6b 0%, #85465f 100%);
    box-shadow: 0 4px 12px rgba(122, 61, 107, 0.3);
    border: 1px solid rgba(244, 176, 250, 0.3);
  }

  [data-theme='dark'] .gradient-blue {
    background: linear-gradient(135deg, #3d5a7a 0%, #466685 100%);
    box-shadow: 0 4px 12px rgba(61, 90, 122, 0.3);
    border: 1px solid rgba(127, 195, 254, 0.3);
  }

  [data-theme='dark'] .gradient-green {
    background: linear-gradient(135deg, #3d7a5a 0%, #468566 100%);
    box-shadow: 0 4px 12px rgba(61, 122, 90, 0.3);
    border: 1px solid rgba(111, 238, 159, 0.3);
  }

  .next-step-card-intro:hover {
    transform: translateY(-8px);
    text-decoration: none;
  }

  .next-step-card-intro:hover {
    box-shadow: 0 12px 24px rgba(0, 0, 0, 0.2) !important;
  }

  [data-theme='dark'] .next-step-card-intro:hover {
    box-shadow: 0 12px 24px rgba(0, 0, 0, 0.6) !important;
    border: 1px solid rgba(255, 255, 255, 0.2) !important;
  }

  .next-step-icon-intro {
    font-size: 3rem;
    margin-bottom: 1rem;
    filter: drop-shadow(0 2px 4px rgba(0,0,0,0.2));
  }

  .next-step-title-intro {
    font-size: 1.5rem;
    font-weight: 700;
    margin-bottom: 0.5rem;
    color: white !important;
  }

  /* Dark mode - high contrast white text */
  [data-theme='dark'] .next-step-title-intro {
    color: #ffffff !important;
    text-shadow: 0 2px 4px rgba(0,0,0,0.8);
    font-weight: 800;
  }

  .next-step-desc-intro {
    font-size: 1rem;
    opacity: 0.95;
    margin-bottom: 1rem;
    color: white !important;
    line-height: 1.5;
  }

  /* Dark mode - high contrast white text for description */
  [data-theme='dark'] .next-step-desc-intro {
    color: #f0f0f0 !important;
    opacity: 1;
    text-shadow: 0 1px 3px rgba(0,0,0,0.6);
    font-weight: 500;
  }

  .next-step-arrow-intro {
    font-size: 1.25rem;
    font-weight: 700;
    color: white !important;
  }

  /* Dark mode - high contrast white arrow */
  [data-theme='dark'] .next-step-arrow-intro {
    color: #ffffff !important;
    text-shadow: 0 2px 4px rgba(0,0,0,0.8);
    font-weight: 800;
  }

  /* Force white text on all child elements in dark mode */
  [data-theme='dark'] .next-step-card-intro * {
    color: white !important;
  }

  /* Ensure links don't change color on hover */
  .next-step-card-intro:hover .next-step-title-intro,
  .next-step-card-intro:hover .next-step-desc-intro,
  .next-step-card-intro:hover .next-step-arrow-intro {
    color: white !important;
  }
`}</style>

## Community & Support

This project is maintained by [hyochan](https://github.com/hyochan).

- **GitHub Issues**: [Report bugs and feature requests](https://github.com/hyochan/godot-iap/issues)
- **Discussions**: [Join community discussions](https://github.com/hyochan/godot-iap/discussions)
- **Contributing**: [Contribute to the project](https://github.com/hyochan/godot-iap/blob/main/CONTRIBUTING.md)

---

Ready to implement in-app purchases in your Godot game? Let's [get started](/godot-iap/getting-started/installation)!
