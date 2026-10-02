# SocialNova V166 — Push notifications and call alerts

## What is included
- In-app and background message notifications.
- Unread message counter in the bottom Messenger tab.
- Notification actions: Reply, Like, Mute.
- Per-account message notification sound and call ringtone preferences.
- Incoming call alerts through `flutter_callkit_incoming` while the app is foreground/background/terminated, with call accept/decline lifecycle hooks.
- Server sends message/call FCM data only when the recipient is not connected through Socket.IO, avoiding duplicate foreground alerts.

## Required Firebase setup for real closed-app push
The Flutter project intentionally does **not** contain a fake Firebase configuration. To enable FCM on the release APK:

1. Create/register Android app package `com.socialnova.app` in your Firebase project.
2. Download the real `google-services.json`.
3. In GitHub repository secrets, add `GOOGLE_SERVICES_JSON_BASE64` containing the base64-encoded contents of that file.
4. The Android workflow will materialize it as `flutter-app/android/app/google-services.json` during CI.
5. Render/backend must have the existing Firebase Admin credentials configured:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY`

Without the real Firebase Android configuration/token, the app can still build and use Socket.IO while open, but Android cannot receive FCM when the process is fully terminated.

## Notification sounds
Sounds are bundled under `flutter-app/assets/sfx/` and Android `res/raw/`. Android notification channels are persistent; changing a sound creates/uses the corresponding channel, which is the supported Android behavior.
