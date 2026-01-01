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

Visit the [documentation site](https://hyochan.github.io/godot-iap) for [installation guides](https://hyochan.github.io/godot-iap/getting-started/installation), [API reference](https://hyochan.github.io/godot-iap/api), and [examples](https://hyochan.github.io/godot-iap/examples/purchase-flow).

## Installation

1. Download `godot-iap-{version}.zip` from [GitHub Releases](https://github.com/hyochan/godot-iap/releases)
2. Extract and copy `addons/godot-iap/` to your project's `addons/` folder
3. Enable the plugin in **Project → Project Settings → Plugins**

See the [Installation Guide](https://hyochan.github.io/godot-iap/getting-started/installation) for more details.

## Quick Start

See the [Quick Start Guide](https://hyochan.github.io/godot-iap/#quick-start) for complete code examples and setup instructions.

## License

MIT License - see [LICENSE](LICENSE) file for details.
