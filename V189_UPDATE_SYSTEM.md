# V189 — production update notification system

- Version: 4.0.0+32
- Successful `main` builds create a GitHub Release and upload a versioned APK.
- The app checks `releases/latest` and compares Android `versionCode`.
- Update availability appears in the update dialog, Android notifications, and the in-app Notifications page.
- FCM `app_update` messages open the update flow when tapped.
- GitHub Actions calls `/api/admin/releases/broadcast-update` after publishing.

## Required production secrets

Set the same `UPDATE_BROADCAST_SECRET` in GitHub Actions secrets and Render environment variables.
FCM also requires `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` in Render.

## Signing

`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS` must correspond to the same signing key used by the installed production APK for seamless Android updates.
