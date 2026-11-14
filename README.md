# ViePN AI Life V4.8 — AI Conversation 2.0

**Nâng cấp mới nhất:** hội thoại AI nhiều lượt, chọn provider/model theo cấu hình an toàn trên Gateway, đọc câu trả lời bằng giọng Việt ngay trên iPhone.

- **AI Assistant 2.0:** chỉ gửi tối đa 12 lượt lịch sử chat gần nhất để trả lời tin nhắn hiện tại; không tự gửi bộ nhớ, tài liệu, công việc hoặc dữ liệu Google.
- **Chọn model:** Gateway hỗ trợ OpenAI-compatible và Gemini native, chỉ hiện model được cấu hình. API key ở server, không đóng gói vào IPA.
- **TTS tiếng Việt:** nút Nghe, Dừng, Sao chép từng câu trả lời; tùy chọn Tự đọc mặc định tắt.
- **Lịch sử riêng tư:** lưu cục bộ tách theo tài khoản, xóa để bắt đầu hội thoại mới; không ghi nhật ký chat lên Gateway.
- **API mới:** `GET /v1/ai/providers` (danh mục model không chứa khóa), `POST /v1/chat` (có `history`, `providerId`, `model`).
- **Hạn chế:** streaming token và quản lý nhiều cuộc hội thoại riêng biệt chưa có trong V4.8; các tính năng AI thực tế cần Gateway cấu hình model và API key hợp lệ.
- Xem [hướng dẫn V4.8 AI Conversation](docs/V4.8-AI-CONVERSATION.md). IPA được build **chưa ký** và vẫn cần ký profile Apple cho app cùng Share Extension.

---

# ViePN AI Life V4.7 — Task Manager 2.0

**Mã nguồn iOS + Gateway đã nâng cấp.** Kiểm tra build và trạng thái ký trong GitHub Actions.

- **Home → Task Manager 2.0:** quản lý công việc có ngày/giờ, mức ưu tiên, tối đa 8 nhãn, tối đa 20 công việc con; chỉnh sửa/xóa và lọc công việc.
- **Lặp lại hằng ngày/tuần/tháng:** tạo lần xuất hiện tiếp theo khi hoàn thành, không tạo trùng kể cả khi mở lại công việc đã hoàn thành.
- **Smart Planner → Đặt hạn & chi tiết:** tạo việc có hạn ngay từ Home; vẫn giữ cách thêm nhanh không đặt hạn.
- **Ưu tiên xuyên các hệ thống:** Smart Day, kế hoạch ngày/tuần và phân tích cá nhân tôn trọng mức ưu tiên mới bên trong từng nhóm hạn.
- **Hợp nhất Smart Reminders:** Home, Profile, Settings cùng sử dụng một giao diện nhắc việc. Có lựa chọn xóa lịch UUID cũ sau khi người dùng xác nhận.
- **API:** `POST /v1/tasks`, `PATCH /v1/tasks/:id`, `DELETE /v1/tasks/:id` và `GET /v1/tasks`; dữ liệu cũ vẫn tương thích.
- Tài liệu: [V4.7 Task Manager 2.0](docs/V4.7-TASK-MANAGER.md).
- Build iOS tạo **IPA chưa ký** và chưa thay đổi quyền App ID; Apple ID miễn phí còn phụ thuộc hạn mức 10 App ID/7 ngày và profile cho Share Extension.

---

# ViePN AI Life V4.6 — Smart Reminders

**Mã nguồn SwiftUI đã cập nhật; CI macOS kiểm thử bộ lọc nhắc việc và build iOS IPA chưa ký.**

- **Home → Smart Reminders:** thông báo hạn công việc cục bộ trên iPhone, có thể xuất hiện ngay cả khi ứng dụng đã đóng.
- **Quyền riêng tư:** mặc định tắt, chỉ xin quyền khi người dùng bấm bật; mặc định ẩn tên công việc trong thông báo.
- **Tùy chỉnh:** đúng hạn, trước 5/15/60 phút hoặc 1 ngày; tối đa 48 thông báo gần hạn nhất.
- **Đồng bộ có kiểm soát:** chỉ điều chỉnh theo dữ liệu Gateway đã đồng bộ thành công; đăng xuất/đổi tài khoản hoặc tắt tính năng sẽ hủy các lịch nhắc của ViePN.
- Không có push server, background AI, Google Calendar write hoặc quyền tự tạo công việc. Chi tiết: [V4.6 Smart Reminders](docs/V4.6-SMART-REMINDERS.md).
- IPA chưa ký; ký miễn phí 7 ngày vẫn phụ thuộc Apple App ID/profile phù hợp cho app và Share Extension.

---

# ViePN AI Life V4.5 — Proactive Assistant

**Đã thêm mã nguồn Gateway + giao diện SwiftUI.** Build iOS qua GitHub Actions tạo IPA **chưa ký**.

- **Home → Proactive Assistant:** phát hiện công việc quá hạn, đến hạn trong 3 ngày, yêu cầu chờ duyệt và đề xuất lập kế hoạch khi có nhiều việc.
- **Tạm ẩn / nhắc lại:** 4 giờ, 24 giờ (API), hoặc 7 ngày; tự hết hạn và có thể hiện lại.
- **Soạn đề xuất:** chỉ tạo workflow ghi chú đang chờ **phê duyệt thủ công** trong Action Center; không tự thực thi.
- **Quyền riêng tư:** chỉ tổng hợp dữ liệu của tài khoản trên Gateway; không AI, Google hay theo dõi nền.
- **REST:** `GET /v1/proactive`, `POST /v1/proactive/snooze`, `POST /v1/proactive/reset`, `POST /v1/proactive/queue`.
- Xem [tài liệu V4.5](docs/V4.5-PROACTIVE-ASSISTANT.md). Chưa kiểm thử thao tác thực tế trên iPhone và không bỏ giới hạn App ID của Apple.

---

# ViePN AI Life V4.4 – Personal Intelligence

**Status:** Gateway & SwiftUI source updated; CI builds unsigned IPA. Device testing and Apple free-ID signing remain separate.

- **Personal Intelligence (Home):** task completion %, overdue and upcoming work, 8 bounded priorities, optional self-reported focus-history comparison.
- **Personal AI Assistant:** each question requires selecting task/memory/document sharing scopes and ticking consent again. All data scopes default off; no hidden account data transfer.
- **Protected requests:** `GET /v1/insights` is private and read-only; `POST /v1/ai/personal-ask` rejects absent consent and returns 503 without forwarding data when no AI provider is configured.
- **No autonomous changes:** AI suggestions cannot create events, tasks, emails or modify account data.
- [V4.4 implementation notes](docs/V4.4-PERSONAL-INTELLIGENCE.md).
- IPA contains the Share Extension and is **unsigned**. Apple free-ID 7-day signing is still subject to quota.

---

# ViePN AI Life Assistant V4.3 – Weekly Intelligence

**Trạng thái:** Đã triển khai mã nguồn Gateway và giao diện iOS; IPA được build qua GitHub Actions ở dạng **chưa ký**, chưa kiểm thử trực tiếp trên iPhone.

- **Home → Weekly Intelligence:** gợi ý lịch tuần này hoặc tuần sau, chọn ngày làm việc và khung giờ; phân loại ưu tiên, chia đều phiên tập trung, cảnh báo nguy cơ trễ hạn.
- **Focus Habits (tự nguyện):** mặc định tắt, chỉ ghi phiên khi người dùng tự nhấn xác nhận; lưu số phút/số phiên/giờ bắt đầu theo ngày, không giám sát nền.
- **Xóa dữ liệu thói quen:** tắt và xóa toàn bộ lịch sử bằng một thao tác có xác nhận.
- **Action Center:** bản kế hoạch chỉ tạo workflow ghi chú chờ duyệt, không thực thi, không tạo lịch Google.
- API: `POST /v1/weekly-plan/preview`, `GET /v1/focus-history`, `POST /v1/focus-history/consent`, `POST /v1/focus-history/record`.
- Chi tiết tại [V4.3 Weekly Intelligence](docs/V4.3-WEEKLY-INTELLIGENCE.md). Lịch Google chỉ áp dụng cho Daily Planner V4.2, chưa hỗ trợ tránh giờ bận trong tuần.
- Đây không phải cách vượt giới hạn 10 App ID của Apple ID miễn phí; app + Share Extension cần profile tương thích khi ký 7 ngày.

---

# ViePN AI Life Assistant V4.2 – AI Daily Assistant

**Trạng thái:** Gateway V4.2 và giao diện iOS SwiftUI đã được cập nhật trên GitHub. Bản IPA do GitHub Actions build **chưa ký**. Xem [ghi chú kỹ thuật V4.2](docs/V4.2-DAILY-ASSISTANT.md).

### V4.2 – Lập kế hoạch trong ngày

- **Home / Smart Day → AI Daily Assistant**: chọn giờ làm việc, thời gian tập trung/nghỉ, và số công việc muốn xếp lịch.
- Đề xuất thứ tự ưu tiên theo hạn; tránh trùng các khoảng Google Calendar bận khi **chủ động bật** tùy chọn.
- Lời khuyên AI chỉ được gọi nếu người dùng **chủ động bật**; khi đó tiêu đề công việc và giờ gợi ý được gửi đến AI provider đã cấu hình.
- Bản nháp không thay đổi dữ liệu. Gửi bản nháp sang Action Center chỉ tạo một yêu cầu **chờ phê duyệt**, không tự lưu/thi hành.
- API: `POST /v1/daily-plan/preview`; kiểm thử TypeScript, Node logic và HTTP qua GitHub Actions.
- Không thêm quyền iOS mới; việc cài IPA 7 ngày vẫn yêu cầu ký đúng app và Share Extension, phụ thuộc giới hạn App ID của Apple.

---

# ViePN AI Life Assistant V4.1 – Smart Day

**Trạng thái:** Mã nguồn đã cập nhật trên GitHub; iOS IPA được build qua GitHub Actions và cần ký bằng Apple ID/profile của bạn trước khi cài. Kết quả build V4.1 xem ở tab Actions.

### Mới trong V4.1

- **Home → Smart Day:** bảng tổng hợp công việc đến hạn hôm nay, quá hạn, sắp tới và chưa đặt hạn; ưu tiên tối đa 12 công việc, có nút hoàn thành.
- **Action Center:** xem thống kê yêu cầu phê duyệt đang chờ (hành động riêng, workflow, automation), đi đến màn hình duyệt khi cần.
- **Lịch tự động 48 giờ:** xem tối đa 5 lịch sắp đến hạn, không thực thi khi mở Smart Day.
- **Quyền riêng tư:** `GET /v1/briefing?offsetMinutes=420` chỉ tổng hợp dữ liệu tài khoản đang xác thực; không gọi mô hình AI hay Google, không gửi thông báo, không thay đổi dữ liệu.
- **Kiểm thử:** unit tests cho ranh giới ngày Việt Nam, tác vụ đã hoàn thành, duyệt thủ công, giới hạn kết quả và request không xác thực; HTTP smoke test và TypeScript CI.
- Không có cơ chế vượt giới hạn App ID Apple. IPA có Share Extension cần profile đúng cho từng extension khi ký miễn phí 7 ngày.

Xem [mô tả Smart Day V4.1](docs/V4.1-SMART-DAY.md).

---

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
