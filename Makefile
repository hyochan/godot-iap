# GodotIap Build System
# Usage:
#   make setup        - Download dependencies (godot-lib.aar)
#   make ios          - Build iOS plugin
#   make android      - Build Android plugin
#   make all          - Build everything
#   make clean        - Clean build artifacts
#   make run-android  - Export and run Android APK on device
#   make run-ios      - Export iOS project and open in Xcode

GODOT_VERSION ?= 4.3
GODOT_LIB_URL = https://github.com/godotengine/godot/releases/download/$(GODOT_VERSION)-stable/godot-lib.$(GODOT_VERSION).stable.template_release.aar

# Directories
PROJECT_ROOT := $(shell pwd)
IOS_DIR := $(PROJECT_ROOT)/ios
IOS_GDEXT_DIR := $(PROJECT_ROOT)/ios-gdextension
ANDROID_DIR := $(PROJECT_ROOT)/android
EXAMPLE_DIR := $(PROJECT_ROOT)/Example
ADDON_DIR := $(PROJECT_ROOT)/Example/addons/godot-iap
BIN_DIR := $(ADDON_DIR)/bin
IOS_EXPORT_DIR := $(EXAMPLE_DIR)/ios

# Godot executable
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: all setup ios ios-build android clean help run-android run-ios export-ios export-android

help:
	@echo "GodotIap Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make setup         - Download godot-lib.aar for Android development"
	@echo "  make ios           - Build iOS plugin (uses xcodebuild)"
	@echo "  make android       - Build Android plugin"
	@echo "  make all           - Build everything"
	@echo "  make clean         - Clean all build artifacts"
	@echo ""
	@echo "Run commands:"
	@echo "  make run-android   - Build, export APK and install on connected device"
	@echo "  make run-ios       - Export iOS project and open in Xcode"
	@echo "  make export-ios    - Export iOS Xcode project only"
	@echo "  make export-android - Export Android APK only"
	@echo ""
	@echo "Environment variables:"
	@echo "  GODOT_VERSION  - Godot version to use (default: $(GODOT_VERSION))"
	@echo "  GODOT          - Path to Godot executable (default: $(GODOT))"

# Download godot-lib.aar for Android builds
setup:
	@echo "$(GREEN)Setting up build environment...$(NC)"
	@mkdir -p $(ANDROID_DIR)/libs
	@mkdir -p $(BIN_DIR)/ios
	@mkdir -p $(BIN_DIR)/ios-simulator
	@mkdir -p $(BIN_DIR)/macos
	@mkdir -p $(ADDON_DIR)/android
	@if [ ! -f "$(ANDROID_DIR)/libs/godot-lib.aar" ]; then \
		echo "$(YELLOW)Downloading godot-lib.aar ($(GODOT_VERSION))...$(NC)"; \
		curl -L -o "$(ANDROID_DIR)/libs/godot-lib.aar" "$(GODOT_LIB_URL)" || \
		(echo "$(RED)Failed to download. Try manually from: $(GODOT_LIB_URL)$(NC)" && exit 1); \
		echo "$(GREEN)✓ godot-lib.aar downloaded$(NC)"; \
	else \
		echo "$(GREEN)✓ godot-lib.aar already exists$(NC)"; \
	fi
	@echo "$(GREEN)Setup complete!$(NC)"

# Build iOS plugin (automated with xcodebuild)
ios: setup ios-build
	@echo "$(GREEN)✓ iOS plugin built$(NC)"

# Build iOS frameworks using xcodebuild
ios-build:
	@echo "$(GREEN)Building iOS frameworks...$(NC)"
	@cd $(IOS_GDEXT_DIR) && xcodebuild -scheme GodotIap -sdk iphoneos -destination 'generic/platform=iOS' -configuration Release -derivedDataPath .build-xcode build
	@echo "$(GREEN)Copying frameworks to addon...$(NC)"
	@rm -rf $(BIN_DIR)/ios/*.framework
	@cp -R $(IOS_GDEXT_DIR)/.build-xcode/Build/Products/Release-iphoneos/PackageFrameworks/GodotIap.framework $(BIN_DIR)/ios/
	@cp -R $(IOS_GDEXT_DIR)/.build-xcode/Build/Products/Release-iphoneos/PackageFrameworks/SwiftGodotRuntime.framework $(BIN_DIR)/ios/
	@echo "$(GREEN)✓ Frameworks copied$(NC)"

# Build Android plugin
android: setup gradle-wrapper
	@echo "$(GREEN)Building Android plugin...$(NC)"
	@cd $(ANDROID_DIR) && ./gradlew copyReleaseAarToAddons
	@echo "$(GREEN)✓ Android plugin built$(NC)"
	@echo "Output: $(ADDON_DIR)/android/"
	@ls -la $(ADDON_DIR)/android/*.aar 2>/dev/null || echo "  (AAR files will appear after successful build)"

# Ensure Gradle wrapper exists
gradle-wrapper:
	@if [ ! -f "$(ANDROID_DIR)/gradle/wrapper/gradle-wrapper.jar" ]; then \
		echo "$(YELLOW)Downloading Gradle wrapper...$(NC)"; \
		mkdir -p $(ANDROID_DIR)/gradle/wrapper; \
		curl -L -o $(ANDROID_DIR)/gradle/wrapper/gradle-wrapper.jar \
			"https://raw.githubusercontent.com/gradle/gradle/v8.5.0/gradle/wrapper/gradle-wrapper.jar"; \
		echo "$(GREEN)✓ Gradle wrapper downloaded$(NC)"; \
	fi

# Build everything
all: android ios
	@echo ""
	@echo "$(GREEN)All builds complete!$(NC)"

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(IOS_GDEXT_DIR)/.build
	@rm -rf $(IOS_GDEXT_DIR)/.swiftpm
	@rm -rf $(ANDROID_DIR)/build
	@rm -rf $(ANDROID_DIR)/.gradle
	@rm -f $(ADDON_DIR)/android/*.aar
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Deep clean - also removes downloaded dependencies
clean-all: clean
	@echo "$(YELLOW)Removing downloaded dependencies...$(NC)"
	@rm -f $(ANDROID_DIR)/libs/godot-lib.aar
	@rm -rf $(IOS_GDEXT_DIR)/Package.resolved
	@echo "$(GREEN)✓ Deep clean complete$(NC)"

# Export Android APK
export-android: android
	@echo "$(GREEN)Exporting Android APK...$(NC)"
	@mkdir -p $(EXAMPLE_DIR)/android
	@cd $(EXAMPLE_DIR) && $(GODOT) --headless --export-debug "Android" android/Martie.apk
	@echo "$(GREEN)✓ APK exported to $(EXAMPLE_DIR)/android/Martie.apk$(NC)"

# Run Android - Build, export and install on device
run-android: export-android
	@echo "$(GREEN)Installing APK on device...$(NC)"
	@~/Library/Android/sdk/platform-tools/adb install -r $(EXAMPLE_DIR)/android/Martie.apk
	@echo "$(GREEN)✓ APK installed$(NC)"
	@echo "$(GREEN)Launching app...$(NC)"
	@~/Library/Android/sdk/platform-tools/adb shell monkey -p dev.hyo.martie -c android.intent.category.LAUNCHER 1
	@echo "$(GREEN)✓ App launched$(NC)"

# Export iOS Xcode project
export-ios: ios
	@echo "$(GREEN)Exporting iOS Xcode project...$(NC)"
	@mkdir -p $(IOS_EXPORT_DIR)
	@cd $(EXAMPLE_DIR) && $(GODOT) --headless --export-debug "iOS" ios/Martie.xcodeproj
	@echo "$(GREEN)Fixing iOS frameworks...$(NC)"
	@cp $(BIN_DIR)/ios/GodotIap.framework/Info.plist $(IOS_EXPORT_DIR)/Martie/addons/godot-iap/bin/ios/GodotIap.framework/ 2>/dev/null || true
	@cp $(BIN_DIR)/ios/SwiftGodotRuntime.framework/Info.plist $(IOS_EXPORT_DIR)/Martie/addons/godot-iap/bin/ios/SwiftGodotRuntime.framework/ 2>/dev/null || true
	@$(MAKE) patch-ios-project
	@echo "$(GREEN)✓ iOS project exported to $(IOS_EXPORT_DIR)$(NC)"

# Patch Xcode project to embed frameworks
patch-ios-project:
	@echo "$(GREEN)Patching Xcode project to embed frameworks...$(NC)"
	@$(PROJECT_ROOT)/scripts/fix_ios_embed.sh
	@echo "$(GREEN)✓ Xcode project patched$(NC)"

# Run iOS - Build, export and open in Xcode
run-ios: export-ios
	@echo "$(GREEN)Opening Xcode...$(NC)"
	@open $(IOS_EXPORT_DIR)/Martie.xcodeproj
	@echo ""
	@echo "$(YELLOW)In Xcode:$(NC)"
	@echo "  1. Select your connected iOS device"
	@echo "  2. Press Cmd+R to build and run"
	@echo "  3. Trust the developer certificate on your device if needed"
