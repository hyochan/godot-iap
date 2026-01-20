---
sidebar_position: 1
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# Installation

<IapKitBanner />

This guide walks you through installing Godot IAP in your Godot 4.x project.

## Prerequisites

- Godot 4.3 or higher
- For iOS: Xcode 16+ (Swift 6.0+) and iOS 15+ target
- For Android: Android SDK with API level 24+

## Installation

### Download from Releases (Recommended)

1. Download the latest `godot-iap-{version}.zip` from [GitHub Releases](https://github.com/hyochan/godot-iap/releases)
2. Extract and copy `addons/godot-iap/` to your project's `addons/` folder
3. Enable the plugin in **Project → Project Settings → Plugins**

That's it! The zip includes pre-built binaries for both iOS and Android.

### Build from Source

If you need to build from source:

```bash
git clone https://github.com/hyochan/godot-iap.git
cd godot-iap

# Build for iOS
make ios

# Build for Android
make android

# Copy addons/godot-iap/ to your project
```

## Platform Setup

### iOS

1. **Project → Export → iOS** preset
2. Enable **GodotIap** in Plugins section
3. See [iOS Setup](./setup-ios) for App Store Connect configuration

### Android

1. **Project → Export → Android** preset
2. Enable **GodotIap** in Plugins section
3. See [Android Setup](./setup-android) for Google Play Console configuration

## Verify Installation

Add `GodotIapWrapper` as a child node in your scene, then use this script:

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

@onready var iap = $GodotIapWrapper

func _ready():
    print("Godot IAP is available!")

    # Connect signals
    iap.connected.connect(_on_connected)
    iap.purchase_updated.connect(_on_purchase_updated)
    iap.purchase_error.connect(_on_purchase_error)

    # Initialize connection
    var success = iap.init_connection()
    print("Init result: ", success)

func _on_connected():
    print("Store connected!")

func _on_purchase_updated(purchase: Dictionary):
    print("Purchase: ", purchase)

func _on_purchase_error(error: Dictionary):
    print("Error: ", error)
```

:::info Note
The native plugin is only available on iOS and Android. In the editor and on desktop platforms, the plugin runs in **mock mode** which allows you to test your integration logic without actual store connections.
:::

## Scene Setup

The recommended way to use GodotIap is to add `GodotIapWrapper` as a child node in your scene:

1. Open your main scene (or create an autoload scene for IAP management)
2. Add a new node: **Add Child Node → Node**
3. Attach the GodotIapWrapper script: **Load → addons/godot-iap/godot_iap.gd**
4. Name it `GodotIapWrapper`
5. Reference it in your script using `@onready var iap = $GodotIapWrapper`

Alternatively, you can create the wrapper node programmatically:

```gdscript
extends Node

const Types = preload("res://addons/godot-iap/types.gd")

var iap

func _ready():
    # Create wrapper node dynamically
    var wrapper = preload("res://addons/godot-iap/godot_iap.gd").new()
    wrapper.name = "GodotIapWrapper"
    add_child(wrapper)
    iap = wrapper

    # Now use iap as normal
    iap.connected.connect(_on_connected)
    iap.init_connection()
```

## Next Steps

- [iOS Setup](./setup-ios) - App Store Connect configuration
- [Android Setup](./setup-android) - Google Play Console configuration
