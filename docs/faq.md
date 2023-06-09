## Frequently Asked Questions (FAQ)

This document services as a central place for frequently asked
questions (FAQ) and common setup and troubleshooting advice.
Please [contribute](../CONTRIBUTING.md) to this list.

### What should I do to integrate on Apple Silicon?

Apple Silicon is currently supported and should work as expected using the main instructions for getting started.

### What should I do if there are naming collisions?

If you own the code that has a collision, you can try to add the module that you want to use the symbol from. For example, if you declare a type also declared in SplunkOtel and want to use it somewhere where you import SplunkOtel, you can prefix it's use with the module your symbol comes from (ex: `MyModule.MyConflictingType`).

### Why can’t I see see any metrics / data in the RUM UI?

- Look for simulator debug logs (by setting `debug` to `true` in SplunkRumOptions).
- Ensure that the `rumAuth` and `beaconUrl` are correctly set up.
    - The token must be active and part of the org you are trying to send data to.
    - The beaconUrl/realm must be the same as the Observability RUM interface you are logging into.

### Why am I not seeing HTTP requests in the RUM UI?

Splunk RUM for iOS supports libraries  based on Apple's URLSession, which includes other libraries like AFNetworking and AlamoFire, but not Apple's deprecated API called NSURLConnection.

Consider setting up `ignoreUrls` if you already have another telemetry library or SDK set up

Splunk RUM on iOS uses moethod swizzling like many other tools (Firebase Performance Monitoring, for example). Having two tools setup to capture network calls might cause issues and undefined behavior.

### Why are my crashes not showing up in the RUM UI?

First, make sure Splunk Otel Crash Reporting is the only crash reporter you have enabled. For example, if you also have Crashlytics running, make sure you disable it and try again.

Second, make sure you are opening the app after a crash so the report is sent.

### Will this work side by side with other tools?

Some other tools include similar functionality to Splunk Otel. In these cases, it can result in undefined behavior as they both attempt to leverage similar techniques in order to track and produce user usage data. It is best to use one tool for these purposes.

For example, Firebase Performance Monitoring also performs some method swizzling for event tracking. Depending on the order agents are setup, behaviors could change. It is best to use one tool as using various tools leads to undefined behavior.

Using multiple crash reporting libraries can also cause issues. Splunk RUM Crash Reporting uses PLCrashReporter, and might other 3rd party libraries you are using.

Crash reporting on iOS is an optional feature; please don't turn it on unless a crash reporter is not present already.

### What should I do if Xcode fails to resolve package dependencies?

If you use any of the [dependencies](../dependencies.txt) that Splunk Rum uses you will need to see if the versions can be resolved to their versioning rules.

Sometimes though, Xcode might fail to fetch a particular dependency and then present a dialog that it failed to resolve. If you see no potential versioning rule issue, it is best to just try adding the package again. Perhaps after closing and reopening Xcode.

### Can I use this along side Cocoapods?

Yes! Please check our available distributions for a newly added Cocoapod. If you wish to use the SPM distribution, you may, but will need to be aware that any potential overlap in dependencies will not be able to be resolved by Xcode or Cocoapods.

For example if you use a Cocoapod that has a dependency that is also a dependency in Splunk Otel, you will likely get symbol collision.

It is also important that you add the SPM package to the app's project and not the Pods project in your workspace.

### I need an XCFramework. Is that available?

Although we do not currently distribute an XCFramework, we do have instructions on how to create one [here](<link to docs>).


### I am getting Sqlite redefinition errors. What should I do?

If you are using another tool that uses sqlite like WCDB, then you might have to look at removing the `use_frameworks!` line in your Podfile if you are using Cocoapods. Other users have been unblocked with this change.