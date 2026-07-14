# Release readiness gate

`tool/release_readiness.ps1` audits release configuration without changing app or store state.

```powershell
.\tool\release_readiness.ps1
.\tool\release_readiness.ps1 -Strict
```

The default command writes `reports/release/release-readiness.json` and exits successfully so the report can be used while release credentials are intentionally absent. `-Strict` exits with code 1 when a blocker remains and is the command to enable for the release branch.

## Enforced checks

- Android application ID is syntactically valid and not an example namespace.
- Android release does not use the debug signing key.
- The release manifest declares `RECORD_AUDIO` and does not declare `INTERNET`.
- The iOS bundle identifier is not an example namespace.
- `NSMicrophoneUsageDescription` is present and non-empty.
- The Flutter version uses `major.minor.patch+build` format.
- Store-facing privacy policy and Play Data Safety worksheet are committed.

`tool/check.ps1` runs the gate's isolated self-test. It does not run strict release validation because signing credentials and store documents are intentionally incomplete during development.

## Current release blockers

As of 2026-07-14:

- Android release still uses the debug signing key.
- `docs/privacy-policy.md` has not been finalized.
- `docs/play-data-safety.md` has not been finalized.

Dependency license classification is reported as a warning until the dedicated GPL deny gate is implemented. App naming, store listing, Play Console upload, closed testing, and iOS device validation remain human/external gates and cannot be inferred from repository configuration.
