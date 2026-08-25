# Objective-C Session Replay

Use `SplunkAgentObjC` and verify these current public surfaces:

- `SPLKSessionReplayConfiguration`
- `SPLKSessionReplayModule`
- `SPLKSessionReplayModuleSensitivity`
- `SPLKSessionReplayModuleCustomID`
- `SPLKRecordingMask`, `SPLKMaskElement`, `SPLKMaskElementType`
- `SPLKRenderingMode`
- `SPLKSessionReplayStatus`

## Configuration

```objc
SPLKSessionReplayConfiguration *replayConfig =
    [[SPLKSessionReplayConfiguration alloc] initWithEnabled:YES
                                               samplingRate:@0.25];

SPLKAgent *agent = [SPLKAgent installWith:configuration
                     moduleConfigurations:@[replayConfig]
                                    error:&error];
```

## Sensitivity, IDs, and rendering

For sensitivity, custom IDs, rendering, or recording-mask work, load
`../instrumentation/session-replay-privacy.md`.

Apply class-level sensitivity, rendering mode, and recording masks before
starting. Set instance sensitivity before the view can appear in a recording;
if that cannot be guaranteed, delay `start()` until it is configured.

Objective-C selectors include:

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

## Start recording

Only after explicit approval and all applicable privacy controls are in place:

```objc
dispatch_async(dispatch_get_main_queue(), ^{
    [agent.sessionReplay start];
});
```

Run Session Replay recording controls on the main queue. Apply the same rule to
`stop` when pausing recording.

Do not add a Swift wrapper only to configure Session Replay.
