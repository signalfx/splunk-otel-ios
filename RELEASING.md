# How to Release Splunk RUM for iOS

This project is distributed through Swift Package Manager and as signed XCFramework archives attached to GitHub releases. Versioned Git tags define the versions available to Swift Package Manager.

## Pre-flight

1. Confirm all features for the release are merged to `develop`.
2. Confirm `CHANGELOG.md` on `develop` has complete `[Unreleased]` entries, each with a PR link (e.g., `#123`).

## Release

3. Run the **"New release"** workflow from the Actions tab, targeting `develop`, with the version (e.g., `2.3.2`) and Jira ticket (e.g., `DEMRUM-1234`). The action will prepare a release pull request.
4. On the resulting PR, click **"Approve workflows to run"** when prompted, obtain the required approvals, and wait for the required checks.
5. Merge the PR into `main` with a **regular merge commit only** (not squash or rebase). If the CLA check remains pending after everything else passes, use the administrator workaround below.
6. After the release PR is merged into `main`, a new tag and release will be created automatically, and a new back-merge PR into `develop` will be opened.

## Sign and upload XCFrameworks

7. With the Apple Distribution certificate and private key in your keychain and the Session Replay repository checked out locally, replace `<VERSION>` and `<APPLE_DISTRIBUTION_SIGNING_IDENTITY>` with the release values and upload both distributions:
   ```bash
   export SESSION_REPLAY_LOCAL_PATH=/path/to/session-replay
   tools/xcframework/scripts/sign-and-upload.sh <VERSION> \
     --identity "<APPLE_DISTRIBUTION_SIGNING_IDENTITY>" \
     --upload-to <VERSION>
   tools/xcframework/scripts/sign-and-upload.sh <VERSION> \
     --identity "<APPLE_DISTRIBUTION_SIGNING_IDENTITY>" \
     --ios-only \
     --upload-to <VERSION>
   ```
8. Open the GitHub release for `<VERSION>` and confirm both `SplunkAgent-XCFrameworks.zip` and `SplunkAgent-XCFrameworks-iOS-only.zip` are attached and downloadable. This check validates the uploaded XCFramework distributions; the SPM smoke test below does not validate these archives.

## Back-merge

9. On the back-merge PR, click **"Approve workflows to run"** when prompted, obtain the required approvals, and wait for the required checks.
10. Ask a repository administrator to temporarily disable **"Require linear history"** for `develop`, merge the PR into `develop` with a **regular merge commit only** (not squash or rebase), and immediately re-enable the rule. If the CLA check remains pending after everything else passes, the administrator should bypass it during this merge.

## Smoke test

11. In a test app, add an SPM dependency on `signalfx/splunk-otel-ios` at the new version.
12. In Xcode: **File → Packages → Reset Package Caches**, then **File → Packages → Resolve Package Versions**.
13. Build and run. Confirm the session appears in a testing realm with `rum.sdk.version` matching the new version.

## Manual recovery

Use this only when an automated workflow fails. Inspect the failed run and complete only the missing steps; do not recreate a branch, tag, release, or PR that already exists.

### Prepare the release PR

1. Create the release branch from `develop`:
   ```bash
   git switch develop
   git pull --ff-only
   git switch -c release/<VERSION>
   ```
2. In `CHANGELOG.md`, rename `[Unreleased]` to `[<VERSION>] - YYYY-MM-DD` and add a new empty `[Unreleased]` section above it.
3. Bump the version constant in `SplunkAgent/Sources/SplunkAgent/Public API/SplunkRum.swift`.
4. Add `<VERSION>` to the version dropdown in `.github/ISSUE_TEMPLATE/bug.yml`.
5. Build the project and run the full test suite using an installed simulator:
   ```bash
   xcodebuild -scheme SplunkAgent -destination 'generic/platform=iOS Simulator' build
   xcodebuild -scheme SplunkAgent -showdestinations
   xcodebuild -scheme SplunkAgent -destination 'OS=<installed OS>,name=<installed iPhone simulator>' test
   ```
6. Create a signed commit, push the branch, and open a PR from `release/<VERSION>` to `main`. Title: `DEMRUM-XXXX: Release <VERSION>`.
7. Merge the PR with a **regular merge commit only** (not squash or rebase). This starts the **"Release finalize"** workflow.

### Complete a failed Release finalize workflow

The workflow creates the tag, GitHub release, and back-merge PR in that order. Check which artifacts exist and perform only the missing steps.

1. If the `<VERSION>` tag is missing, create and push it without a `v` prefix. Swift Package Manager uses this tag to resolve the release:
   ```bash
   git switch main
   git pull --ff-only
   git tag -s <VERSION> -m "Release <VERSION>"
   git push origin <VERSION>
   ```
2. If the GitHub release is missing, draft one for the `<VERSION>` tag, use the `[<VERSION>]` section from `CHANGELOG.md` as its notes, and publish it.
3. If the back-merge PR is missing, open one from `main` to `develop`. Title: `NO-TICKET: Merge back <VERSION> to develop`.
4. Complete the back-merge steps above.

## Known issue: pending CLA check

The `ContributorLicenseAgreement` check on bot-created PRs may remain at "Waiting for status to be reported." After every other required check and review passes, ask a repository administrator to bypass the pending check and perform a regular merge commit. This workaround applies to both the release and back-merge PRs until the workflow is fixed.
