# SocialNova V163 — Professional Chat, Voice, Reactions, Images, Calls & Call Reels

Implemented on top of V162:

- WhatsApp-style quick reaction bar on long-press with persistent server-side message reactions and realtime sync.
- Voice messages play inside SocialNova with play/pause, progress and duration; no external player is opened.
- Chat images open in a full-screen zoomable InteractiveViewer.
- Calls now use the persisted REST Call lifecycle instead of socket-only fake rooms.
- Incoming call UI is a professional ringing card with ringtone, accept/reject, 45-second timeout handling and missed-call state.
- Outgoing calls show "جاري الاتصال… بانتظار الرد" until accepted; ring timeout closes automatically.
- Call end/reject/missed states are persisted as an automatic call card in the conversation; no manual message is sent by the user.
- Call cards show duration/status and allow one-tap redial.
- Reels inside calls now open as a vertical full-screen PageView with swipe navigation and a share-to-peer action.
- Incoming shared Reels open in the same vertical Reels viewer.
- Added bundled call ringtone WAV asset.
- Backend adds the additive MessageReaction table automatically at startup; no destructive Prisma migration is required.

Verification performed in this environment:
- Node server syntax check: passed.
- Dart source bracket/quote structural audit: passed for modified Dart files.
- Ringtone WAV integrity: passed.
- Flutter SDK is not installed in this environment, so `flutter analyze`/APK build must be confirmed by GitHub Actions.
