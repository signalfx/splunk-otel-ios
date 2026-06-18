# Objective-C UIKit, Storyboards, And Navigation

## Load when

Load for Objective-C UIKit apps, storyboard apps, ObjC navigation tracking, or
mixed apps where navigation code is ObjC.

## Do not load when

Do not load for pure SwiftUI navigation.

## Source files to verify

- Host App `.storyboard`, ObjC view controllers, `SceneDelegate.m`,
  `AppDelegate.m`
- `SplunkAgent/Sources/SplunkAgentObjC/Modules/Navigation/`
- `SplunkAgent/Sources/SplunkAgent/SplunkAgent.docc/Modules/Navigation-Tracking.md`

## Required output additions

- Storyboard and controller evidence.
- Automated/manual ObjC navigation decision.
- Whether SceneDelegate or view controllers are touched.

## Guidance

Do not edit storyboards just to install RUM. Initialize in the app delegate and
add screen tracking in existing controllers when needed.

Use SceneDelegate only for scene-specific work if the app already centralizes
that behavior there.

Avoid Swift-only APIs such as SwiftUI `.trackScreen` in `.m` files. Verify ObjC
selectors in the bridge source before recommending them.

Current ObjC manual screen selectors:

```objc
[self.splunkRum.navigation trackScreen:@"Account"];
[self.splunkRum.navigation trackScreen:@"Account"
                            attributes:@{ @"screen.source": @"tab" }];
```

To enable automated tracking during install, verify
`SPLKNavigationConfiguration` and pass it in `moduleConfigurations`:

```objc
SPLKNavigationConfiguration *navigationConfig =
    [[SPLKNavigationConfiguration alloc] initWithEnabled:YES
                                      automatedTracking:YES];
```
