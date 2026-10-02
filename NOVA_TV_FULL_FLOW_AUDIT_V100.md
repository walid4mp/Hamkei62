# SocialNova Nova TV — Full Flow Audit V100

Date: 2026-09-29

## Flow audited

Creator -> Series -> Season -> Episode -> Published catalog -> Nova TV -> Google Play subscription -> protected episode playback.

## Verified in source/tests

1. Creator endpoints exist for series, seasons and episodes.
2. Published series are exposed by `/api/series`.
3. Published episodes are exposed by `/api/episodes/:id` and nested in published series.
4. Nova TV loads series and episodes from the API.
5. The player calls `/api/content/:kind/:id/view` before obtaining the video URL.
6. The backend does not return the protected video URL until access is allowed.
7. Series-level `subscriberOnly` now protects every episode in that series unless the viewer is the creator or has an active verified subscription.
8. Episode access modes `SUBSCRIBER` and legacy `SUBSCRIPTION` both require an active verified subscription.
9. Subscription purchase is tied to the creator's active `CreatorSubscriptionPlan` and the submitted Product ID must match the plan.
10. Google Play subscription tokens are verified server-side through the Android Publisher API when Google Play credentials are configured.
11. The Flutter client only treats a backend response with `verification == VERIFIED` as successful activation.
12. The UI shows the subscription action when the series is subscriber-only OR any nested episode requires a subscription.
13. Existing admin legacy `SUBSCRIPTION` access values are normalized to canonical `SUBSCRIBER` on writes.

## Automated results

- Node syntax check: PASS
- Existing backend tests: PASS
- Nova TV flow contract tests: PASS
- Total tests: 24 passed, 0 failed

## Important runtime limitation

A real Google Play purchase cannot be executed inside this build environment. Therefore the following production-dependent steps still require a Google Play test track/device and valid Render environment variables:

- `GOOGLE_PLAY_PACKAGE_NAME`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`

The service account must have the required Google Play Console permissions for Android Publisher API access, and the subscription Product ID must be published/available to the test account.

## Expected real-device path

1. Creator creates a series and marks it subscriber-only, or creates a subscriber-only episode.
2. Creator creates Season 1.
3. Creator uploads and publishes Episode 1.
4. Creator creates an active subscription plan with the exact Google Play Product ID.
5. Viewer opens Nova TV -> series.
6. Viewer sees the subscription button.
7. Google Play completes the subscription purchase.
8. Flutter sends the Android purchase token to `/api/content/subscription`.
9. Backend verifies the token with Google Play.
10. Backend stores a `VERIFIED` `CreatorSubscription` with the Google expiry time.
11. Viewer opens Episode 1.
12. `/api/content/EPISODE/:id/view` checks the verified subscription.
13. Backend returns the protected `videoUrl` only after authorization.
14. Flutter starts the video player.

If Google verification is unavailable or fails, the purchase is not treated as activated and protected playback remains blocked.
