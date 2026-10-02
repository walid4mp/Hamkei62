# SocialNova V92 — Release report

Branch: `v90-core-hardening` (contains V90 → V92). This report answers the
16-point delivery checklist.

## 1. Files modified

Backend: `backend/src/server.js`, `backend/prisma/schema.prisma`,
`backend/package.json`, `.github/workflows/android.yml`.
Client: `flutter-app/lib/core/api.dart`, `core/nova_audio.dart`,
`core/nova_gifts.dart`, `core/socket.dart`, `lib/main.dart`,
`lib/screens/home.dart`, `profile.dart`, `social.dart`, `wallet.dart`,
`auth.dart`, `achievements.dart`, `editor.dart`, `fitness_challenges.dart`,
`max_privacy.dart`, `secret_diary.dart`, `tech_gaming.dart`, `women_hub.dart`,
`flutter-app/android/app/build.gradle`.

## 2. Files created

- `backend/src/modules/permissions.js` — central permission catalog + roles + live-staff rules.
- `backend/src/modules/gifts.js` — Gift Engine (210 gifts).
- `backend/test/gifts.test.js` — Node unit tests.
- `flutter-app/lib/core/nova_audio.dart`, `core/nova_gifts.dart`,
  `core/message_effects.dart`, `core/creator_levels.dart`,
  `lib/screens/nova_tv.dart`.
- `flutter-app/test/nova_gifts_test.dart`, `test/v92_features_test.dart`.
- `flutter-app/assets/sfx/*.wav` (9 generated sound effects).
- `flutter-app/android/key.properties.example`.
- Root docs: `.gitignore`, `V90_CORE_HARDENING.md`, `V91_GIFTS_LIVE_CHAT.md`, this report.

## 3. Systems implemented

- Gift Engine (210 gifts, 5 rarities, 7 categories, semantic animations).
- Gift Animation Manager (queue) + 6 motion families + alert banner.
- Central permission catalog with 71 dotted permissions and 7 roles.
- Audit log (rich metadata) and idempotency for money/content mutations.
- Creator levels (8) and Creator Milestones (5, reward-bearing), both admin-editable.
- Continue Watching + Nova TV (movies, series, seasons, episodes, player with resume).
- Central Asset library.
- Chat themes (10 + 3 premium) and message effects (6).
- Live moderation (mute/remove) with Moderator/Assistant roles.

## 4. Systems fixed

- Session token storage (SecureStorage), 401 → login, logout-all, no host fallback.
- Admin permissions actually enforced (was `ADMIN_ONLY` for everyone but DEVELOPER/ADMIN_EMAILS).
- Missing owner-delete routes for posts/reels; account close/reactivate; post/live-comment reports.
- Live counters persisted across re-entry; support board (top gifters/tappers).
- `AndroidManifest`/Gradle release signing via `key.properties`; CI runs analyze + tests + build.
- Analyse clean-up: all warnings + `withOpacity` deprecations fixed.

## 5. Database migrations (all idempotent `ALTER TABLE ... IF NOT EXISTS` / `CREATE TABLE IF NOT EXISTS`)

- `User`: `isDeactivated`, `deactivatedAt`, `tokenVersion`.
- `AuditLog`: `actorRole`, `permission`, `targetType`, `targetId`, `result`, `ipAddress`.
- `IdempotencyRecord` (new table + index).
- `Gift`: `rarity`, `category`, `metadata`.
- `LiveRoom`: `tapCount`, `giftCount`, `giftScore`.
- `LiveTapCount` (new table + index).
- `LiveMute` (new table).
- `Message`: `effect`.
- `NotificationType`: added `REPORT` enum value.
- `Story`, `Post`: `views`.
- `CreatorLevel` (new table), `CreatorMilestone` (new table),
  `ContinueWatching` (new table), `Asset` (new table + index).

## 6. API endpoints added/changed (V90→V92)

Added: `POST /api/auth/logout-all`, `DELETE /api/posts/:id`, `DELETE /api/reels/:id`,
`POST /api/account/close`, `POST /api/account/reactivate`,
`PATCH /api/admin/users/:id/deactivate`, `POST /api/posts/:id/report`,
`POST /api/live/comments/:id/report`, `GET /api/live/stats/:roomName`,
`GET /api/live/top/:roomName`, `GET /api/gifts/categories`,
`GET /api/creator/levels`, `PUT /api/admin/creator-levels`,
`GET /api/creator/milestones`, `GET /api/creator/milestones/me`,
`PUT /api/admin/creator-milestones`, `GET/PUT /api/continue-watching`,
`GET /api/assets`, `GET/POST/PATCH/DELETE /api/admin/assets`,
`POST /api/admin/users/:id/followers`, `POST /api/admin/content/:kind/:id/boost`.
Changed: `DELETE /api/admin/*` now permission-checked; `/api/me` and login return
`permissions`; `/api/wallet/gifts` returns the full engine payload.

## 7. Permissions added

`assets.manage` (plus the full dotted catalog from
`backend/src/modules/permissions.js`: users.*, profiles.*, posts.*, stories.*,
reels.*, live.*, comments.*, messages.*, calls.*, gifts.*, wallet.*,
transactions.*, withdrawals.*, movies.*, series.*, episodes.*, creators.manage,
rewards.manage, themes.manage, backgrounds.manage, effects.manage, reports.*,
admins.*, permissions.*, settings.*, audit.view). Live-staff permissions:
`comments.delete`, `comments.pin`, `live.mute`, `live.remove`, `live.report`.

## 8. Admin features

- Role/permission management guarded by `permissions.grant`; last-SUPER_ADMIN
  protection; sensitive-change confirmation; full audit trail.
- Creator levels and creator milestones editable from the API.
- Asset library CRUD (gifts/themes/backgrounds/frames/effects/rewards).
- Growth tools: add/remove followers, boost live viewers / reel views / story
  views / post views.
- Delegated profile card in-app: ban, verify, feature, coins, effects, close
  account, add followers.

## 9. Security fixes

Secure token storage, fixed API host (no fallback), 401 handling, logout-all,
CORS allow-list, security headers, no default JWT secret, idempotent money
operations, permission checks on every admin route, `PermissionDenied` audit,
upload MIME/size handled by existing pipeline.

## 10. Tests

- Flutter: `test/smoke_test.dart`, `test/live_messenger_ui_test.dart`,
  `test/nova_gifts_test.dart`, `test/v92_features_test.dart` — **21 tests**.
- Backend: `backend/test/gifts.test.js` — **7 tests** (`npm test`).

## 11. Coverage

`flutter test --coverage` produces `coverage/lcov.info`. For the modules reached
by tests: **43.3% lines (594/1371)**. Whole-app coverage is still low (most
screens are not yet widget-tested) — reported honestly.

## 12. flutter analyze result

`flutter analyze lib` → **No issues found!**

## 13. Flutter test result

`flutter test` → **All tests passed** (21/21).

## 14. Android build result

`flutter build apk --release --split-per-abi` → **success** (JDK 17, Android SDK 36).

## 15. APK path

`flutter-app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (46.5 MB),
`app-armeabi-v7a-release.apk` (39.3 MB), `app-x86_64-release.apk` (51.6 MB),
and the universal `app-release.apk`.

## 16. Genuinely remaining issues

- **Gift artwork**: gifts still render as emoji + rarity frames; the reference
  design uses real PNG artwork, and there is no XP bar in the gift sheet yet.
- **Localization**: still uses the existing in-app translation helper, not full
  `flutter_localizations` + ARB files.
- **Calls**: ring/accept/reject signalling exists; incoming-call UI, call
  history and missed-call notification still need verification on devices.
- **Movies/Series admin UI**: content CRUD exists on the API; the in-app admin
  screens for it are not built yet (creator studio covers creator posting).
- **Notifications**: the type list was extended (`REPORT`); push delivery for
  every type is not independently verified here.
- **Whole-app widget/integration coverage** is low; only the modules listed in
  §11 are tested.
- **Backend tests** cover pure logic only; no DB-backed integration tests.
