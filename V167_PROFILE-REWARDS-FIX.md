# SocialNova V167 — Profile Customization + Music + Achievement Rewards Repair

## Fixed
- Custom profile background can now be selected from the phone gallery and uploaded through `/api/upload`.
- Custom background gets a preview before saving and is rendered on the profile after saving.
- Added built-in background aliases for milestone rewards (`bg_neon`, `bg_gold`, `bg_diamond`, `bg_galaxy`, `bg_aurora`).
- Profile frame rendering now applies selected frames and milestone frame IDs (`frame_ice`, `frame_neon`, `frame_gold`, `frame_diamond`, `frame_legend`).
- Added Ice frame and reward background choices to profile customization.
- Profile music can be uploaded directly from the phone as audio.
- Spotify/Apple Music/Deezer page links are opened externally instead of incorrectly trying to stream them as raw audio.
- Direct MP3/M4A/AAC-style URLs continue to play inside SocialNova.
- Creator milestone rewards are now reconciled into the user's unlocked profile cosmetics/reward arrays.
- Existing milestone reward records from older builds are repaired automatically when milestone rewards are loaded.
- Creator reward IDs are translated to human-readable Arabic names in the rewards screen.
- Achievement task rewards now grant NovaCoin exactly once when the task becomes complete.
- Achievement UI now explicitly shows whether the NovaCoin reward was received.
- Existing reward/profile selections are not overwritten when a user already has a deliberate selection.

## Storage note
Production profile-background/music uploads require the existing durable media storage configuration (Cloudinary on Render). If production storage is not configured, the upload UI reports the server error instead of silently saving a broken URL.

## Verification
- `node --check backend/src/server.js` passes.
- No Flutter SDK/Dart SDK is installed in this execution environment, so Flutter analyzer/APK compilation was not run locally.
