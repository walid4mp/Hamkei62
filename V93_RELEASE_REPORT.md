# SocialNova V93 — complete release report

Branch: `v93/gift-engine-foundation` (based on `v90-core-hardening`, which carries
V90 → V92). This archive is the full project, ready to push.

## 1. How to run it

```bash
# backend
cd backend
cp .env.example .env          # then fill DATABASE_URL (Neon) + JWT_SECRET + LIVEKIT_*
npm install
npx prisma generate
npx prisma db push            # or let the server upgrade an existing DB at boot
npm start

# client
cd flutter-app
flutter pub get
flutter run --dart-define=API_URL=https://<your-render-host> \
            --dart-define=SOCKET_URL=https://<your-render-host>

# verify everything
cd backend && npm test && npx prisma validate
cd ../flutter-app && flutter analyze && flutter test && flutter test --coverage
```

`flutter gen-l10n` runs automatically on `flutter pub get` (`generate: true`).

## 2. Verified in this release

| Command | Result |
|---|---|
| `node --check backend/src/server.js` | OK |
| `npx prisma validate` | valid |
| `npm test` (backend) | **18/18 pass** |
| `flutter analyze` (whole project) | **No issues found** |
| `flutter test` | **41/41 pass** (includes widget tests that build the new screens) |
| `flutter test --coverage` | 43.8 % lines |
| GitHub Actions (run 135) | **success** — backend tests, prisma validate, analyze, test, coverage, `flutter build apk --release` |

Not verifiable from the dev sandbox: a physical device run (no Android SDK here)
and any DB-backed path (no PostgreSQL here). The APK is built by CI.

## 3. What V93 added

### Calls — real records instead of signalling
`Call`, `CallParticipant`, `CallEvent`; `/api/calls/start|accept|reject|end|history/:id`;
socket signals persist the same rows; a ring-timeout sweeper marks unanswered calls
`MISSED` and notifies; duration is computed server-side; `/api/calls/token` refuses
rooms that are not an active call the caller belongs to. Client: live `mm:ss` timer
in the call screen, `CallHistoryPage` with direction/outcome/duration/redial.

### Stories — real view tracking
`StoryView` (who, when, how many times), `POST /api/stories/:id/view`
(the client already called this route — it used to 404), `GET /api/stories/:id/viewers`
(author only), `GET /api/stories/seen` for the status-circle state.

### Creator rewards
`CreatorMilestone` + `CreatorMilestoneReward`; reaching a threshold grants the reward
exactly once (coins + notification + socket event) on follow and on read; admin edits
keep row ids so granted rewards stay valid. New in-app **Creator Rewards** screen with
the earned/locked milestones, progress to the next one and the concrete rewards
(badge, frame, background, entry effect, chat effect, gift, coins).

### Gift engine + store
* 210 gifts, five rarities, seven themes, six motion families, per-gift sound.
* Admin CRUD (`/api/admin/gifts`) — add or disable gifts without a Flutter release.
* New neon **gift store** (`features/gifts/gift_store.dart`): coin pill, supporter
  level + XP bar, rarity/theme tabs, 3-column glow grid, real artwork, PRO badges,
  preview that charges nothing, x1/x5/x10 combos, replay-safe send with an
  idempotency key. `showGiftPicker` now delegates to it, so there is one gift UI.
* Live: identical gifts merge into one animation with an ×N badge; the ledger still
  records every transaction separately.

### Live
Persisted `giftScore/giftCount/tapCount/commentCount/peakViewers`, server-side
ordering for top gifters/tappers, Moderator vs Assistant permissions enforced on the
server, comment moderation (reply/pin/delete/mute/remove/report), and new
**join requests** (`LiveJoinRequest` + REST + socket events) with an in-app sheet:
a viewer asks and sees the status, the host approves or rejects.

### Admin inside the app
`AdminConsolePage` with four working tabs — Gifts, Assets, Rewards, Nova TV — plus new
audited backend CRUD for movies/series/seasons/episodes and `/api/admin/content-tree`.
Content gained backdrop, genres, cast, rating, status, year and release date.

### Localization
The hand-written translation map is gone. `flutter-app/lib/l10n/app_*.arb` for
**ar, en, fr, es, tr, de, ru, pt** (117 strings), compiled by `flutter gen-l10n` into
`AppLocalizations` and wired into `MaterialApp`; `core/localization.dart` is a thin
adapter. Regenerate with `python3 tools/generate_l10n.py`.

### Gift artwork
`tools/generate_gift_assets.py` renders 210 real WebP images + 210 four-frame previews
and a manifest into `backend/src/admin-assets/gifts`; seeding attaches
`imageUrl`/`previewUrl` to gifts without artwork and never overwrites an admin upload.
The store and the live overlay render the real image (emoji only as fallback).

### Security & data
Socket `live:gift` no longer relays client payloads (it could forge gifts and inflate
a room's score); sliding-window rate limiting (600/min per IP, 12/min for auth);
Prisma promotion of nine tables that only existed as raw SQL; every new column and
table is applied with idempotent `ALTER TABLE ... IF NOT EXISTS` / `CREATE TABLE IF
NOT EXISTS`, so an existing Neon database upgrades without data loss.

## 4. Honestly still open

1. **Device run.** No Android SDK in the development sandbox, so the app was not
   launched on a device/emulator by me. The APK is built by CI, and the new screens
   are covered by widget tests.
2. **DB-backed integration tests.** No PostgreSQL here — the tests cover pure logic
   and widget rendering; end-to-end HTTP/DB paths need CI with a database service.
3. **Visual redesign still pending** for: the live stage's own chrome (the HUD,
   supporters board, tap-to-like, gift queue already work), Nova TV screens,
   Stories/Reels/Chat polish.
4. **Portuguese** is reviewed for 64 of 117 strings; the rest falls back to English.
5. **Some older screens still contain hardcoded Arabic strings** that were never in
   the legacy translation map, so they are not yet in the ARB files.
6. **Gift artwork is generated procedurally** and consistent with the brand; upload
   real art per gift from the admin console and it appears everywhere.
7. `main` is still pre-V90. Merge the pull request (or fast-forward `main`) so the
   deployment stops shipping an old build.
