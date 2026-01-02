---
title: AI Assistants
sidebar_label: AI Assistants
sidebar_position: 6
---

import IapKitBanner from '@site/src/uis/IapKitBanner';

# AI Assistants

<IapKitBanner />

godot-iap provides AI-optimized documentation files that help AI coding assistants understand and work with the library more effectively.

## AI-Optimized Documentation

| File | Description | Best For |
|------|-------------|----------|
| [llms.txt](https://hyochan.github.io/godot-iap/llms.txt) | Concise quick reference (~300 lines) | Quick lookups, simple questions |
| [llms-full.txt](https://hyochan.github.io/godot-iap/llms-full.txt) | Complete API reference (~1000 lines) | Complex implementations, detailed guidance |

## Cursor

### Adding to Project Rules

1. Open Cursor Settings (`Cmd/Ctrl + ,`)
2. Navigate to **Features > Docs**
3. Click **Add new doc**
4. Enter the URL: `https://hyochan.github.io/godot-iap/llms-full.txt`
5. Give it a name like "godot-iap"

### Using @Docs

Once added, you can reference the documentation in your prompts:

```
@godot-iap How do I implement subscription purchases?
```

### Alternative: Project-Level .cursorrules

Create a `.cursorrules` file in your project root:

```
# godot-iap Documentation
When working with godot-iap, refer to:
- Quick reference: https://hyochan.github.io/godot-iap/llms.txt
- Full API: https://hyochan.github.io/godot-iap/llms-full.txt

This project uses godot-iap for in-app purchases following the OpenIAP specification.
```

## GitHub Copilot

### In VS Code / Cursor

Reference the documentation URL directly in your chat:

```
Using the godot-iap library (docs: https://hyochan.github.io/godot-iap/llms-full.txt),
how do I implement a purchase flow in GDScript?
```

### Custom Instructions

Add to your GitHub Copilot custom instructions:

```
When working with Godot in-app purchases, I use godot-iap.
Documentation: https://hyochan.github.io/godot-iap/llms-full.txt
The library follows OpenIAP specification and provides typed GDScript APIs.
```

## Claude / ChatGPT

### Direct URL Reference

Simply include the documentation URL in your prompt:

```
I'm using godot-iap for Godot Engine. Here's the documentation:
https://hyochan.github.io/godot-iap/llms-full.txt

How do I implement consumable purchases with proper error handling?
```

### Project Context

For Claude Projects or ChatGPT custom GPTs, add these as knowledge sources:

1. Download the text files
2. Upload as project knowledge/context
3. Reference in system prompts

## Direct URL Access

Access the raw documentation files directly:

- **Quick Reference**: https://hyochan.github.io/godot-iap/llms.txt
- **Full API Reference**: https://hyochan.github.io/godot-iap/llms-full.txt

## What's Included

### llms.txt (Quick Reference)

- Project overview and version info
- Installation steps
- Quick start code example
- Core API method signatures
- Key types and enums
- Common usage patterns
- Error handling basics
- Platform requirements

### llms-full.txt (Complete Reference)

- Full installation and setup guide
- Complete API documentation with all methods
- All type definitions with properties
- iOS-specific API reference
- Android-specific API reference
- All signals with payload details
- Comprehensive error code list
- Detailed implementation patterns
- Subscription management examples
- Troubleshooting guide

## Example Prompts

Here are some effective prompts to use with AI assistants:

### Basic Implementation

```
Using godot-iap (https://hyochan.github.io/godot-iap/llms-full.txt),
create a complete IAP manager class that:
1. Initializes the connection
2. Fetches products
3. Handles purchases
4. Properly finishes transactions
```

### Subscription Flow

```
With godot-iap docs at https://hyochan.github.io/godot-iap/llms-full.txt,
implement subscription upgrade/downgrade functionality for Android
using replacement modes.
```

### Error Handling

```
Based on godot-iap documentation (https://hyochan.github.io/godot-iap/llms.txt),
implement comprehensive error handling with:
- Retry logic for network errors
- User-friendly messages
- Proper logging
```

### Cross-Platform

```
Using the godot-iap library (see https://hyochan.github.io/godot-iap/llms-full.txt),
show me how to handle platform differences between iOS and Android
for purchase verification.
```

## Tips for Better Results

### 1. Be Specific About the Platform

```
# Good
"How do I check subscription status on iOS using godot-iap?"

# Less effective
"How do I check subscriptions?"
```

### 2. Reference the Documentation Type

```
# For detailed implementation
"Using godot-iap full API reference, implement..."

# For quick lookup
"According to godot-iap quick reference, what's the signature for...?"
```

### 3. Include Version Context

```
"I'm using godot-iap v1.0 with Godot 4.3 and StoreKit 2.
How do I implement promotional offers?"
```

### 4. Provide Code Context

```
"I have this purchase handler:
[your code]

Using godot-iap docs, how do I add proper transaction finishing?"
```

## Feedback

If you find issues with the AI documentation or have suggestions for improvement:

- **GitHub Issues**: [Report documentation issues](https://github.com/hyochan/godot-iap/issues)
- **Discussions**: [Share feedback](https://github.com/hyochan/godot-iap/discussions)

We continuously improve these files based on common AI assistant interactions and user feedback.
