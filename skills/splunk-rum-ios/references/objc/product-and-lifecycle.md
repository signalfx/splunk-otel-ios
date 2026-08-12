# Objective-C Product And Lifecycle

## Guidance

If initialization lives in Objective-C, link `SplunkAgentObjC`. Do not link both
products by default. Do not add a Swift lifecycle wrapper just to initialize an
Objective-C app.

Use the existing ObjC app delegate when present. For mixed apps, choose the file
that already owns startup.

Before `apply`, get the app name and deployment environment from Host App
configuration or the user; never write placeholders. Defer the endpoint and
redact `NSError`; see
`endpoint-and-runtime-state.md`.

```objc
@import SplunkAgentObjC;

- (void)startSplunkRumWithAppName:(NSString *)appName
            deploymentEnvironment:(NSString *)deploymentEnvironment {
    NSError *error = nil;
    SPLKAgentConfiguration *config =
        [[SPLKAgentConfiguration alloc] initWithEndpoint:nil
                                                 appName:appName
                                   deploymentEnvironment:deploymentEnvironment];
    self.splunkRum = [SPLKAgent installWith:config error:&error];
    if (self.splunkRum == nil) {
        // Non-fatal. Do not log raw error; it may contain config values.
        NSLog(@"Splunk RUM agent did not start. Check configuration values.");
    }
}
```

This installs and starts the agent. Telemetry is queued locally until the user
adds an endpoint after apply.
