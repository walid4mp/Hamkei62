# SocialNova V91 — Gift Engine, Live moderation, Chat themes & effects, Creator levels

Branch: `v90-core-hardening` (continues the V90 branch). Builds on `V90_CORE_HARDENING.md`.

## 17 · Gift Engine (200+ gifts)

- New `backend/src/modules/gifts.js`: a deterministic engine that builds a
  catalog of **210 gifts**, all with unique emoji, name and slug.
- Every gift carries: `slug` (id), `name`, `emoji` (icon), `priceCoins`
  (value), `rarity`, `category`, `effectKey` (animation), `effectMs`
  (duration), `soundKey`, `enabled`, `metadata`.
- Five rarities — COMMON / RARE / EPIC / LEGENDARY / MYTHIC — with prices
  ascending 1 → 17000.
- Seven categories: حب ومشاعر، فخامة، تقنية وسيارات، طبيعة، مأكولات،
  موسيقى وترفيه، رياضة وقوة.
- New `Gift` columns (`rarity`, `category`, `metadata`) added idempotently and
  seeded by raw upsert, so no Prisma regeneration is required.
- `GET /api/wallet/gifts` now returns the full engine payload;
  `GET /api/gifts/categories` returns the category list.
- The gift sheet groups by **category** with rarity-coloured frames, and shows
  the rarity label and price for the selected gift.

## 18 · Gift animations

`flutter-app/lib/core/nova_gifts.dart`

- **Six motion families**, chosen semantically per gift so no two types move
  alike: `drop` (crown/diamond/castle/trophy/coins fall from above and settle),
  `rise` (rocket/fireworks from bottom to top), `drive` (car/yacht cross with
  speed lines), `fly` (plane/galaxy/dragon arc across), `shake`
  (lion/fire/lightning shake the screen with a radial glow), `bloom`
  (rose/heart/sakura/stars particle burst).
- Rarity drives intensity: LEGENDARY/MYTHIC add **golden rain** and a short
  **white flash**.
- **Gift Animation Manager**: `LiveRoomPage` now queues incoming gifts and plays
  them one after another, so a burst never overlaps or drops an animation.
- A gift is still charged exactly once: sends are idempotent (V90) and the
  animation layer never issues a second charge.

## 15 · Live comments

- Each comment shows avatar, username, body and time; tapping the avatar opens
  the profile, tapping the comment starts a reply.
- Long-press opens a permission-gated menu: **Reply, View profile, Pin, Delete,
  Mute, Remove from live, Report** — only the actions the viewer's role allows.
- The comment composer is disabled with an explanatory hint when the viewer is
  muted in that room.

## 16 · Moderator system

- Live staff roles with **separate, server-enforced** capabilities
  (`LIVE_ROLE_PERMISSIONS`): **Moderator** = delete + pin + mute + remove + end;
  **Assistant Moderator** = delete + report only.
- `liveStaffCan()` gates every moderation socket event, so a moderator can
  never act beyond their role.
- New `live:mute` / `live:remove` events, a `LiveMute` table (muted users cannot
  chat), and staff report notifications delivered to accounts holding
  `reports.view` (raw-SQL insert, so it works regardless of Prisma enum state).
- The host still appoints staff from their followers, choosing Moderator or
  Assistant.

## 19 · Chat

Verified and kept working: send/receive, delivered & read status, typing,
replies, reactions, delete, profile navigation, images, video, voice notes and
notifications. Message sending now also carries an optional effect (below).

## 20 · Chat themes

- Ten named themes — 🌌 فضاء، 🌊 محيط، 🌸 ساكورا، 🔥 نار، 💜 نيون، 🌙 ليل،
  🎮 ألعاب، 💎 ألماس، ❤️ حب، 🖤 داكن — plus three premium animated ones
  (✨ شفق، 💗 قلوب، ❄️ ثلج).
- Each theme sets the background gradient and its particle mode; the new
  `sakura`, `fire` and `snow` painters join the existing `stars`, `hearts` and
  `particles` modes.
- Themes are still saved per conversation via `PUT /api/chat/:userId/theme`.

## 21 · Animated chat backgrounds

- Static (gradient) and animated (particle) backgrounds, with premium options.
- Particles are drawn with a single `CustomPaint` driven by a shared
  `AnimationController` already throttled by the chat screen, so there is no
  per-particle widget and no unnecessary battery drain.

## 22 · Message effects

- New `flutter-app/lib/core/message_effects.dart`: 🎉 celebration, ❤️ hearts,
  🔥 fire, ✨ stars, ❄️ snow, 🎆 fireworks as full-screen overlays.
- The effect is attached to the outgoing message, sent to the server, stored on
  the message (new `effect` column) and replayed for the receiver — so both
  sides see the same effect on send and receive.
- A composer button opens the effect picker and previews the choice.

## 23–25 · Profile customization & entry effects

- Entry effects extended from 5 to 12: GOLDEN_AURA, NEON_PORTAL, HEART_BURST,
  SPARKLES, **FIRE, GALAXY, CROWN, DIAMOND, STARS, LIGHTNING, SAKURA** (+ NONE).
  The server validator accepts all twelve and each has its own animate-in
  gradient. Existing profile background/frame/aura/song/pins are unchanged, and
  the whole set stays admin-manageable through the delegated profile card.

## 26 · Creator levels

- New `CreatorLevel` table seeded with eight levels (مبتدئ 100، صاعد 500،
  مبدع 1,000، مبدع+ 5,000، مبدع مشهور 10,000، نخبة 50,000، أسطورة 100,000،
  عملاق 1,000,000) with per-level tier and colour.
- `GET /api/creator/levels` for the client and
  `PUT /api/admin/creator-levels` (permission `creators.manage`, audited) so
  admins can edit thresholds, labels, colours and enable/disable levels.
- The profile shows a `CreatorLevelBadge` computed from the follower count.

## Verification

- `flutter analyze lib` → **No issues found**.
- `flutter test` → **14/14 pass**.
- `node --test test/*.test.js` (new) → **7/7 pass** — gift catalog uniqueness,
  determinism, completeness, permission wildcard rules, legacy grant expansion,
  live staff role enforcement, catalog integrity.
- `node --check backend/src/server.js` → OK.
- CI: new `backend-tests` job runs the Node tests; the APK job runs
  `flutter analyze` + `flutter test` then builds.
- Release APKs rebuilt from this source (see the thread).

## Still open

- Watching the 10 reference screenshots for ideas not yet covered (the sheet
  designs for post/story/reel settings, analytics, privacy).
- Admin UI sections, status circles, reels polish, movies/series content
  system, rewards, signed AAB for stores.
