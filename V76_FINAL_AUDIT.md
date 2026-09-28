# SocialNova V76 — Final Integration Audit

## Baseline reviewed
The Library contains cumulative SocialNova archives from V66 through V75, with V72 Production Repair, V73 Conversation Review Fix, V74 Featured Account, and V75 Explore/Search as the latest cumulative line. The exact original V7 ZIP is not present in the accessible Library, so V75 was used as the cumulative source rather than inventing missing V7 files.

## Existing systems preserved
- Authentication and dedicated developer/admin login.
- Messenger, conversation list, read/delivered states, disappearing/secret messages.
- Chat themes/background endpoints and duplicate `/api/chat` + `/api/chats` compatibility routes.
- Posts, comments, likes, reposts, bookmarks, Stories, Reels, LiveKit live rooms and battles.
- Groups/communities, wallet, gifts, withdrawals, marketplace.
- Digital ID card, relationship controls, profile visibility controls.
- Device bans, verification, moderation, admin conversation review and audit logs.
- Explore/global search with users, posts, reels, groups, live and stories.
- Featured-account promotion without fabricating views/followers.

## V76 additions
### Movies and Series
- Movies with poster, trailer, duration and secure access modes.
- Series with multiple seasons and ordered episodes.
- Per-episode FREE / PAID / SUBSCRIBER access.
- Season Pass data model and access checks.
- Movie FREE / PAID / SUBSCRIBER access.
- Server-side content access checks before returning playback URLs.
- Locked paid/subscriber video URLs are not exposed by public series/movie listing endpoints.

### Monetization
- Google Play purchase tokens are stored server-side.
- When Google Play service-account verification is configured, one-time products are verified against Google Play before content access is granted.
- Subscription tokens are verified through Google Play subscriptions v2.
- Wallet coin purchases now use the same server-side Google Play verification path instead of trusting a client assertion.
- Creator/platform split is stored per content item; defaults are 70/30 and remain configurable.
- Qualified ad impressions and eCPM/revenue fields are stored for creator analytics.

### Creator ecosystem
- Creator Studio aggregates movies, series, episodes, subscriptions, purchases and qualified ad revenue.
- Creator teams and team members.
- Audio rooms.
- Creator battles and participant scoring.
- Creator Academy courses/lessons.
- Hall of Fame entries.
- Creator Coach session storage and a safe non-fabricated starter workflow.

### Admin
- Movie/series moderation endpoints.
- Featured movie/series controls.
- Content revenue summary.
- Explicit Google Play verification actions for pending content purchases/subscriptions/season passes.

## Database production repair
The startup compatibility layer remains additive and creates missing legacy tables such as `PostView`, `Relationship`, `ChatTheme`, and `AuditLog`. V76 extends the same additive strategy to the new Hub tables, so an older Render database does not immediately crash with Prisma P2021 merely because the code was deployed before the new schema.

## Important deployment requirements
1. Set `DATABASE_URL` and existing Render secrets.
2. Keep Cloudinary configured for durable media in production.
3. Keep LiveKit configured for real live/video rooms.
4. For real Google Play verification, configure:
   - `GOOGLE_PLAY_PACKAGE_NAME`
   - `GOOGLE_SERVICE_ACCOUNT_EMAIL`
   - `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`
   and grant the service account the required Google Play Developer API access.
5. The backend deliberately does **not** mark a Google purchase as verified merely because the Flutter client says it succeeded.
6. Render free instances can still sleep; that is a hosting characteristic, not an application correctness failure.

## Validation performed in this environment
- `node --check backend/src/server.js` passes after the V76 backend changes.
- The Flutter SDK is not installed in this execution environment, so a local `flutter analyze` / APK build could not be executed here. CI is included to run Flutter analysis/build on GitHub.
- Network package installation was unavailable/too slow in this environment, so Prisma CLI validation could not be executed locally. The repository still includes the Prisma schema, lockfile, Docker generate step, and CI validation command.

## V76.1 activity status rings
- Added backend-derived profile activity status for LIVE, active STORY, recent POST and recent REEL.
- Status is returned as `statusRings` on profile, feed, stories and Reels author payloads.
- Flutter now renders segmented avatar rings without fabricating activity: LIVE red, STORY gold, POST cyan, REEL violet.
- The profile and main Story/Feed/Reels avatars use the same status component.
- Activity freshness for POST/REEL is currently the last 24 hours; LIVE is active-room state; STORY is active-until-expiry state.
- A future per-viewer unread state can be layered on top without changing the visual component.
