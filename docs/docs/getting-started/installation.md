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

```gdscript
extends Node

func _ready():
    if Engine.has_singleton("GodotIap"):
        var iap = Engine.get_singleton("GodotIap")
        print("Godot IAP is available!")
        var result = iap.init_connection()
        print("Init result: ", result)
    else:
        print("Godot IAP not available - only works on iOS/Android")
```

:::info Note
The plugin is only available on iOS and Android. `Engine.has_singleton("GodotIap")` returns `false` in the editor and on desktop platforms.
:::

## Next Steps

- [iOS Setup](./setup-ios) - App Store Connect configuration
- [Android Setup](./setup-android) - Google Play Console configuration
