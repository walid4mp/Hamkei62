# SocialNova V101 — CI APK Build Fix

Fixed the Android CI analyzer errors reported by GitHub Actions run `36634262427`.

## Fixes
- Rewrote `_addEpisode()` in `lib/screens/creator_content_center.dart` using structured Flutter widgets instead of the malformed one-line dialog expression.
- Fixed the missing closing parenthesis that caused `Expected to find ')'` and the cascading `expected_executable` error.
- Added the missing `../core/nova_ui.dart` import to `lib/screens/home.dart`, resolving `NovaSectionTitle` and `NovaLiveTile` undefined-method errors.
- Removed imports reported as unused by `flutter analyze` from `home.dart`.
- Removed the unused private widget constructor `key` parameter warning.

## Validation
The container used for this repair does not include Flutter/Dart SDK, so a local `flutter analyze`/APK build could not be executed here. The changes were checked structurally and the reported parser/import errors were corrected directly.
