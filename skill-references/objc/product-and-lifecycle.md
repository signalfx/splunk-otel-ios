# Objective-C Product And Lifecycle

Load when the Host App has `.m`, `.h`, `main.m`, `UIApplicationMain`,
Objective-C app delegates, bridging headers, or `SplunkAgentObjC`.

## Guidance

If initialization lives in Objective-C, link `SplunkAgentObjC`. Do not link both
products by default. Do not add a Swift lifecycle wrapper just to initialize an
Objective-C app.

Use the existing ObjC app delegate when present. For mixed apps, choose the file
that already owns startup.

Write deferred-endpoint initialization during `apply`. Do not log raw `NSError`.
The endpoint is added by the user after apply — see the post-apply handoff in
`endpoint-and-runtime-state.md`.

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
    NSLog(@"Splunk RUM agent did not start. Check configuration values.");
}
```

This installs and starts the agent. Telemetry is queued locally until the user
adds an endpoint after apply.
