# SocialNova V89 — Stories player, Live swipe, Gift effects & sounds, Admin permissions

Base: `SocialNova-V88-LIVE-MESSENGER-PRO`. Version bumped `3.6.0+17 → 3.7.0+18`
(`flutter-app/pubspec.yaml` and `flutter-app/android/app/build.gradle` moved together).

This release targets the reports you sent: stories not behaving, music/sounds
missing, Live not swiping like reels, gifts all looking the same, admin
permissions not usable inside the app, and posts not looking professional.

## 1. Stories now behave like real stories

`flutter-app/lib/screens/home.dart`

- The rail groups stories **by author** and shows a small counter badge when an
  author has several.
- `StoryViewer` accepts a `queue` and becomes a full player:
  - segment **progress bars** at the top;
  - **auto-advance** (5s for images, 15s for videos) and auto-close at the end;
  - **tap right / tap left** to move next/previous, **long-press to pause**;
  - **swipe down to close**;
  - the author's selected **music actually plays** (looped) via the new audio
    service and stops when the viewer closes;
  - viewed is still marked, and like/reply keep working per current story.
- Passing a single story (profile, share links) keeps working unchanged.

## 2. Music & sound layer (stories, reels, live)

New: `flutter-app/lib/core/nova_audio.dart` + bundled effects in
`flutter-app/assets/sfx/` (9 generated royalty-free WAV files, no external
licensing).

- `playMusic/stopMusic/playAssetMusic` — one background track at a time
  (`just_audio`), used by Stories (and available to Reels which already carry
  `musicUrl`).
- `playSfx` — fire-and-forget effects from the asset pool; failures are silent
  so audio can never break a screen.
- Wired in: story music playback; live **join**, **tap** and **gift** sounds.
- Gift sounds are tier based: شائعة/حظ/فاخرة/حصرية map to four distinct
  effects, with the exclusive tier using a long, grand chord.

## 3. Live — swipe between rooms (reels-style)

`flutter-app/lib/screens/social.dart`

- New `LiveSwipeViewer`: a vertical `PageView` where each page is a full live
  room. Swipe up/down to move live→live without returning to the grid; a
  temporary hint and `N / M` counter appear on entry. Off-screen rooms are
  disposed, so only the visible room keeps a LiveKit connection.
- The discovery grid and the "مذيعون نشطون الآن" rail now open the swipe viewer
  at the tapped room.
- Capture stays on **tap-anywhere on the video stage** (already present) and now
  also plays the tap sound and pushes the rising-hearts burst.

## 4. Gifts — varied, animated, with sound

New: `flutter-app/lib/core/nova_gifts.dart`

- A 26-gift catalog across four tiers, **no two gifts share an emoji, a name or
  a slug** (enforced by a test). Mirrors the server catalog so the UI renders
  even offline.
- `NovaGiftEffect`: a distinct full-screen animation per effect family —
  golden rain (تاج/عرش/كريستال), flight path (صاروخ/تنين/سيارة/طائرة/مجرة),
  and a particle burst for the rest — plus tier colours, elastic hero card and
  the sender/coins badge.
- Gift sheet rebuilt with **tier tabs** (الكل/شائعة/حظ/فاخرة/حصرية), a preview
  that names the tier and price, and a per-gift sound on selection/send.
- Server seed (`backend/src/server.js` → `ensureCatalog`) now upserts the same
  26 distinct gifts (stable ASCII slugs, ascending prices 1→9999, each with its
  own `effectKey`/`soundKey`).

## 5. Admin — granted permissions now actually work in the app

Backend (`backend/src/server.js`)

- **Root cause fixed:** every moderation route was hard-gated to
  `role==='DEVELOPER'` or `ADMIN_EMAILS`, so a user granted `FULL_MODERATOR` /
  `CUSTOM_MODERATOR` through `PATCH /api/admin/users/:id/privileges` still got
  `403 ADMIN_ONLY`. A new `requirePermission(permission)` middleware now accepts
  DEVELOPER, an admin email, **or an account holding the matching permission**,
  and it is applied to: admin delete post/reel/story/comment/group, stop live,
  ban/verify user, and device bans. `staffPermission` is no longer dead code.
- **Missing owner-delete routes added** (the app already called them and got a
  404): `DELETE /api/posts/:id` and `DELETE /api/reels/:id` — owner or the
  matching moderation permission.
- **Account close/reactivate added** (previously no such endpoint existed):
  `POST /api/account/close`, `POST /api/account/reactivate`, plus admin
  `PATCH /api/admin/users/:id/deactivate` (needs `USER_MODERATION`). Login and
  the auth middleware reject a closed account with `ACCOUNT_CLOSED`.
- New `POST /api/posts/:id/report` — delivers a moderation notification to staff
  accounts (there was no post report route before).

Client

- `Api.can(permission)` / `Api.isDeveloper` read `adminPermissions` from `/api/me`.
- Post card overflow menu (non-owner) now offers **إبلاغ عن المنشور** and
  **نسخ رابط المنشور**, plus **حذف المنشور (إشراف)** when `POST_MODERATION`
  is held.
- Profile delegation card gained a **صلاحيات المنصة** section: ban / unban and
  **close account / reactivate** when `USER_MODERATION` is held.

## 6. Posts look more professional

`flutter-app/lib/screens/home.dart` → `PostCard`

- Action row is now naturally RTL (like, comment, repost, share, then bookmark)
  with icon-then-count, and a subtle divider above it — no more forced-LTR row.
- Media is constrained by a 4:5 aspect ratio with a loading placeholder, so tall
  images no longer stretch the card.
- Title and caption are truncated (2 / 7 lines) instead of unbounded.
- Non-owner posts get the overflow menu described above.

## Verification performed in this environment

- Flutter 3.29.2 / Dart 3.7.2 (same toolchain as the repo CI).
- `flutter analyze lib` → **0 errors** (only pre-existing infos/warnings).
- `flutter test` → **14/14 pass**, including the new
  `test/nova_gifts_test.dart` (catalog uniqueness, ascending prices, sound
  mapping, and two RTL animation render tests).
- `node --check backend/src/server.js` → OK.
- An APK was **not** built here (no Android SDK in this environment) — the repo
  CI workflow `.github/workflows/android.yml` builds it.

## Still open (next increment)

- **Live background music**: the host cannot yet broadcast a chosen track to
  viewers — that needs publishing an audio track over LiveKit (the story/reel
  server-side mixing route `/api/mix` already exists).
- **Live discovery "حلقات LIVE" on stories** from the design file: showing live
  hosts as rings in the stories rail.
- **Bot accounts** and a fully in-app admin console (role/grant UI) are not in
  this release; grants are still made from the admin panel, but they now take
  effect in the app.
- Real store signing (release keystore) for a publishable AAB.
