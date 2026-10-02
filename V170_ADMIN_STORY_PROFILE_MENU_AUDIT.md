# SocialNova V170 — Admin / Stories / Profile / Home Menu Repair

## Admin
- Added unified content boost controls for views, likes/hearts and Live taps.
- Admin growth UI now covers Reel, Post, Story, Live, Movie, Series and Episode.
- Comment heart boost remains available for Post/Reel comments.
- Added admin Live creation from the admin publishing tab.
- Nova TV admin already supports upload buttons for poster/backdrop/trailer/video/thumbnail fields; this release makes the surrounding publishing flow explicit.

## Stories
- Story creation now persists replyEnabled, archived, autoHideViews, autoHideAfterInteraction and scheduledAt.
- Story editing now persists the same settings.
- Scheduled stories are hidden until their scheduled time.
- Auto-hide by view count archives the story once the threshold is reached.
- Story publishing sheet was improved with story-specific controls and clearer status text.

## Profile
- Existing custom profile background upload from the phone remains server-backed and applied across the profile surface.
- Existing profile entry effects, avatar frame, custom background and profile music were audited and retained.

## Home / three-dots menu
- Added a dedicated top-right three-dots menu.
- Menu exposes Search, SocialNova Marketplace, Google Play/NovaCoin wallet, Nova TV, Content Studio, Digital ID and Settings/Privacy.
- Bottom navigation was simplified to Home / Reels / Create / Messages / Profile.

## Verification
- `node --check backend/src/server.js` passed.
- Backend test suite: 24/24 passed.
- Dart/Flutter SDK is not installed in this environment, so a real `flutter analyze`/APK build was not claimed.
