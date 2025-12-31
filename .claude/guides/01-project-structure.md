# Project Structure

## Directory Layout

```
godot-iap/
├── android/                # Android plugin (Kotlin)
├── ios-gdextension/        # iOS plugin (SwiftGodot)
├── Example/                # Godot example project
│   ├── addons/godot-iap/   # Plugin addon
│   │   ├── bin/ios/        # iOS frameworks
│   │   └── bin/android/    # Android AARs
│   └── ios/                # Exported Xcode project
├── scripts/                # Build scripts
├── docs/                   # Docusaurus documentation
└── Makefile                # Main build commands
```

## Dependencies

- **Android**: `io.github.hyochan.openiap:openiap-google:1.3.+`
- **iOS**: `https://github.com/hyodotdev/openiap.git` (SwiftGodot)

## Quick Commands

```bash
make run-ios       # Build, export, open Xcode
make run-android   # Build, export, install on device
make help          # Show all commands
```
