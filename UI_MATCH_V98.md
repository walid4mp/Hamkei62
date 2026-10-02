# SocialNova V98 — Reference UI Pass

## UI changes
- Home header now follows the supplied Arabic reference layout: SocialNova branding on the left, search/notifications/profile on the right.
- Bottom navigation is explicitly laid out left-to-right to match the supplied reference while the app remains RTL for content.
- Home now includes the supplied discovery hierarchy: stories → neon gift banner → live cards → short-video cards → posts.
- Live cards use the existing `/api/live` data and open the existing functional LiveKit room.
- Short-video cards use the existing `/api/reels` data and open the existing functional Reels screen.
- Post media is presented edge-to-edge with dark surfaces, neon borders and reference-like proportions.
- Existing likes, comments, reposts, bookmarks, sharing, stories, LiveKit, gifts and API behavior remain connected to the existing implementation.

## Version
Flutter build: `3.8.0+20`

## Verification note
The execution environment does not contain the Flutter/Dart SDK, so `flutter analyze` and an APK build could not be executed here. The modified source was inspected statically and the changes are isolated to the Flutter presentation layer plus the version/release metadata.
