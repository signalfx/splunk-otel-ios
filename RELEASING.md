# How to Release Splunk RUM for iOS

This project is distributed as a Swift Package. The release process is driven by creating and pushing versioned Git tags.

## Pre-flight

1. Confirm all features for the release are merged to `develop`.
2. Confirm `CHANGELOG.md` on `develop` has complete `[Unreleased]` entries, each with a PR link (e.g. `#123`).

## Release

3. Run the **"New release"** workflow from the Actions tab, targeting `develop`, with the version (e.g. `2.3.2`) and Jira ticket (e.g. `DEMRUM-1234`). The action will prepare a release pull request.
4. On the resulting PR, click **"Approve workflows to run"** when prompted, then approve the PR and wait for all checks to pass.
5. Ask a repo admin to merge the PR into `main` — **regular merge commit only** (not squash, not rebase merge). Admins can bypass the stuck CLA check if needed (see Known issue below).
6. After the release PR is merged into `main`, a new tag and release will be created automatically, and a new back-merge PR into `develop` will be opened.

## Sign and upload xcframeworks

7. With the Apple Distribution certificate in your keychain and the Session Replay repo checked out locally:
   ```bash
   SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay \
     tools/xcframework/scripts/sign-and-upload.sh <VERSION> --upload-to <VERSION>
   ```

## Back-merge

8. On the back-merge PR, click **"Approve workflows to run"**, approve the PR, and wait for checks to pass.
9. Ask a repo admin to: (1) temporarily disable **"Require linear history"** on `main` in Settings → Branches, (2) merge the PR into `develop` — **regular merge commit only** (not squash, not rebase merge), (3) re-enable **"Require linear history"** on `main`.

## Smoke test

10. In a test app, add an SPM dependency on `signalfx/splunk-otel-ios` at the new version.
11. In Xcode: **File → Packages → Reset Package Caches**, then **File → Packages → Resolve Package Versions**.
12. Build and run. Confirm sessions appear in mon0 with `rum.sdk.version` matching the new version.

## Manual workflow (automated steps broken down)

Use this if any part of the automated workflow fails and needs to be reproduced manually.

1. Create the release branch from `develop`:
   ```bash
   git checkout develop && git pull
   git checkout -b release/<VERSION>
   ```
2. In `CHANGELOG.md`, rename `[Unreleased]` to `[<VERSION>] - YYYY-MM-DD` and add a new empty `[Unreleased]` section above it.
3. Bump the version constant in `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum.swift`.
4. Build the project and run the full test suite to ensure everything is passing:
   ```bash
   xcodebuild build -scheme SplunkAgent -destination 'generic/platform=iOS Simulator'
   xcodebuild test -scheme SplunkAgent -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
5. Commit, push, and open a PR from `release/<VERSION>` to `main`. Title: `DEMRUM-XXXX: Release <VERSION>`.
6. Merge the PR — **regular merge commit only** (not squash, not rebase merge).
7. Create and push a signed tag. Swift Package Manager uses these tags to resolve package versions:
   ```bash
   git checkout main && git pull
   git tag -s v<VERSION> -m "v<VERSION>"
   git push origin v<VERSION>
   ```
8. On the GitHub Releases page, draft a new release for the tag. Paste the `[<VERSION>]` section from `CHANGELOG.md` as the release notes and publish.
9. Open a PR from `main` to `develop`. Title: `NO-TICKET: Merge back <VERSION> to develop`.
10. Merge the PR — **regular merge commit only** (not squash, not rebase merge). Requires temporarily disabling "Require linear history" on `main` (see Back-merge section above).

## Known issue: CLA check stuck

The `ContributorLicenseAgreement` check on bot-created PRs may remain stuck as "Waiting for status to be reported" after all other checks pass. This is a known workflow issue pending a fix. If it occurs, ask a repo admin to perform the merge — admins have the ability to bypass the stuck required check.
