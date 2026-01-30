# Framework-Based Integration

Learn how to integrate SplunkAgent when building an intermediate framework.

## Overview

If your app architecture uses an intermediate framework (e.g., a "Core" module) that integrates SplunkAgent, you need to add the binary dependencies product to your **app target** to ensure proper embedding.

This is due to a known Swift Package Manager limitation where binary targets (xcframeworks) are not automatically embedded when consumed through an intermediate framework.

## The Problem

When SplunkAgent is added to a framework (not directly to an app target), Swift Package Manager links but does not embed the transitive binary dependencies. This causes runtime crashes on real devices with errors like:

```
Library not loaded: @rpath/CiscoDiskStorage.framework/CiscoDiskStorage
```

The root cause is that **frameworks cannot embed other frameworks** - only the final app target can embed frameworks into the `.app` bundle's `Frameworks/` folder. At runtime, the dynamic loader looks for frameworks in the app bundle, and if they're not embedded there, the app crashes.

## Solution

You need to add products to **two different targets**:

### Step 1: Add SplunkAgent to Your Framework

1. In Xcode, select your **framework target** (e.g., CoreFramework)
2. Go to **General** > **Frameworks, Libraries, and Embedded Content**
3. Add `SplunkAgent`
4. Set to **Do Not Embed** (frameworks cannot embed other frameworks)

### Step 2: Add Binary Dependencies to Your App Target

1. In Xcode, select your **app target** (e.g., YourApp)
2. Go to **General** > **Frameworks, Libraries, and Embedded Content**
3. Add `SplunkAgentBinaryDependencies`
4. Set to **Embed & Sign**

This ensures the binary frameworks are copied into the app bundle where the dynamic loader can find them at runtime.

## Architecture Example

If your app has this structure:

```
YourApp (App Target)
├── SplunkAgentBinaryDependencies  ← Add here (Embed & Sign)
├── Module A (links CoreFramework)
├── Module B (links CoreFramework)
└── CoreFramework (Framework Target)
    └── SplunkAgent                 ← Add here (Do Not Embed)
```

## Why This Works

- **Linking vs Embedding**: Adding `SplunkAgent` to your framework handles *linking* - making the symbols available at compile time.
- **Embedding**: Adding `SplunkAgentBinaryDependencies` to your *app target* handles *embedding* - copying the dynamic frameworks into the app bundle so they're available at runtime.
- The `SplunkAgentBinaryDependencies` product explicitly exposes all the binary framework dependencies (CiscoDiskStorage, CiscoLogger, etc.) that SplunkAgent uses internally.

## See Also

- <doc:Getting-Started>
- <doc:Modules-Overview>
