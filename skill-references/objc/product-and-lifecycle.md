# Objective-C Product And Lifecycle

## Load when

Load when the Host App has `.m`, `.h`, `main.m`, `UIApplicationMain`,
Objective-C app delegates, bridging headers, or `SplunkAgentObjC`.

## Do not load when

Do not load for pure Swift apps unless product selection is ambiguous.

## Source files to verify

- `Package.swift`
- `SplunkAgent/Sources/SplunkAgentObjC/Public API/`
- `SplunkAgent/Sources/SplunkAgentObjC/Public API/SplunkRumObjC.swift`
- Host App `main.m`, `AppDelegate.m`, `SceneDelegate.m`, bridging headers

## Required output additions

- Swift versus ObjC product decision.
- Lifecycle owner file.
- Whether mixed-language bridging is needed.
- ObjC-safe initialization plan.

## Guidance

If initialization lives in Objective-C, link `SplunkAgentObjC`. Do not link both
products by default. Do not add a Swift lifecycle wrapper just to initialize an
Objective-C app.

Use the existing ObjC app delegate when present. For mixed apps, choose the file
that already owns startup.

Safe ObjC init must not print raw `NSError`.

```objc
@import SplunkAgentObjC;

NSError *error = nil;
SPLKAgentConfiguration *config =
    [[SPLKAgentConfiguration alloc] initWithEndpoint:nil
                                             appName:@"<YOUR_APP_NAME>"
                               deploymentEnvironment:@"<YOUR_ENVIRONMENT>"];
self.splunkRum = [SPLKAgent installWith:config error:&error];
if (self.splunkRum == nil) {
    // Non-fatal. Do not log raw error; it may contain config values.
}
```

`nil` endpoint preserves deferred endpoint setup. If endpoint setup is approved,
use `SPLKEndpointConfiguration` via
`initWithRealm:rumAccessToken:` or `initWithTrace:sessionReplay:`.

Add endpoint only through an approved secret/configuration mechanism.
