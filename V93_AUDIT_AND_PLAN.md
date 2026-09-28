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

---

## V93.2 — implemented (verified in this sandbox)

Flutter SDK 3.29.2 and the Dart packages were installed locally, so the client
side is now really verified, not assumed.

### New systems
- **Calls** — `Call`, `CallParticipant`, `CallEvent` models + `/api/calls/start`,
  `/accept`, `/reject`, `/end`, `/history`, `/:id`; the socket signals persist
  the same records, a ring-timeout sweeper marks unanswered calls `MISSED` and
  notifies, duration is computed server-side from `answeredAt`→`endedAt`, and
  `/api/calls/token` now refuses room names that are not an active call the
  caller belongs to. Client: `SocketService.callEnded/callMissed`,
  `sendCallEnd`, and six `Api` methods.
- **StoryView** — who saw a story, when, how many times; `POST /api/stories/:id/view`
  (the client was already calling this route — it used to 404),
  `GET /api/stories/:id/viewers` (author only), `GET /api/stories/seen`.
- **Creator milestones** — `CreatorMilestone` is a real Prisma model now, with
  `CreatorMilestoneReward` recording what each creator actually earned.
  Reaching a threshold grants the rewards once (coins + notification + socket
  event) on follow and on `/api/creator/milestones/me`. Admin edits match rows
  by `followersRequired` so granted rewards never point at a deleted row.
- **Gift library** — the whole contract (`nameEn`, `imageUrl`, `previewUrl`,
  `animationUrl`, `assetKey`, `premium`, `sortOrder`, `metadata`, `updatedAt`)
  is now in `prisma/schema.prisma`; seeding is a type-safe upsert that never
  overwrites admin-uploaded media, and `/api/wallet/gifts` supports
  `?category=` / `?rarity=` filtering. New admin CRUD
  (`GET/POST/PATCH/DELETE /api/admin/gifts`) lets gifts be added or disabled
  without a Flutter release, and `GET /api/gifts/xp` feeds the XP bar.
- **Rate limiting** — dependency-free sliding window: 600/min per IP for `/api`,
  12/min for login/register, with `Retry-After` and automatic bucket cleanup.
- **Notification types** — `CALL`, `STORY`, `REWARD`, `MILESTONE`, `ADMIN` added
  to the enum and applied to the database with `ALTER TYPE ... ADD VALUE`.

### Promoted from raw SQL into `prisma/schema.prisma`
`CreatorLevel`, `CreatorMilestone`, `Asset`, `ContinueWatching`,
`IdempotencyRecord`, `LiveMute`, `LiveTapCount` — these existed in the database
but were invisible to Prisma. The raw `CREATE TABLE IF NOT EXISTS` statements
stay, so existing Neon databases upgrade the same way.

### Verification actually run
| Command | Result |
|---|---|
| `node --check src/server.js` | OK |
| `npx prisma validate` | valid |
| `npx prisma generate` | OK (new models/fields present in the client) |
| `npm test` (backend) | **18/18 pass** |
| `flutter analyze` (whole project) | **No issues found** |
| `flutter test` | **21/21 pass** |
| `flutter test --coverage` | **42.6 % lines (594/1395)** |
| `flutter build apk --release` | **NOT RUN** — no Android SDK in this sandbox |

### Still open (honest list)
- Admin **screens** (Nova TV content, gifts, rewards, assets) — the APIs exist;
  the in-app screens do not.
- Call **UI**: history list, incoming-call screen polish, duration display.
- Gift **artwork**: real images are still absent; the pipeline (`Asset`,
  `imageUrl/previewUrl/animationUrl`, admin CRUD) is ready for uploads.
- Localization (`flutter_localizations` + ARB) — untouched.
- Database-backed integration tests and any HTTP/DB verification — no Postgres here.
