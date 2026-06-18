# Hybrid Apps

## Load when

Load when the Host App shows a hybrid SDK such as React Native or Flutter, or
another generated native iOS wrapper around a cross-platform app.

## Do not load when

Do not load for a normal native Swift/Objective-C iOS app. For native
`WKWebView` usage inside a native app, use `instrumentation/webview.md`.

## Source files to verify

- Host App `package.json`, Metro config, and `ios/Podfile` for React Native
  evidence
- Host App `pubspec.yaml`, Flutter project layout, and `ios/Runner.*` files for
  Flutter evidence
- Product-specific public docs and repo docs for the detected hybrid SDK
- Host App generated iOS project files only to understand native build impact
- `release/crash-and-dsym.md` for narrow native iOS dSYM upload work
- `instrumentation/webview.md` only for explicit native `WKWebView` Browser RUM
  bridge work

## Required output additions

- Hybrid framework evidence and confidence.
- Recommended owner: product-specific hybrid SDK, native iOS SDK, or narrow
  native iOS subtask.
- Any generated-file or package-manager risks.
- Explicit out-of-scope items and suggested follow-up ticket when needed.

## Guidance

Hybrid apps such as React Native and Flutter have their own Splunk SDK
surfaces, package managers, generated native projects, and platform setup. Do
not directly add or initialize `SplunkAgent` in the generated iOS project as
the default response to "add Splunk RUM" for these apps.

Default recommendation:

- React Native: use the Splunk React Native SDK and its current docs.
- Flutter: use the Splunk Flutter SDK and its current docs.
- Native Swift/Objective-C app: continue with this iOS SDK Skill Bundle.

Avoid duplicate instrumentation. If a hybrid app already uses a Splunk hybrid
SDK, do not add a second native `SplunkRum.install` path unless the user
explicitly asks for a native-only investigation and the product docs support
that pattern.

Treat generated iOS files as high-risk edit targets. Before editing
`ios/Podfile`, generated Xcode projects, Flutter `Runner` files, or CI scripts,
report why the edit belongs in the hybrid app's native layer and require
explicit approval.

Narrow native iOS subtopics can stay in this Skill Bundle when explicitly in
scope:

- locating or uploading dSYMs for the iOS archive
- reviewing iOS build/link errors caused by the native SDK dependency chain
- inspecting a native `WKWebView` bridge only when the app-controlled Browser
  RUM precondition is satisfied

Do not handle React Native JavaScript source maps, Flutter Dart symbolication,
hybrid navigation APIs, or hybrid SDK initialization from this iOS skill unless
the product-specific hybrid docs are loaded and the user explicitly asks for
that cross-repo work. Prefer a separate ticket in the React Native or Flutter
repo for broad hybrid skill coverage.
