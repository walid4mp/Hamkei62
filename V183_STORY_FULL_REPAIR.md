# SocialNova V183 — Story Full Repair

## Story publish pipeline
- Fixed the Flutter audience mapping so `FOLLOWERS` is no longer sent as an unsupported backend enum.
- Backend now normalizes legacy audience values (`PUBLIC`, `FOLLOWERS`, `FRIENDS`, `CLOSE_FRIENDS`, `HIDDEN`) safely.
- Story media URL must be a valid HTTP(S) URL before the database record is created.
- Story creation returns HTTP 201 plus the created story and an immediate STORY status ring.
- Hidden-user IDs are normalized, deduplicated and bounded.
- Scheduled stories are not exposed before their scheduled time.
- Expired/archived stories are excluded from active story feeds and status rings.

## Story visibility
- `EVERYONE`: visible to all viewers.
- `FOLLOWERS`: visible when the viewer follows the author.
- `CLOSE_FRIENDS`: visible for mutual follows (the project currently has no dedicated close-friends table).
- `HIDDEN`: visible except to explicitly hidden user IDs.
- The same visibility checks are applied to `/api/stories` and `/api/users/:id/stories`.

## Story editing
- Story audience updates accept legacy UI values and normalize them.
- Hidden-user lists are normalized and deduplicated.
- Story update errors now expose a useful server-side detail field.

## Storage
- `/api/upload` continues to use Cloudinary when configured, so production Story media gets durable HTTPS URLs.
- Production still returns `STORAGE_NOT_CONFIGURED` if durable media storage is not configured instead of silently relying on Render's ephemeral filesystem.

## Release
- Flutter version: `3.9.5+27`
- Android versionCode: `27`
- Android versionName: `3.9.5`

## Verification
- `node --check backend/src/server.js` passed.
- Existing backend test suite: 24/24 passed.
- Flutter/Gradle build was not executed because Flutter SDK is unavailable in this execution environment.
