# Objective-C Product And Lifecycle

Load when the Host App has `.m`, `.h`, `main.m`, `UIApplicationMain`,
Objective-C app delegates, bridging headers, or `SplunkAgentObjC`.

## Guidance

If initialization lives in Objective-C, link `SplunkAgentObjC`. Do not link both
products by default. Do not add a Swift lifecycle wrapper just to initialize an
Objective-C app.

Use the existing ObjC app delegate when present. For mixed apps, choose the file
that already owns startup.

Safe ObjC init must not print raw `NSError`.

```objc
@import SplunkAgentObjC;

// Replace <YOUR_REALM> with your Splunk Observability realm (e.g. us0, eu0).
// Supply SPLUNK_RUM_TOKEN via the app's existing secret/configuration
// mechanism — see post-apply handoff for options.
NSString *token = NSProcessInfo.processInfo.environment[@"SPLUNK_RUM_TOKEN"] ?: @"";
SPLKEndpointConfiguration *endpoint =
    [[SPLKEndpointConfiguration alloc] initWithRealm:@"<YOUR_REALM>"
                                      rumAccessToken:token];

NSError *error = nil;
SPLKAgentConfiguration *config =
    [[SPLKAgentConfiguration alloc] initWithEndpoint:endpoint
                                             appName:@"<YOUR_APP_NAME>"
                               deploymentEnvironment:@"<YOUR_ENVIRONMENT>"];
self.splunkRum = [SPLKAgent installWith:config error:&error];
if (self.splunkRum == nil) {
    // Non-fatal. Do not log raw error; it may contain config values.
}
```

The `<YOUR_REALM>` placeholder is intentional — the agent does not know the
user's realm and must not guess it. The user fills it in after apply (see
post-apply handoff in `endpoint-and-runtime-state.md`).
