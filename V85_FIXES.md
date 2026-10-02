# SocialNova V85 — Live / Calls / Reels / Admin Repair

- Live screen: full-screen tap/click increments, visible tap counter, viewer counter, gift counter, battle score HUD.
- Live gifts: redesigned picker with wallet balance, selected-gift preview, stronger presentation and sender/coin overlay.
- Calls: rebuilt call UI and added a dedicated Socket.IO `call:reel` event so shared Reels are synchronized to the other caller instead of being sent to a Live room.
- Home/Post/Reels profile rings: tapping an active LIVE/STORY/REEL/POST status now opens the corresponding surface directly.
- Reels feed: viewed Reels are no longer removed from the feed solely because they were already viewed, making vertical navigation continuous.
- Admin: ADMIN_EMAILS accounts can use super-admin privilege management; the served admin panel now has an explicit “grant all permissions” path (`DEVELOPER` + `*`) and verification tier selection.
- Admin panel JavaScript syntax was validated with Node. Backend JavaScript syntax was validated with Node.
- Flutter SDK was not available in the build environment, so a local `flutter analyze`/APK build could not be executed here.
