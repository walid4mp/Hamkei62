# Firebase / FCM setup for SocialNova

1. Firebase Console -> Project settings -> Your apps -> Android app.
2. Download the real `google-services.json` for the Android package `com.socialnova.app`.
3. Put it here:
   `flutter-app/android/app/google-services.json`
4. Do NOT put the Render Service Account private key in this file or in Git.
5. In Render add:
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_PRIVATE_KEY`
6. `FIREBASE_PRIVATE_KEY` must contain the complete service-account private key. Render may store it with `\n`; SocialNova converts those escaped newlines automatically.

The Android build is intentionally conditional: if `google-services.json` is missing, the APK can still compile, but FCM will stay disabled at runtime. Once the real file is present, the Google Services Gradle plugin is enabled automatically.

For calls, SocialNova sends an FCM data message with `type=call`; Android shows the full-screen Call UI through `flutter_callkit_incoming`. The normal Socket.IO/LiveKit call path remains active while the app is open.
