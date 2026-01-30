# Framework-Based Integration

Learn how to integrate SplunkAgent when building an intermediate framework.

## Overview

If your app architecture uses an intermediate framework (e.g., a "Core" module) that integrates SplunkAgent, you need to explicitly add the binary dependencies product to ensure proper linking.

This is due to a known Swift Package Manager limitation where binary targets (xcframeworks) are not automatically embedded when consumed through an intermediate framework.

## The Problem

When SplunkAgent is added to a framework (not directly to an app target), Swift Package Manager links but does not embed the transitive binary dependencies. This causes runtime crashes on real devices with errors like:

```
Library not loaded: @rpath/CiscoDiskStorage.framework/CiscoDiskStorage
```

## Solution

Add both `SplunkAgent` and `SplunkAgentBinaryDependencies` to your framework:

1. In Xcode, select your framework target
2. Go to **General** > **Frameworks, Libraries, and Embedded Content**
3. Add `SplunkAgent` (if not already added)
4. Add `SplunkAgentBinaryDependencies`
5. Set both to **Embed & Sign**

## Architecture Example

If your app has this structure:

```
YourApp
├── Module A (links CoreFramework)
├── Module B (links CoreFramework)
└── CoreFramework
    ├── SplunkAgent              ← Add this
    └── SplunkAgentBinaryDependencies  ← Add this too
```

Both products must be added to `CoreFramework` to ensure the binary dependencies are properly embedded and available at runtime.

## Why This Works

The `SplunkAgentBinaryDependencies` product explicitly exposes all the binary framework dependencies (CiscoDiskStorage, CiscoLogger, etc.) that SplunkAgent uses internally. By adding this product to your intermediate framework, you make these dependencies visible to Xcode's build system, which then correctly embeds them in the final app bundle.

## See Also

- <doc:Getting-Started>
- <doc:Modules-Overview>
