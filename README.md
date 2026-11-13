# ViePN AI Life Assistant V4.0 (engineering preview)

**Release status:** V4.0 source code preview; **NOT a verified signed IPA or App Store-ready release**. This version is based on V3.6 and includes optional V3.7 vector search, V3.8 manual workflow failure recovery, V3.9 revisioned foreground snapshot sync, and V4.0 test/release documentation.

See [V4.0 implementation report](docs/V4.0-IMPLEMENTATION.md) and [release checklist](docs/RELEASE_CHECKLIST.md).

# ViePN AI Life Assistant – V3.1 Premium UI engineering prototype

**SwiftUI iOS 17+ • Node.js 22 TypeScript AI Gateway • GitHub Actions • No Python.**

This is an **engineering prototype**, not a production-ready autonomous personal assistant. The core features are programmed, but full iOS Xcode build, device validation, App Store review, and service deployment have **not** been completed. No separate project repository was created or pushed.

## V3.1 UI/UX continuation (latest)

- Rebuilt native SwiftUI shell with five tabs: **Home, AI, Actions, Library, Profile**.
- Added Premium Minimal AI visual system with adaptive surfaces, gradient hero, 3-metric dashboard, quick shortcuts, approval cards and profile hub.
- Implemented compact Library sections for Documents, Notes and opt-in Memory.
- Added device-local recent chat history with iOS complete file protection, excluded from backup and manually clearable from the conversation toolbar.
- Added HTTPS gateway reachability check in Settings (does not validate bearer token; use refresh for authenticated requests).
- Added UI specifications (`docs/V3.1-DESIGN-SYSTEM.md`) and release gate checklist (`docs/V3.1-RELEASE-GATES.md`).
- Verified Swift *syntax only*, Node logic tests (20/20) and HTTP integration smoke test. **Actual iOS build, device UX testing and strict TypeScript check remain unverified.**

## Implemented

- **Stage 1 (foundation):** Chat through a configured OpenAI-compatible HTTPS provider, Vietnamese speech-to-text, photo OCR with Apple Vision, tasks, memories with explicit consent, application lock, Keychain-stored gateway token.
- **Stage 2 (action/document):** Validated note→task workflows, explicit per-step approval, action history; PDF text extraction, multi-page PDF export, iOS ShareLink; on-device local notification scheduling; a basic App Intent to open the app. **Incoming Share Extension and model-generated workflows are still missing.**
- **Stage 3 (personalization):** Opt-in memory search (keyword-based, not semantic); manual communication profiles and AI-written reply drafts that are never sent automatically.
- **Stage 4 (skills/scheduling):** Fixed allowlisted skills, recurring task/note requests, off-by-default automation, due-job generation as pending approvals, duplicate-resolution protection, manual polling and optional server-side scheduler. No external apps controlled.
- **Stage 5 (foundation):** API tests, integration smoke tests, CI for Node and unsigned iOS builds, permission boundaries, secret-in-Keychain pattern and local reminders. **Production authentication, database, auditing, load testing, StoreKit and app release are not done.**

## V3.0 continuation

- AI-generated and structured **preview-only** plans for notes and tasks, with an allowlist and per-step approval. Model output cannot execute arbitrary commands.
- Task completion toggle in dashboard, `PATCH /v1/tasks/:id`.
- Accent-insensitive Vietnamese keyword memory search (not semantic vectors).
- Personal JSON export without gateway tokens or provider API keys, shared via the iOS Share Sheet.
- 20/20 Node logic tests plus end-to-end HTTP API checks. The typecheck and actual Xcode build are still unverified in this environment.

See `docs/V3.0-IMPLEMENTATION.md` for precise endpoint details, test results and limitations.

## Repository structure

```
ViePN-AI-Life/
  ios/project.yml                       XcodeGen iOS app configuration
  ios/ViePNAILife/Sources/             SwiftUI screens, networking, OCR, notifications, intent
  gateway/src/server.ts                Bearer-protected REST API
  gateway/src/core.ts                  Validated basic actions
  gateway/src/workflows.ts             Approval-based multiple-step flows
  gateway/src/personal.ts              Profiles, memory search, skills and scheduler
  gateway/src/planner.ts               Strict preview-only task/note AI proposals
  gateway/test/*.test.ts               Unit tests
  gateway/test/api.integration.mjs     Real HTTP smoke tests
  .github/workflows/                  CI and unsigned IPA build
  docs/                                Architecture, API and release checklists
```

## Run locally (Windows PowerShell)

Install **Node.js 22+** and then:

```powershell
cd gateway
Copy-Item .env.example .env
# Edit .env: use your own long random VIEPN_GATEWAY_TOKEN; configure AI provider separately
node --env-file=.env --experimental-strip-types src/server.ts
```

Check `http://localhost:8787/health`. Unit tests need no internet:

```powershell
node --experimental-strip-types --test test/*.test.ts
node test/api.integration.mjs
```

For strict typechecks, install dependencies when npm is accessible:

```powershell
npm install
npm run check
```

**Production HTTPS:** Host Node behind a TLS reverse proxy, access with an `https://` URL and paste the gateway token in iOS Settings. Never put AI provider keys inside IPA or source control. The gateway currently uses **one bearer token and a JSON file for a single user**. Don't expose it to multiple users; implement per-account OAuth sessions, authorization, quota, encrypted database and backups first.

## iOS build

The `ios/project.yml` is an XcodeGen project; build on macOS using the included Actions workflow, which will produce an unsigned IPA if successful. Signing requires your own App ID, provisioning profile and matching entitlements. `swiftc -frontend -parse` on Linux checks syntax but **does not prove an iOS build succeeds**.

## Scheduling

A recurring automation is **disabled by default**, and requires explicit enablement. To generate approval requests when jobs are due, open Skills & Automation → *Kiểm tra các lịch đến hạn*, or set `VIEPN_AUTOMATION_POLL=true` on an **always-on server** to poll every minute. Neither route performs the action without user approval. iOS local reminders are separate notifications and do not require this server.

## Privacy/limitations

This project cannot read third-party messages, detect Zalo/Facebook recipients in the background, send them messages, or silently operate other apps. OCR uses locally chosen photos. The assistant does not train on stored memories, but requested text may be sent to the configured AI model provider when you ask for AI output. The current data store is not suitable for storing sensitive third-party/customer information. Review `docs/RELEASE_CHECKLIST.md` before any public deployment.


## V3.2 — Multi-user gateway and on-device account isolation

Implemented: separate bearer tokens per account using `VIEPN_ACCOUNTS_JSON`, validation of account IDs and tokens, per-account JSON state under `data/users/<id>.json`, tenant-specific exports, account identity endpoint `GET /v1/me`, a serialized write queue, and account-specific local chat files on iOS. The previous `VIEPN_GATEWAY_TOKEN` still works as **legacy single-user mode** and retains the existing `VIEPN_DATA_FILE`.

**Do not expose this prototype gateway directly to the public Internet.** It is not a production-grade identity service. Tokens are administratively provisioned, without signup, MFA, OAuth, rate limiting, device revocation or a supported recovery flow. Use HTTPS behind an authenticated reverse proxy or private VPN, isolate secrets, restrict backups, and plan a PostgreSQL migration and audited user account system before public release.

Run `cd gateway && npm test && npm run test:api` to verify all core rules and multi-account isolation. `npm run check` requires downloading npm development dependencies. On iOS, change the gateway URL/token in Profile and save, then refresh. Previous on-device chat history is scoped by credentials; the old global `chat-history.json` is not migrated to avoid accidental cross-account exposure.

No Xcode IPA build has been run for V3.2. GitHub Actions remains configured to do that when the project is pushed to a dedicated repository.

## V3.4 — PostgreSQL account & session foundation

- Add optional PostgreSQL mode via `DATABASE_URL`. Legacy JSON account mode remains available when no database is configured.
- Native SwiftUI Security Center now has **Register**, **Login**, **Logout** using `/v1/auth/*`.
- PostgreSQL stores user records, salted scrypt password hashes, hashed bearer session tokens, and user-scoped JSONB state.
- Seven-day sessions, session revocation, lockout after repeated incorrect passwords.
- New logic tests for credentials and scrypt; PostgreSQL integration tests must run with a real database before deployment.
- V3.2 data **is not automatically migrated**. See `docs/V3.4-POSTGRES-AUTH.md` for security limitations and production setup.
- Node.js `npm install` and complete TypeScript typecheck were not possible in the packaging environment because the npm registry was inaccessible; those steps are included in GitHub Actions.
- iOS Swift parser validation passed but full macOS Xcode compilation has not been performed. No IPA has been built.

## V3.4 native integrations

- Share Extension: plain text and web URLs only. Open Safari → Share → ViePN AI Life, then in app Library → Nội dung chia sẻ. Review and send a workflow to Action Center; **no automatic note creation**. Shared drafts are stored in App Group preferences for up to 7 days, max 20 drafts/8000 characters each, and are deleted from the inbox only after a workflow is created.
- App Intents: open the host app from Siri/Shortcuts. No unattended actions.
- Foreground data refresh: on app activation, capped to one refresh per minute per session; manual pull-to-refresh remains available. iOS background delivery is not guaranteed.
- Signing: App Group `group.com.viepn.ailife` MUST be enabled in Apple developer portal for BOTH `com.viepn.ailife` and `com.viepn.ailife.share`; sign each target with its own matching provisioning profile. Unsigned IPA can be built but cannot be installed without signing.
- Source confidentiality: Shared draft text resides in App Group UserDefaults, accessible to the app and extension. Do not share confidential material before device trust and provisioning are established.
- CI builds are unverified until macOS GitHub Actions succeeds.


## V3.5 – Advanced AI / Knowledge Library

- Added a native SwiftUI Knowledge Library page (Library → Kho tri thức AI). Import UTF-8 TXT or text-layer PDF locally; inspect text before uploading intentionally to Gateway.
- Gateway API: `GET/POST /v1/documents`, `DELETE /v1/documents/:id`, `GET /v1/knowledge/search?q=...`, `POST /v1/knowledge/ask` with `{"question":"...","useAI":false}`.
- Corpus is stored **per account** via existing account storage. It is included in the `/v1/export` response.
- Documents split into <=1,000-character blocks; accent-insensitive weighted token retrieval returns exact document IDs and segment references. This is *lexical retrieval*, not a vector embedding semantic search.
- Optional model-based synthesis uses the already configured AI gateway and attaches retrieved references; citations are evidence candidates and are not automatically claim-verified. No sources = no model answer.
- 120,000 characters/doc, 200 documents/account; no binary PDF uploaded.
- This is a prototype, not production readiness: full Xcode build, PostgreSQL integration, upload concurrency, token-bound pagination, rate limiting and multi-device tests remain necessary.

## V3.6 — Google Connected Services

Added native SwiftUI **Profile → Connected Services** plus tenant-isolated Google OAuth 2.0 Gateway endpoints for **read-only** Gmail summaries and Google Calendar events. The iOS app never receives a Google client secret or Google refresh token. See [V3.6 setup and security notes](docs/V3.6-GOOGLE-CONNECTIONS.md).

**Tested:** 37/37 Gateway logic tests passed under Node.js 22. **Not yet verified:** Xcode IPA compilation, live OAuth with a real Google Cloud project, PostgreSQL integration, and complete `tsc` typecheck (missing `@types/node` in this environment). A real Google connection requires user consent and configured credentials.
