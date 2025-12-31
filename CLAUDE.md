# CLAUDE.md - Godot IAP Project Guidelines

This document outlines conventions and guidelines for the godot-iap project.

## Project Overview

godot-iap is a Godot 4.x plugin for in-app purchases following the [OpenIAP](https://openiap.dev) specification.

### Architecture

```
godot-iap/
├── android/           # Android plugin (Kotlin)
│   ├── src/main/
│   │   ├── java/      # Kotlin sources
│   │   └── AndroidManifest.xml
│   └── build.gradle.kts
├── ios/               # iOS plugin (Swift)
│   ├── Sources/
│   └── Package.swift
├── Example/           # Godot example project
│   ├── addons/godot-iap/
│   ├── main.gd
│   └── project.godot
└── .vscode/           # Development tools
```

## Naming Conventions

### Acronym Usage

1. **IAP (In-App Purchase)**:
   - When final suffix: Use `IAP` (e.g., `GodotIAP`)
   - When followed by other words: Use `Iap` (e.g., `IapManager`)

2. **ID (Identifier)**:
   - Always use `Id` (e.g., `productId`, `transactionId`)

3. **Platform-specific suffixes**:
   - iOS: `IOS` suffix (e.g., `PurchaseIOS`)
   - Android: `Android` suffix (e.g., `PurchaseAndroid`)

### GDScript Conventions

```gdscript
# Class names: PascalCase
class_name IapManager

# Function names: snake_case
func init_connection() -> bool:
    pass

func request_purchase(product_id: String) -> Dictionary:
    pass

# Signal names: snake_case
signal purchase_updated(purchase: Dictionary)
signal purchase_error(error: Dictionary)

# Constants: SCREAMING_SNAKE_CASE
const PRODUCT_PREMIUM := "com.example.premium"
```

## Dependencies

### Android (openiap-google)

```kotlin
// build.gradle.kts
dependencies {
    implementation("io.github.hyochan.openiap:openiap-google:1.3.+")
}
```

### iOS (openiap-apple)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/hyodotdev/openiap.git", from: "1.3.0")
]
```

## OpenIAP Specification

All implementations must follow OpenIAP standards:

- **APIs**: https://openiap.dev/docs/apis
- **Types**: https://openiap.dev/docs/types
- **Events**: https://openiap.dev/docs/events
- **Errors**: https://openiap.dev/docs/errors

### Core Methods

| Method | Description |
|--------|-------------|
| `initConnection()` | Initialize store connection |
| `endConnection()` | Close connection |
| `fetchProducts(skus)` | Get product info |
| `requestPurchase(params)` | Start purchase |
| `finishTransaction(purchase, isConsumable)` | Complete transaction |
| `restorePurchases()` | Restore purchases |

### Signals/Events

| Signal | Payload |
|--------|---------|
| `purchase_updated` | `{ productId, purchaseState, ... }` |
| `purchase_error` | `{ code, message, ... }` |

## Build & Testing

### Android

```bash
cd android
./gradlew assembleRelease

# Output: android/build/outputs/aar/
```

### iOS

```bash
cd ios
swift build -c release

# For device:
xcodebuild -scheme GodotIap -destination 'generic/platform=iOS' -configuration Release
```

### Running Example

```bash
# Open Godot editor
/Applications/Godot.app/Contents/MacOS/Godot --editor --path Example

# Or use VSCode launch configurations
```

## VSCode Development

Use the provided launch configurations:

- **🎮 Godot: Open Editor** - Open Godot editor with Example project
- **🔨 Build: Android** - Build Android plugin
- **🔨 Build: iOS** - Build iOS plugin
- **📱 Xcode: Open Example** - Open exported iOS project

## Pre-Commit Checklist

1. Code compiles without errors
2. GDScript passes linting
3. Android: `./gradlew build` succeeds
4. iOS: `swift build` succeeds
5. Example project runs in editor

## Contributing

1. Follow naming conventions above
2. Test on both platforms when possible
3. Update documentation for API changes
4. Reference OpenIAP spec for new features
