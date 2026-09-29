# Hybrid Apps

## Guidance

Hybrid apps have their own Splunk SDK surfaces, package managers, generated
native projects, and platform setup. Do not directly add or initialize
`SplunkAgent` in the generated iOS project as the default response to "add
Splunk RUM" for these apps.

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

Narrow native iOS subtopics that can stay in this Skill Bundle when explicitly
in scope:

- locating or uploading dSYMs for the iOS archive
- reviewing iOS build/link errors caused by the native SDK dependency chain
- inspecting a native `WKWebView` bridge only when the app-controlled Browser
  RUM precondition is satisfied

Do not handle React Native JavaScript source maps, Flutter Dart symbolication,
hybrid navigation APIs, or hybrid SDK initialization from this iOS skill unless
the product-specific hybrid docs are loaded and the user explicitly asks for
that cross-repo work.
