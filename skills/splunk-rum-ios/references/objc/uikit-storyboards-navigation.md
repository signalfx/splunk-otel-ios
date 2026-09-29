# Objective-C UIKit, Storyboards, And Navigation

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

To enable automated tracking during install, verify `SPLKNavigationConfiguration`
and pass it in `moduleConfigurations`:

```objc
SPLKNavigationConfiguration *navigationConfig =
    [[SPLKNavigationConfiguration alloc] initWithEnabled:YES
                                      automatedTracking:YES];
```
