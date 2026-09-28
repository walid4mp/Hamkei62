# SocialNova V71 — Production audit and fixes

## Verified statically
- Node.js syntax: `backend/src/server.js` and `backend/src/seed.js` pass `node --check`.
- Every Flutter API family used by the current client now has a corresponding backend route, including Messenger state endpoints, Live/LiveKit endpoints, wallet/gifts, marketplace, verification, settings, digital card, groups, content analytics/archive, and profile saved/liked collections.
- Socket.IO now authenticates the JWT and supports user rooms, Messenger realtime events, live chat/join/leave, call invites, and live gifts.
- Prisma model references in `server.js` were checked against `schema.prisma`; no unknown Prisma model reference remains.
- The production compatibility layer still creates the missing `Relationship` and `PostView` tables additively.

## External services that must be configured for real production operation
- Live video/audio/screen share: `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`.
- Persistent media uploads on Render: Cloudinary variables.
- Push notifications: Firebase FCM variables and the Android Firebase configuration in the Flutter app.
- Google Play/App Store purchase verification: server-side store verification credentials are still required before NovaCoins can be credited. The API intentionally refuses to credit coins from a client-only claim.

## Important limitation of this audit
The build environment here does not contain the Flutter SDK and cannot download the npm dependency `livekit-server-sdk` from the registry, so a real Android APK build and a live PostgreSQL/LiveKit integration test could not be executed in this environment. The source was checked statically instead; production credentials/services must still be exercised after deployment.
