# Bulding, testing, and contributing to this project

## Building

Open SplunkRumWorkspace in Xcode; everything should be wired up correctly to
run unit tests in SplunkRum or use one of the test apps to try things out.

`./fullbuild.sh` is what the CI runs, and it requires `swiftlint`:
`brew install swiftlint` or your local equivalent first.  This also runs
the unit tests and can take a couple of minutes; be patient.

Note that `swift build` will not work since the code depends on UIKit which is
not available on the mac.

## Community Contributions

If you are not a Splunk employee and would like to contribute code to this project, please read and fill out the
[Splunk CLA](https://www.splunk.com/en_us/form/contributions.html).
