# ViePN AI Life V1.0 – System architecture

## Trust boundaries

```
iPhone (SwiftUI) --> HTTPS + bearer token --> TypeScript gateway --> Optional external AI provider
    |                                                   |
 Local OCR (Vision)                               JSON prototype datastore
 Voice (Speech)                                   Tasks / Memory / Actions
 Keychain (token)                                 Approval gate
 Device authentication
```

## Six modules
1. **AI Chat & Voice:** Vietnamese speech-to-text and chat through authenticated AI Gateway. AI is not usable without provider configuration; no simulated responses.
2. **AI Document:** select photo, run local Vision OCR, edit/share text and request AI summary. PDF/Word parsing and formatted document exports are not implemented yet.
3. **Smart Planner:** task creation and listing; scheduling notifications and calendar integration are later milestones.
4. **Action Engine:** propose `create_task` or `save_memory`, then explicit approval/rejection; only approval executes. No arbitrary code/tool execution.
5. **AI Memory:** explicit-consent creation, view and delete. No automatic harvesting of user data.
6. **Security Center:** token in Keychain, device-owner authentication, no provider secret in client, HTTPS only.

## Data models
- Task: `id`, `title`, `dueAt` nullable ISO UTC, `done`, `createdAt`
- Memory: `id`, `text`, `createdAt`
- Action: `id`, `kind`, `payload`, `status`, `createdAt`
- Chat: messages are session-only on the client in this starter; chat persistence intentionally excluded.

## API contract
- `GET /health` anonymous
- `POST /v1/chat` body `{message}`; response `{reply,configured}`
- `GET /v1/tasks`, `POST /v1/tasks` body `{title,dueAt}`
- `GET /v1/memories`, `POST /v1/memories` body `{text,consent:true}`, `DELETE /v1/memories/:id`
- `GET /v1/actions`, `POST /v1/actions/plan` body `{kind,payload}`
- `POST /v1/actions/:id/approve`, `POST /v1/actions/:id/reject`
All `/v1` endpoints require header `Authorization: Bearer <VIEPN_GATEWAY_TOKEN>`.

## Threats and production hardening needed
This is a **single-user local/dev prototype**, not a production multi-tenant deployment. Before public launch: use OAuth/OpenID with short-lived access tokens, per-user authorization and row-level isolation, PostgreSQL migrations/transactions, encrypted backups, secret rotation, rate limiting, audit log, CSRF review as applicable, consent/version tracking, data retention/deletion, request tracing, prompt-injection and tool-output isolation, idempotency keys, background scheduler, observability and integration tests. Put gateway behind HTTPS (reverse proxy / hosting). Never ship the admin token or AI provider key in the IPA.

## iOS constraints
No access to private chats/screens of other apps. Action Engine calls supported APIs; iOS background execution is not guaranteed. Voice recognition may depend on OS support and permissions. App uses deviceOwnerAuthentication fallback (passcode if Face ID unavailable).
