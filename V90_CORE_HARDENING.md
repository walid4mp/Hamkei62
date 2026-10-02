# SocialNova V90 — Core hardening: security, central permissions, audit, idempotency

Branch: `v90-core-hardening`. This is the first V90 increment and targets the
"fix the project and its security" mandate before feature work continues.

## 1. Client security

`flutter-app/lib/core/api.dart`, `main.dart`, `screens/profile.dart`

- **Session token moved to FlutterSecureStorage.** It is no longer written to
  SharedPreferences; an existing SharedPreferences token is migrated once and
  the old copy is deleted.
- **No untrusted host fallback.** The `fallbackBases` list and the runtime
  host-probing were removed. The API host is fixed at build time from
  `--dart-define=API_URL=...`; there is no automatic redirection to any other
  domain, so credentials can never be sent to an unowned host.
- **401 handling.** Any `401` clears the session and returns the app to the
  login screen (`Api.onUnauthorized` wired in `main.dart`).
- **Logout all devices.** New `POST /api/auth/logout-all` bumps a per-user
  `tokenVersion`; JWTs carry `tv`, and the `auth` middleware rejects tokens whose
  version no longer matches. Exposed in Settings as "تسجيل الخروج من كل الأجهزة".

## 2. Central permission system

New: `backend/src/modules/permissions.js`

- Full dotted catalog (users.view … audit.view) and the roles
  `USER, ASSISTANT_MODERATOR, MODERATOR, ADMIN, SECURITY_ACCOUNT, DEVELOPER,
  SUPER_ADMIN` (legacy `CUSTOM_MODERATOR`/`FULL_MODERATOR` are aliases).
- `ROLE_PERMISSIONS` gives every role an explicit permission list. **Only
  SUPER_ADMIN carries `*`.** A DEVELOPER account is now permission-checked like
  everyone else and cannot grant permissions to itself.
- Legacy uppercase grants (POST_MODERATION, …) are expanded onto the dotted
  catalog, so existing production rows and the admin panel keep working.
- **Every admin endpoint checks a specific permission** via `requirePermission`.
  `hasPermission` accepts dotted or legacy names.
- `ADMIN_EMAILS` no longer bypasses checks at runtime. It is used only for
  one-time bootstrap in `ensureSuperAdmin()`, which guarantees at least one
  SUPER_ADMIN exists.
- Security accounts start with no permissions and are granted exactly what they
  need by a Super Admin; they cannot grant themselves.
- Guardrails: the **last SUPER_ADMIN cannot be demoted or removed** (409
  `LAST_SUPER_ADMIN`), and sensitive changes require `confirm:true`
  (428 `CONFIRMATION_REQUIRED`). Only a SUPER_ADMIN can create another
  SUPER_ADMIN.
- `GET /api/admin/permission-catalog` returns roles + the full catalog.

## 3. Audit log

- `auditAction()` records actor, actorRole, action, permission, target user/
  resource, before/after, IP, device and result into `AuditLog` (new columns
  added idempotently; values also packed into `metadata`).
- Staff grants, staff creation, logout-all and other sensitive actions write an
  audit row. `GET /api/admin/audit-logs` is now guarded by `audit.view`.

## 4. Idempotency for money & content

- The client sends an `Idempotency-Key` header on every mutation, reused across
  its own retries.
- The server stores the first response in `IdempotencyRecord` (scoped to the
  caller) and replays it for the same key, so gifts, purchases, withdrawals,
  posts, reels, stories and other mutations can never execute twice.
- Keys are scoped per user, so one account can never read another's response.

## 5. Live: persistent counters + support board

- `LiveRoom` now stores `tapCount`, `giftCount`, `giftScore`; per-user taps are
  aggregated in `LiveTapCount`. Leaving and re-entering a live no longer resets
  the totals.
- New `GET /api/live/stats/:roomName` and `GET /api/live/top/:roomName`.
- Tapping the viewers (eye) pill opens a **support board**: top gifters (by
  NVC) and top tappers, in order. Gift sends in a live increment the room
  totals.
- The host's uploaded stage cover (`[live_image]`) is now actually rendered
  behind the "waiting for video" state instead of a plain black screen.

## 6. Android release signing & CI

- `android/app/build.gradle` reads `android/key.properties` when present and
  uses `signingConfigs.release`; otherwise it falls back to debug signing so
  builds still work locally.
- `android/key.properties.example` documents the format; `key.properties`, the
  keystore, `local.properties` and `google-services.json` are all git-ignored
  (root and `flutter-app/.gitignore`).
- `.github/workflows/android.yml` now runs `flutter analyze lib` and
  `flutter test` before building, decodes an optional keystore from repository
  secrets (never committed), builds the APK with `API_URL`/`SOCKET_URL`
  dart-defines, uploads it, and always cleans the signing material.

## 7. Code health

- `flutter analyze lib` → **No issues found** (all warnings and the
  `withOpacity` deprecation infos fixed; `withOpacity` → `withValues(alpha:)`).
- `flutter test` → 14/14 pass.
- Dead code removed (unused imports, fields, and unreferenced methods).

## Verification performed

- Flutter 3.29.2 / Dart 3.7.2.
- `flutter analyze lib` → 0 issues. `flutter test` → all pass.
- `node --check backend/src/server.js` → OK.
- Release APK build attempted locally with Android SDK 36 + JDK 21 (see the
  thread for the result).

## Still to do (next V90 increments)

- Admin UI: a real in-app admin panel with all sections gated by permission
  (Users, Profiles, Reports, Posts, Stories, Reels, Live, Comments, Messages,
  Calls, Gifts, Wallet, Transactions, Withdrawals, Creators, Rewards, Movies,
  Series, Episodes, Categories, Themes, Backgrounds, Effects, Admins,
  Permissions, Security, Audit Logs, Settings).
- Status circles with the full state set (new/seen/live/online/close-friends/
  featured/creator) and stable smart ordering.
- Reels/Live polish, chat background + supporter ranks, movies/series content
  system, rewards.
- Real keystore provisioning and a signed AAB for the stores.
