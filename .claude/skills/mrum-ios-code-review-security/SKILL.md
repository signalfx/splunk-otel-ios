---
name: mrum-ios-code-review-security
description: Swift/ObjC security review checklist. Covers secrets, ATS, Keychain, PII logging, and certificate pinning.
user-invocable: false
---

# Security

## Secrets and Credentials in Code
Scan for any of the following inadvertently left in source files, config files, plists, or test fixtures:
- API keys, auth tokens, bearer tokens, access tokens, refresh tokens.
- AWS ARNs, AWS access key IDs (`AKIA...`), AWS secret keys.
- Cloud provider credentials: GCP service account JSON, Azure connection strings.
- Splunk ingest tokens, HEC tokens, realm identifiers with embedded secrets.
- Private keys, certificates, PEM/P12 file contents inlined as strings.
- OAuth client secrets, JWT signing keys.
- Database connection strings with embedded passwords.
- Hardcoded passwords, passphrases, or PIN codes.
- Base64-encoded blobs that decode to any of the above.
- URLs containing credentials in query parameters or userinfo (e.g., `https://user:pass@host`).

Also flag:
- Secrets in comments or documentation (even "example" values that look real).
- Test files using production credentials instead of mocks/fakes.
- `.xcconfig` files or `Info.plist` entries with hardcoded secret values.

## Network Security
- `NSAllowsArbitraryLoads` or ATS exceptions without justification.
- Missing certificate pinning for sensitive network calls.

## Data Storage
- Storing sensitive data in `UserDefaults` instead of Keychain.

## Logging and PII
- Logging sensitive user data (PII, credentials, tokens) via `NSLog`, `os_log`, `print`, or custom logging.
- User-facing error messages that leak internal system details.

## Objective-C Specifics
- Format string vulnerabilities (`NSLog` with user-controlled strings).
