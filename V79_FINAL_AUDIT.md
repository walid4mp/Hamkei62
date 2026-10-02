# SocialNova V79 Final Audit

## Changes carried into V79
- Preserves V78 Live + Messenger fixes.
- Fixes the SocialNova Hub menu route so selecting Hub actually opens `SocialNovaHubPage`.
- Removes end-user server/API URL controls from login and Settings. The API endpoint remains internal to the app.
- Removes server URL exposure from connection/upload error messages.
- Keeps Messenger call token route `/api/calls/token` separate from Live rooms.
- Keeps Live pause/resume, tap counter, gift counter, 14-gift catalog and cinematic effects.
- Keeps profile Reels tab and `/api/users/:id/reels`.
- Keeps Movies/Series/Seasons/Episodes, Trailer/Poster, FREE/PAID/SUBSCRIBER access, Season Pass and Google Play verification endpoints.
- Keeps creator/platform revenue split fields and ad-qualified revenue data.
- Keeps admin conversation review and audit logging.
- Keeps status rings for Live/Story/Post/Reel.

## Static checks completed in this environment
- `node --check backend/src/server.js`
- `node --check backend/src/seed.js`
- All local Dart imports resolve to existing files.
- All `Api.*()` references found in the Flutter source have a declared API method.
- The previously broken Hub route was detected and corrected.
- No feature directories were deleted.

## CI checks configured
- Flutter 3.29.2: `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --release`.
- Node 20: `npm install`, Node syntax checks and `prisma validate`.

## Important deployment behavior
- Render uses `npm install --omit=dev`, not `npm ci`, because the repository lock is intentionally allowed to be refreshed by npm for the LiveKit/Multer dependencies.
- Production media storage still requires the configured durable provider (Cloudinary) rather than ephemeral Render disk.
- LiveKit still requires `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET`.
- Google Play content/subscription verification still requires the corresponding service-account environment variables.
