# SocialNova V175 — Release Audit + Story Auto-Hide + Update Version

- Audited V165 through V174 source changes.
- Fixed the previously incomplete Story `autoHideAfterInteraction` behavior: the first viewer interaction now archives the story when this option is enabled.
- Bumped Flutter version to `3.9.1+24`.
- Aligned Android `versionCode` to `24` and `versionName` to `3.9.1` so the build is clearly an update over the previous release.
- Application ID remains `com.socialnova.app`.
- Release signing must use the same keystore as the currently installed APK for an in-place Android update.

Verification in this environment: all backend JS syntax checks pass and ZIP integrity is checked. Flutter/Dart SDK is unavailable locally; GitHub Actions must run Flutter analyze/test/build. Backend npm dependencies are not installed in this environment, so the 24-test suite was not rerun in this turn.
