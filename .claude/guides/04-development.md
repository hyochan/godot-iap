# Development Guide

## VSCode Setup

**Run and Debug (F5):**
- 🍎 iOS: Build & Run
- 🤖 Android: Build & Run
- 🎮 Godot: Run Example
- 📚 Docs: Dev Server

**Run Task (Cmd+Shift+B):**
- 🍎 iOS: Build, Export & Run
- 🤖 Android: Build, Export & Run

## Version Management

`openiap-versions.json` - OpenIAP dependency versions:
```json
{
  "apple": "1.3.9",
  "google": "1.3.21",
  "gql": "1.3.11"
}
```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/fix_ios_embed.sh` | Patch Xcode project for framework embedding |
| `scripts/generate-types.sh` | Download GDScript types from openiap releases |

## Troubleshooting

### iOS: dyld Library not loaded
Framework not embedded. Run `make run-ios` which auto-patches the Xcode project.

### macOS Editor: GDExtension not found
Normal - iOS plugin only supports iOS platform, not macOS editor.

### Android: Plugin not found
Check `Example/addons/godot-iap/bin/android/` has AAR files and `.gdap` manifest.
