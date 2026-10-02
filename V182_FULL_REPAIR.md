# SocialNova V182 — Full Repair

## Fixed backend 404 routes
- PATCH `/api/settings` for profile privacy/settings save.
- GET `/api/users/:id/stories` for profile/story opening.
- Live lifecycle: GET/POST `/api/live`, token, pause, resume, end, stats and top.
- Calls REST lifecycle: start, token, accept, reject, end, history and detail.
- LiveKit configuration/token helper.

## Fixed Flutter UI
- Bottom navigation Messenger now uses the chat icon; Create remains the center plus button.
- Unread badge is attached to Messenger instead of Profile.
- When a user has both LIVE and STORY, tapping the avatar opens a choice sheet.
- Story opening now has a working per-user stories endpoint and queue.

## Release
- Flutter version: 3.9.4+26
- Existing update manager can detect a GitHub Release with a higher versionCode.

## Validation
- `node --check backend/src/server.js` passes.
- Flutter/Dart SDK is not installed in this execution environment, so `flutter analyze`, `flutter test`, and `flutter build apk` must be verified by the GitHub Actions workflow.
