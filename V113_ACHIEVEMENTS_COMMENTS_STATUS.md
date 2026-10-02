# SocialNova V113 — Achievements, Profile Status Priority & Comment Hearts

## Implemented

### 1. Admin follower boosts → achievements
- Admin follower changes continue using `demoFollowersCount`.
- The achievements API now includes this value in the displayed follower total.
- Creator milestone progress also now uses real followers + admin-added followers.
- Achievement tasks include follower milestones plus content, comments, Live, likes and following tasks with NovaCoin reward values.
- Follower milestone rewards remain idempotent and are granted automatically by the existing milestone engine.

### 2. Profile status ring priority
- Tapping a profile avatar/status ring now uses the priority `LIVE -> STORY -> POST -> REEL`.
- If Live and Story are both active, Live opens first.
- Removed the extra Story mini-button so the avatar has one predictable action.

### 3. Comment hearts
- Added real user heart/unheart for Post comments.
- Added real user heart/unheart for Reel comments.
- Added persistent admin heart counters for both comment types.
- Comment APIs return `likeCount` and `likedByMe`.
- Comments are sorted by total hearts (real + admin) so the most-liked comments appear first.
- Comment rows now use a compact social layout: display name, `متابعة +`, body, heart count, and `رد`; the separate `@username` line was removed.
- Reply `parentId` is now persisted for Post and Reel comments.

### 4. Admin comment-heart controls
- Admin Growth page has a `قلوب التعليقات ❤️` section.
- Supports Post/Reel comment selection and positive/negative heart adjustments.
- Recent comments can be loaded and tapped to select their Comment ID.
- Changes are audited under `comments.moderate`.

## Validation
- `node --check backend/src/server.js` passes.
- Prisma/Flutter full builds were not executed in this environment because Flutter SDK and Prisma CLI dependencies are not installed locally.
- The project CI should run `flutter analyze` and the Android build after pushing the archive.
