# How to Release Splunk RUM for iOS

This project is distributed as a Swift Package. The release process is driven by creating and pushing versioned Git tags.

### 1. Prepare the Release

1.  Ensure the `main` branch is stable and all changes for the release have been merged.
2.  Update `CHANGELOG.md` by moving all items from the `[Unreleased]` section to a new version heading (e.g., `[2.0.0] - YYYY-MM-DD`).
3.  Update the `version` constant in `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum.swift`.

### 2. Run Final Checks

Build the project and run the full test suite from the command line to ensure everything is passing.

```bash
# Build the project
xcodebuild build -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'

# Run the tests
xcodebuild test -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'
```

### 3. Tag and Push the Release

Create a signed Git tag for the new version. Swift Package Manager uses these tags to resolve package versions.

```bash
# Create a signed tag (e.g., for version 2.0.0) with a 'v' prefix
git tag -s v2.0.0

# Push the tag to the remote repository
git push origin v2.0.0
```

### 4. Publish on GitHub

1.  Go to the "Releases" page in the GitHub repository and click "Draft a new release".
2.  Choose the tag you just pushed.
3.  For the release notes, copy and paste the content from the corresponding version section in `CHANGELOG.md`.
4.  Click the **Publish release** button. This will finalize the release, making it public and visible to the community.

