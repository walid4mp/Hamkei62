# SocialNova V78 – Production Fixes

## Fixed
- Messenger voice/video calls no longer use `/api/live/token`; dedicated `/api/calls/token` creates a real LiveKit call token. This removes `LIVE_NOT_FOUND` for calls.
- Chat theme/background API is aligned to `/api/chat/:userId/theme`, with the existing `/api/chats/...` compatibility route preserved on the backend.
- Live pause/resume added for hosts without ending the live room.
- Live tap/like counter added and synchronized through Socket.IO.
- Live gift counter added; gift delivery is broadcast to the live room after a successful wallet transaction.
- Expanded live gift catalog from 6 to 14 gifts.
- Added cinematic live visual effects: Natural, Cinema, Noir, Dream, Warm, Cool.
- Added a visible live pause overlay and host pause/resume control.
- Added Reels tab to user profiles and a backend `/api/users/:id/reels` endpoint for the user's own Reels.
- Redesigned NovaCoin withdrawal dialog with clearer balance, method selection, fee/net preview and validation.
- Preserved existing Messenger, Stories, Reels, LiveKit, groups, wallet, movies/series, creator and admin systems.

## Verification performed
- `node --check backend/src/server.js` passes.
- Static consistency checks for new Flutter API/profile references pass.
- No feature folders were removed.

## Important
Flutter SDK is not installed in this execution environment, so a local `flutter analyze`/APK build could not be executed here. CI remains configured for Flutter 3.29.2 and the Android release workflow remains enabled.
