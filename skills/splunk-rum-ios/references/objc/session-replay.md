# Objective-C Session Replay

Use `SplunkAgentObjC` and verify these current public surfaces:

- `SPLKSessionReplayConfiguration`
- `SPLKSessionReplayModule`
- `SPLKSessionReplayModuleSensitivity`
- `SPLKSessionReplayModuleCustomID`
- `SPLKRecordingMask`, `SPLKMaskElement`, `SPLKMaskElementType`
- `SPLKRenderingMode`
- `SPLKSessionReplayStatus`

## Configuration and start

```objc
SPLKSessionReplayConfiguration *replayConfig =
    [[SPLKSessionReplayConfiguration alloc] initWithEnabled:YES
                                               samplingRate:@0.25];

SPLKAgent *agent = [SPLKAgent installWith:configuration
                     moduleConfigurations:@[replayConfig]
                                    error:&error];

// Only after the approval and privacy review required by the core reference:
[agent.sessionReplay start];
```

## Sensitivity, IDs, and rendering

For sensitivity, custom IDs, rendering, or recording-mask work, load
`../instrumentation/session-replay-privacy.md`. Objective-C selectors include:

```objc
[agent.sessionReplay.sensitivity setSensitivity:@YES forView:paymentField];
[agent.sessionReplay.sensitivity setSensitivity:@YES forViewClass:UITextField.class];

checkoutButton.splk_splunkRumID = @"checkout.submit";
[agent.sessionReplay.customIdentifiers setCustomID:@"checkout.total"
                                           forView:totalLabel];

agent.sessionReplay.preferences.renderingMode = SPLKRenderingMode.wireframeOnly;
```

`splk_splunkRumID` labels both Session Replay and interaction spans.
`setCustomID:forView:` affects Session Replay only.

Do not add a Swift wrapper only to configure Session Replay.
