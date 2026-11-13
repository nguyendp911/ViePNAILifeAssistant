# ViePN AI Life – implemented API and next milestones

## Endpoint summary

All `/v1/` routes require `Authorization: Bearer VIEPN_GATEWAY_TOKEN` and JSON bodies for POST. Health is public. The prototype has a single shared account.

| Method | Path | Operation |
|---|---|---|
| GET | `/health` | service check |
| POST | `/v1/chat` | invoke configured AI provider for answer |
| GET / POST | `/v1/tasks` | list/create tasks |
| GET / POST | `/v1/memories` | list/create opt-in memories; POST needs `consent: true` |
| GET | `/v1/memories/search?q=...` | keyword search |
| DELETE | `/v1/memories/{id}` | remove memory |
| GET / POST | `/v1/profiles` | read/create reply style profiles |
| DELETE | `/v1/profiles/{id}` | delete profile |
| POST | `/v1/replies/draft` | AI draft only, never sends |
| GET | `/v1/skills` | allowlisted skills |
| GET / POST | `/v1/automations` | read/create schedule (disabled unless enabled) |
| POST | `/v1/automations/{id}/enable` | enable schedule |
| POST | `/v1/automations/{id}/disable` | disable schedule |
| POST | `/v1/automations/tick` | propose pending approval for due jobs |
| GET | `/v1/approvals` | inspect pending/executed approval records |
| POST | `/v1/approvals/{id}/approve` | execute one approved pending operation |
| POST | `/v1/approvals/{id}/reject` | reject pending operation |
| GET / POST | `/v1/workflows` | list/create validated 1–10 step workflows |
| POST | `/v1/workflows/{id}/steps/{stepId}/approve` | execute exactly one approved step |
| POST | `/v1/workflows/{id}/steps/{stepId}/reject` | reject workflow |
| GET | `/v1/notes` | list notes |

## Minimal structured example

```json
{"title":"Báo cáo hàng ngày","intervalMinutes":1440,"skill":"create_note","payload":{"title":"Tổng kết","content":"Xem lại công việc hôm nay"},"enabled":false}
```

## Remaining milestones before release

1. Incoming Share Extension and App Group data handoff, real App Intents for tasks, and background lifecycle tests.
2. AI function calling with strict schema parsing and preview-before-approve; never run arbitrary shell or scripts from model output.
3. Replace JSON with an encrypted production database; authenticated multi-account users, rate limits and quotas, server-side audit log and backup/restore.
4. Proper calendar/email OAuth consent integration and explicit send confirmations. Any Zalo/Messenger functionality must use supported legal integrations or user-initiated sharing.
5. Implement StoreKit and subscription receipt verification; privacy disclosures, account deletion, test on physical iOS devices, verified CI, TestFlight and App Store review.
