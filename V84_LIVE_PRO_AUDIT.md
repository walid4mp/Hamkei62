# SocialNova V84 — Live Pro / Messenger / Story Repair

Base: SocialNova-V83-FINAL-REPAIRED

## Changes
- Redesigned the Live room UI around the supplied TikTok-style references:
  - premium top host/viewer header
  - two/four participant live grid layout when multiple LiveKit participants are present
  - participant rank badges and audio state
  - challenge score bar
  - glass controls, comments rail, gifts and reaction feedback
  - cleaner host tools grouped under a professional menu
- Fixed incoming call routing mismatch (`from` vs `fromId`).
- Added realtime call accept/reject events to the Flutter socket layer.
- Added call history messages with audio/video type and duration after a completed caller-side call.
- Made profile avatar Story opening prioritize an active Story before the profile-image action.
- Preserved the existing backend, Prisma schema, LiveKit token flow, wallet, admin, stories, reels and profile systems.

## Validation performed
- Node.js syntax check passed for `backend/src/server.js`.
- Structural bracket/parenthesis checks passed for modified Dart files.
- Compared against V83: only the three intended Dart files were modified before this audit file was added.

## Note
Flutter SDK is not installed in the current build environment, so a local `flutter analyze` / APK build could not be executed here. The repository CI remains the authoritative Flutter build check.
