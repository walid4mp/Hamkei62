# SocialNova V185 — Full Merged Release

Version: 3.9.7+29

This release consolidates the current V182/V183/V184 repair line into one installable release tree.

## Included repair areas
- Stories: upload/create, audience/privacy filtering, scheduling, expiry/archive, viewer tracking, reactions/replies, seen state, profile story state and story navigation.
- Live: live room creation/listing/token, pause/resume/end, comments, moderators, join requests, stats/top, LiveKit configuration handling, status rings and profile navigation.
- Calls: audio/video call start/token/accept/reject/end/history/detail and call chat/status handling.
- Messenger: navigation/icon placement, direct messaging, media/status handling and story reaction/reply integration.
- Profile: edit/save settings, avatar/cover URLs, profile background choices, contrast overlay, readable counters/tabs/metadata, privacy visibility and profile effects.
- Admin: story/live moderation surfaces, permissions and operational endpoints already present in the merged tree.
- Updates: Android version 3.9.7 (versionCode 29) for upgrade discovery from older releases.
- Existing features retained: Reels, groups, Nova TV, gifts, wallet, creator/rewards, notifications, digital ID, fitness, store, music and other modules present in the base project.

## Verification performed in this environment
- Backend Node test suite: 24/24 passed.
- Backend syntax checks are compatible with Node test execution.
- ZIP contents and Android version fields were checked.
- Flutter/Gradle full build was not executed because Flutter SDK is unavailable in this environment.

## Upgrade requirement
The release APK must be signed with the same Android signing key as the currently installed app for an in-place update.
