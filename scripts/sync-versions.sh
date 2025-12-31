#!/bin/bash
# Sync OpenIAP versions from openiap-versions.json to platform configs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="$PROJECT_ROOT/openiap-versions.json"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: openiap-versions.json not found at $VERSIONS_FILE"
    exit 1
fi

# Read versions from JSON
APPLE_VERSION=$(python3 -c "import json; print(json.load(open('$VERSIONS_FILE'))['apple'])")
GOOGLE_VERSION=$(python3 -c "import json; print(json.load(open('$VERSIONS_FILE'))['google'])")

echo "OpenIAP Versions:"
echo "  Apple: $APPLE_VERSION"
echo "  Google: $GOOGLE_VERSION"

# Update iOS Package.swift from template
TEMPLATE_FILE="$PROJECT_ROOT/ios-gdextension/Package.swift.template"
PACKAGE_FILE="$PROJECT_ROOT/ios-gdextension/Package.swift"

if [ -f "$TEMPLATE_FILE" ]; then
    sed "s/{{OPENIAP_APPLE_VERSION}}/$APPLE_VERSION/g" "$TEMPLATE_FILE" > "$PACKAGE_FILE"
    echo "Updated: ios-gdextension/Package.swift (version: $APPLE_VERSION)"
fi

# Update godot_iap_plugin.gd Android dependency
PLUGIN_FILE="$PROJECT_ROOT/Example/addons/godot-iap/godot_iap_plugin.gd"
if [ -f "$PLUGIN_FILE" ]; then
    # Use portable sed syntax (works on both macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/openiap-google:[0-9.]*\"/openiap-google:$GOOGLE_VERSION\"/g" "$PLUGIN_FILE"
    else
        sed -i "s/openiap-google:[0-9.]*\"/openiap-google:$GOOGLE_VERSION\"/g" "$PLUGIN_FILE"
    fi
    echo "Updated: Example/addons/godot-iap/godot_iap_plugin.gd (version: $GOOGLE_VERSION)"
fi

echo "Version sync complete!"
