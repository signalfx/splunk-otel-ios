# Bulding, testing, and contributing to this project

## Dependencies

Due to Swift's package management not being compatible with CocoaPods and OpenTelemetry Swift not supporting it either, it was decided all dependencies would be included in-source.

The list of dependencies can be found in `dependencies.txt` with a link to the repository and a specific commit.

OpenTelemetry Swift is a minimal version where unnecessary parts are stripped out, meaning only Zipkin and Stdout exporters along with the tracing SDK are brought in.

## Building

Open SplunkRumWorkspace in Xcode; everything should be wired up correctly to
run unit tests in SplunkRum or use one of the test apps to try things out.

`./fullbuild.sh` is what the CI runs, and it requires `swiftlint`:
`brew install swiftlint` or your local equivalent first.  This also runs
the unit tests and can take a couple of minutes; be patient.

Note that `swift build` will not work since the code depends on UIKit which is
not available on MacOS.  Accordingly, `fullbuild.sh` executes a `swift build` with 
options to perform an iOS build.

## Releasing

- Branch to vX.Y.Z.  Update the constant `SplunkRumVersionString` in `SplunkRum.swift`.  Merge this as usual.
- git tag -s x.y.z (exactly like the semver string, no "v" prefix, etc.)
- git push origin x.y.z

## Contributing

See [the CONTRIBUTING document](./CONTRIBUTING.md)
