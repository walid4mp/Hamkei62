# SocialNova V70 — Production repair notes

## Fixed
- Added production-safe compatibility for `PostView` and its indexes/foreign keys.
- Added missing `User.relationshipStatus` / `relationshipSince` compatibility.
- Added `User.fcmToken` to Prisma so Firebase queries match the production schema.
- Preserved legacy Post/Reel/Story moderation columns so future schema syncs do not try to delete live data.
- Disabled automatic `prisma db push` in the production Docker startup. Startup is now additive and migration-safe.
- Kept device-ban tables additive and revocable.
- Refreshed the birthday picker with a custom SocialNova UI and live age indicator.
- Replaced Android launcher icon rasters with the supplied SocialNova icon reference.
- Bumped Flutter app version to `3.3.0+13`.

## Render deployment
Do NOT enable `PRISMA_PUSH=true` on the production service. The Docker image now starts the API directly and `server.js` performs only additive compatibility SQL.

After deployment, verify:
- `GET /api/health` returns `{ "ok": true }`
- registration no longer fails on `User.relationshipStatus`
- feed no longer fails with `PostView does not exist`
- Admin routes under `/api/admin/*` return authenticated data instead of 404

## Important
The project does not intentionally run `prisma db push --accept-data-loss`. Existing production data should be preserved.
