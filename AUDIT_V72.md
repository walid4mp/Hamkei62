# SocialNova V72 — Production repair audit

## Repairs included
- Added additive production compatibility for the missing `AuditLog` table that caused Prisma `P2021` and crashed the Node process.
- Added additive compatibility for `ChatTheme` so Messenger chat backgrounds can be saved without a missing-table failure.
- Added compatibility columns for digital identity card settings and profile-field privacy.
- Fixed the digital identity-card API response shape so the Flutter screen receives the user fields it actually renders.
- Added singular `/api/chat/:userId/theme` aliases in addition to `/api/chats/:userId/theme` to tolerate older client builds.
- Relationship partner is optional: a user can save a relationship status without selecting a partner, or select a partner and send a confirmation request.
- Relationship, birth date, location/state, and gender can be hidden from the public profile independently.
- Public profile now renders these items as compact chips beside each other instead of a large relationship card.

## Static verification performed
- `node --check backend/src/server.js` passes.
- The Prisma schema contains `AuditLog`, `ChatTheme`, `Relationship`, `PostView`, and the new privacy/digital-card fields.
- The production startup compatibility code creates missing additive tables/columns with `IF NOT EXISTS` and does not run destructive Prisma push.

## What is not honestly claimable from this environment
- A real Android APK build could not be executed because the Flutter SDK is not installed in this environment.
- A live PostgreSQL/Render/LiveKit/Cloudinary integration test could not be executed against production credentials here.
- Live video still requires valid `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`.
- Persistent media on Render requires Cloudinary configuration.
- Push notifications require Firebase FCM configuration.
- Store purchase verification requires the server-side Google Play/App Store credentials.

Deploy V72 to Render, then verify `/api/health`, Messenger theme save, Digital ID loading, profile privacy toggles, relationship save with and without a partner, Reels, Stories, and Live from the Android build.
