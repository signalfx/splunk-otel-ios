How to release splunk-otel-ios:

* Make sure to bump the release version on both SplunkRum.swift and Podfile
* Create a release branch named “release-X.X.X” filling in X with the next release version. Ensure that this branch builds correctly.
* Run splunk-otel-ios-crashreporting locally, making sure that the dependency points to the main branch to be released. If necessary, fix any breaking issues before releasing a new version of splunk-otel-ios. Follow the following steps with splunk-otel-ios-crashreporting as well.
* Create a signed tag with `git tag -s X.X.X` filling in X with the next release version. Push this tag to the repo. You can also use Github's release flow, which will automatically sign the tag as well.
* In github, go to the releases section on the right and click the Releases header. Then click “Draft a New Release.” Choose the tag you just created (or create a new one here) and fill in release notes.
* Release the cocoapod. Follow the steps under 'Release': https://guides.cocoapods.org/making/making-a-cocoapod.html
