# ViePN AI Life V4.0 — release readiness (2026-11-13)

## Verified in this delivery
- [x] Native SwiftUI sources retain Home, AI, Actions, Library, Profile, plus optional semantic search settings
- [x] TypeScript gateway logic includes tenant-scoped semantic endpoint and manual failure recovery
- [x] 42/42 backend Node unit tests pass
- [x] Swift source syntax parse succeeds on available Linux toolchain
- [x] Snapshot sync endpoint supports revisions and ETags (read-side foundation)

## Blocking V4.0 production release gates
- [ ] TypeScript `tsc --noEmit` succeeds after npm packages are available
- [ ] API integration tests pass with PostgreSQL and migrated schema
- [ ] Google OAuth verified with real consent screen, redirect URL and minimal scopes
- [ ] XcodeGen generates project, Swift typecheck/build passes on macOS with supported Xcode
- [ ] End-to-end tests on a physical iPhone (Share Extension, microphone, OCR, lock, reminders)
- [ ] Developer account provisioning profiles created for app and share extension with App Groups
- [ ] Gateway production auth, rate limits, abuse mitigation, TLS, secure logging, encrypted backups, deletion and incident recovery
- [ ] True multi-device write conflict handling and background queue/retry
- [ ] Provider privacy notice and consent for embedding data export; verify embedding API limits
- [ ] Signed TestFlight build, accessibility tests, crash reporting, privacy disclosures, App Store review

**This is not a completed commercial product until the above gates are addressed.**
