# SocialNova V165 — Chat / Media / Status Navigation Audit

## Implemented
- Unified profile/status navigation from Messenger, chat header, Reels, posts, comments, Live host header and shared-call Reels.
- Status ring behavior uses backend status data and refreshes `/api/users/:id/profile` on interaction; priority is LIVE -> STORY -> REEL -> POST when the ring has multiple active segments.
- Messenger conversations now include `statusRings` from `/api/conversations`.
- Names open the user's profile while avatar/status rings open LIVE/Story/content.
- Message reaction picker is anchored to the pressed message, with a WhatsApp-style white reaction pill and double-tap ❤️.
- In-chat images open in an InteractiveViewer with zoom and a visible zoom affordance.
- Voice messages remain in-app using `just_audio`; composer keeps image + emoji + voice controls visible on small screens, with effects moved under More.
- Story/Post/Reel/Live comment avatars support the same status/profile navigation.
- Call ring timeout default changed from 45 seconds to 60 seconds; client UI waits 61 seconds to allow the server's 60-second timeout event to arrive.
- Existing call lifecycle automatically writes a `[call_event]` message into the conversation on reject/missed/end.

## Verification performed in this environment
- Dart-style bracket balance: `social.dart`, `home.dart`, `nova_ui.dart` — OK.
- `node --check backend/src/server.js` — OK.
- `node --check backend/src/modules/calls.js` — OK.
- ZIP integrity verified after packaging.

Flutter SDK is not installed in this environment, so `flutter analyze` and APK compilation must be confirmed by GitHub Actions.
