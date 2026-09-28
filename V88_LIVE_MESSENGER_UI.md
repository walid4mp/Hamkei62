# SocialNova V88 — Live + Messenger Pro UI (design integration)

Base: SocialNova-V87-APK-BUILD-FIX.

This release integrates the approved Live + Messenger interface design into the
real app (Flutter client + backend), instead of shipping it as an external
prototype. Everything is wired to live data — no mock content, no fake numbers.

## What was integrated

### 1. New presentation kit — `flutter-app/lib/core/nova_ui.dart`
A single source of truth for the new design layer, built on the existing `SN`
theme so the app identity (violet/indigo neon, dark glass) stays coherent:

| Widget | Used by |
| --- | --- |
| `NovaTokens` | radius/spacing/motion scales, glass tints, gradient name shader |
| `NovaGlass` | frosted surfaces (pills, comment bubbles, composer, search field) |
| `NovaLiveBadge` | pulsing `مباشر` flag (opacity/scale only) |
| `NovaStatPill` | viewers, taps, gift score, challenge score |
| `NovaGlassIcon` | circular glass actions in the Live layer |
| `NovaTabs` | segmented filters (Live ordering, Messenger inbox tabs) |
| `NovaCommentTile` | Live comment bubble: accent-gradient author, reply chip, pin |
| `NovaTypingDots` | three-dot typing animation |
| `NovaChatRow` | inbox row: avatar, verified badge, preview, stamp, unread badge |
| `NovaBubble` | chat bubble with a direction-aware tail |
| `NovaVoiceNote` | voice bubble: play, waveform, duration |
| `NovaTicks` | read/delivered double tick |
| `NovaComposer` | dark glass composer with send/mic primary action |
| `NovaHeartsOverlay` | rising-hearts layer driven by a burst counter (CustomPaint) |
| `NovaLiveTile` | Live discovery card (thumbnail, LIVE flag, viewers, host) |
| `NovaSectionTitle` | section header with an optional action |

Performance rules baked in: transform/opacity-only motion, single-pass
`BackdropFilter` per surface with `blur: 0` available for long lists, painters
that repaint only when their animation value changes.

### 2. Live — discovery screen (`LivePage`)
- New header, ordering tabs (`رائج` / `الجديد`) and a 2-column discovery grid of
  `NovaLiveTile` cards (LIVE flag, viewer counter, host avatar/name, title).
- New horizontal "مذيعون نشطون الآن" rail built from the same live rooms.
- Long-press a card to share the room to chats (previous share action preserved).
- The old tabs (`الكل/الألعاب/الموسيقى/الدردشة`) were decorative — they never
  filtered the payload. They are replaced by two ordering tabs that work on the
  loaded rooms (viewers desc / newest first) without extra requests.
- Start-live bottom sheet, empty state, 8-second auto-refresh, FAB and watch
  navigation all preserved.

### 3. Live — room screen (`LiveRoomPage`)
- Premium host header: glass host chip (avatar + name + verified badge + follow),
  pulsing LIVE flag, live viewer counter, share action, and the end-live action
  moved into the header (host only).
- HUD restyled with glass pills: taps, gift count, gift score, challenge score.
  The challenge bar was moved below the HUD so the two no longer overlap.
- Comment rail now renders `NovaCommentTile` (glass bubble, gradient author,
  reply chip, pin marker) while keeping tap-to-reply, long-press actions,
  moderator pin/delete and profile navigation exactly as before.
- Bottom bar: glass comment field, heart/tap pill with counter, gift button,
  host controls (mic, camera, menu) and the join-request action for viewers.
- New rising-hearts layer replaces the single centered ❤️; it is fed by the same
  tap event that emits `live:tap` to the room.

### 4. Messenger — inbox (`MessengerPage`)
- Header (title + message requests + new chat), local search field, and the
  three inbox tabs (`الكل` / `غير مقروءة` / `مجموعات`).
- Rows are now data-complete: avatar, verified badge, readable last-message
  preview (`أنت: …` for your own last message), compact stamp
  (today → `HH:MM`, yesterday → `أمس`, this week → `قبل N أيام`, older → `D/M`)
  and the unread counter, all from `/api/conversations`
  (`lastMessage`, `unreadCount`) which already existed on the server.
- Backend markers (`[image]`, `[story_reply]`, `[live_share]`, `[call:audio]`, …)
  are translated into readable Arabic previews.
- Real typing presence: rows show `يكتب الآن…` from live socket events, with a
  4-second expiry so a lost stop-event can never stick a row.

### 5. Messenger — conversation (`ChatPage`)
- Bubbles use `NovaBubble` (direction-aware tail, same violet gradient for own
  messages), ticks use `NovaTicks`.
- Header shows `يكتب الآن…` under the peer name when the peer is typing.
- Composer rebuilt as `NovaComposer` (dark glass + gradient round action) and it
  keeps every previous capability: send/mic, recording note, image, reactions,
  more-actions, secret-mode banner and read receipts.

### 6. Realtime typing presence (end to end)
- `backend/src/server.js`: new `typing` socket relay → `io.to('user:<id>')`.
- `flutter-app/lib/core/socket.dart`: `typing` stream + `sendTyping()`.
- `flutter-app/lib/screens/social.dart`: debounced emit while typing, emit stop
  on send/dispose, listener with expiry.
- Nothing is faked: typing only appears while real events arrive.

## Version & packaging
- `flutter-app/pubspec.yaml` → `3.6.0+17` and `android/app/build.gradle` →
  `versionCode 17` / `versionName '3.6.0'` (the Gradle block overrides pubspec, so
  both must move together; they were still announcing 3.4.0/14).
- A release APK was built in this environment with Flutter 3.29.2 and verified
  to contain all four ABIs, signed with the repo's usual debug signing config
  (installable for testing; store builds need the release keystore).

## Bug fixed on the way
- `lib/core/theme.dart` — `VerifiedBadge` created its `AnimationController`
  lazily and accessed it from `dispose()`, so disposing a `NONE`/`NORMAL` badge
  threw *"Looking up a deactivated widget's ancestor is unsafe"* in debug. The
  controller is now created on demand and never from `dispose()`. This became
  visible because inbox rows and comment tiles now always carry a badge.

## Deliberate omissions (no data, so no UI)
- No "top gifters" rail inside the Live room: the API exposes neither a room
  gift leaderboard nor gifter identities.
- No online/last-seen dot in the inbox: the API has no presence field. The dot
  component exists in `NovaChatRow` (`online`) and turns on the moment presence
  lands in `/api/conversations`.
- No typing line inside the inbox for a peer you never opened: presence events
  are delivered only to the conversation you are in.

## Verification performed in this environment
- `flutter analyze lib` → 0 errors, 0 warnings (only pre-existing
  `withOpacity` deprecation infos, none added by this release).
- `flutter test` → all tests pass, including the new
  `test/live_messenger_ui_test.dart` (6 widget tests: discovery tile, Live HUD,
  rising hearts, inbox row, conversation bubbles + composer, tab switching) run
  in an RTL Arabic 390px surface so overflows and direction bugs fail the build.
- `flutter build bundle` → compiles clean (full kernel build of the app).
- `node --check backend/src/server.js` → syntax OK.
- Flutter 3.29.2 / Dart 3.7 toolchain, same as the repo CI (`android.yml`).

## Design source
The interactive design that this release implements is kept next to the code as
`docs/design/live-messenger-design.html` (single file, open it in any browser):
it holds both screens, the control panel used to pick tokens, and the copy-out
specification text.

## Files changed
```
backend/src/server.js                        typing relay
flutter-app/pubspec.yaml                     version 3.6.0+17
flutter-app/lib/core/nova_ui.dart            NEW — design kit (Live + Messenger)
flutter-app/lib/core/socket.dart             typing stream + sendTyping
flutter-app/lib/core/theme.dart              VerifiedBadge dispose fix
flutter-app/lib/screens/social.dart          Live discovery, Live room, inbox, chat
flutter-app/test/live_messenger_ui_test.dart NEW — widget regression tests
docs/design/live-messenger-design.html       design source of this release
V88_LIVE_MESSENGER_UI.md                     this file
```
