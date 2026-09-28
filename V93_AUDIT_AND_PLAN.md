# SocialNova V93 — Verified gap analysis + execution plan

Base: branch `v90-core-hardening` @ `012e67d` (V90 → V92).
**Note:** `main` @ `680eb10` ("Re-upload complete project") is an *ancestor* of
`v90-core-hardening` — everything from V90, V91 and V92 lives **only** on
`v90-core-hardening`. Anything built or deployed from `main` is pre-V90 and
will look "broken" (no persisted live stats, no 200-gift engine, no permissions,
no idempotency).

Method: every line below is read from the code at `012e67d`, not from a release
note. "Verified" means I could execute it in a sandbox with no Postgres and no
Flutter toolchain; everything else is marked as unverified on purpose.

---

## Audit of the 12 V93 points, against the real code

| # | Point | Status on `012e67d` | Evidence / gap |
|---|-------|--------------------|----------------|
| 1 | Nova TV (admin + posters + CRUD + continue watching) | **Partial** | `flutter-app/lib/screens/nova_tv.dart` (448 lines), player with resume, `ContinueWatching` table, `/api/continue-watching`. Missing: in-app **admin** screens for movies/series/seasons/episodes, dedicated poster/backdrop/trailer upload flow, "next episode auto-play". |
| 2 | Gifts (200+, real assets, XP, animation, one-time charge) | **Mostly done** | `backend/src/modules/gifts.js` = 210 gifts / 5 rarities / 7 categories; queue + 6 motion families in `core/nova_gifts.dart`. Missing: **real artwork** (emoji only, no `assetKey`), **XP + progress bar in the gift sheet**, and the 16 spec tabs (only 7 categories + 5 rarities exist). |
| 3 | Live (ticks, points, gifts, counters, comments, pin, delete, staff, 👁️ supporters, no stat reset) | **Mostly done** | `LiveRoom.tapCount/giftCount/giftScore`, `LiveTapCount`, `LiveMute`, `GET /api/live/stats/:roomName`, `GET /api/live/top/:roomName`, role-gated `liveStaffCan`. Gap found and **fixed in V93**: the socket `live:gift` relay accepted raw client payloads → any user could forge gifts/score into any room. |
| 4 | Calls (incoming → ringing → accept/reject → end → duration → missed → history) | **Missing** | Signalling only (`call:invite/accept/reject` socket events, `/api/calls/token`). There is **no call table/model at all** — no history, no duration, no missed-call record. |
| 5 | Admin (Users/Reports/Live/Gifts/Wallet/Creators/Rewards/Nova TV/Assets/Permissions/Security/Audit) | **Partial** | Only three in-app admin screens exist (`admin_dashboard_page`, `conversation_moderation_center`, `investigation`). Most of the above is API-only or only in `admin-panel/index.html`. Growth tools exist (`/api/admin/users/:id/followers`, `/api/admin/content/:kind/:id/boost`). |
| 6 | Creator Rewards (milestones + badge/frame/background/entry/chat/gift/title, DB-driven) | **Partial** | `CreatorLevel` + `CreatorMilestone` tables are created by raw SQL only — they are **not in `prisma/schema.prisma`**, so nothing type-safe can use them. Reward asset kinds exist via `Asset`. Needs schema promotion + wiring to the profile. |
| 7 | Chat (backgrounds, themes, effects, reply/reaction/attachments/voice/read/typing, performance) | **Done** | 10 + 3 premium themes, `message_effects.dart` (6 effects, stored on the message), reply/reaction/voice/read/typing all present. |
| 8 | Stories / Reels (navigation, status circles, replies/reactions/views/privacy, reels playback/comments/shares/saves/follow) | **Partial** | Full route set exists. `Story` has `audienceMode`/`hiddenUserIds`; there is **no `StoryView` model**, so "story views" and "status circle ordering" cannot be correct. |
| 9 | Localization (real `flutter_localizations` + ARB, old system removed) | **Missing** | `core/localization.dart` is still the custom map helper; no `l10n/`, no `.arb`. |
| 10 | GitHub / CI | **Fixed in V93 (partly)** | `android.yml` runs backend tests + analyze + test + `--coverage` + release APK. Three legacy workflows (`v62`, `v76`, `v79`) duplicated the same jobs and two of them contained a **duplicate `env:` key** (invalid YAML). They are removed in V93; `prisma validate` + `npm install` added to the backend job. |
| 11 | Security | **Mostly done, one real hole fixed** | CORS allow-list, security headers, secure token storage, permission checks, audit, `IdempotencyRecord`. **V93 fix:** socket `live:gift` forgery (above). Remaining: object-level checks on the newer content routes, rate limiting, and unifying the raw-SQL tables into the Prisma schema. |
| 12 | Real final test report | **Cannot be fully produced yet** | No Postgres and no Flutter/Android toolchain in this sandbox, so `flutter analyze`, `flutter test`, `flutter build apk` and any HTTP/DB path must run in CI or on a machine with the toolchain. This report says so instead of claiming success. |

## Structural findings

1. **Branch confusion.** `main` is pre-V90. If Render deploys `main`, V90–V92 are not live.
2. **No Prisma migrations.** The project relies on `prisma db push` plus ~33
   `CREATE TABLE IF NOT EXISTS` statements executed at boot. This works, but it
   means several tables (Asset, ContinueWatching, CreatorLevel, CreatorMilestone,
   LiveMute, LiveTapCount, IdempotencyRecord) are invisible to the Prisma client.
3. **Duplicate catalog risk.** Any new gift work must extend
   `backend/src/modules/gifts.js` — never add a second engine.

## V93 execution order (proposed)

1. **V93.1 — Integrity & CI** (this increment): CI consolidation, live-gift
   forgery fix, audit doc.
2. **V93.2 — Gift store completion**: extend the existing engine to the 16 spec
   tabs + `assetKey`/`previewKey` + XP bar; generate the artwork bundle and an
   admin replaceable asset manifest (no code edits needed to swap art).
3. **V93.3 — Calls**: `Call` model (state, startedAt, endedAt, durationSec,
   missed) + history + missed-call notifications + incoming-call UI.
4. **V93.4 — Admin**: in-app admin screens for Nova TV content, gifts, rewards,
   assets, permissions, audit, security — each button hitting a real endpoint.
5. **V93.5 — Nova TV**: admin CRUD + uploads + next-episode autoplay.
6. **V93.6 — Rewards/Stories/Chat**: promote raw-SQL tables into the Prisma
   schema, `StoryView`, status-circle ordering.
7. **V93.7 — Localization**: `flutter_localizations` + ARB, old helper removed.
8. **V93.8 — Verification**: run every command in a toolchain environment and
   publish the real report.

## What V93 has changed so far

- `.github/workflows/android.yml` — single pipeline: install, syntax check,
  `prisma validate`, `npm test`, analyze, test, coverage artifact, release APK.
- `.github/workflows/{v62-quality,v76-final-quality,v79-final-quality}.yml` — removed.
- `backend/src/server.js` — socket `live:gift` now verifies the transaction;
  the LIVE gift broadcast carries `transactionId` so clients can use it.
