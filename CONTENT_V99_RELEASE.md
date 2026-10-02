# SocialNova V99 — Movies / Series / Episodes / Subscriptions

## Creator publishing
- Added a visible **فيلم / مسلسل** action to the main `+` creation sheet.
- Added a visible **اشتراك** action to the main `+` creation sheet.
- Added `CreatorContentCenterPage` with four sections:
  - نشر فيلم
  - إنشاء مسلسل + مواسم + حلقات
  - إدارة اشتراك المبدع
  - مكتبة المحتوى
- Movie publishing uploads poster/trailer/video and supports FREE, PAID and SUBSCRIBER access modes.
- Series publishing supports poster/trailer, subscriber-only mode and season-pass pricing.
- Episode publishing supports video, thumbnail, FREE/PAID/SUBSCRIBER access and per-episode price.

## Backend
- Added creator content listing endpoint: `GET /api/creator/content`.
- Added creator subscription plan endpoints:
  - `GET /api/creator/subscription-plan`
  - `GET /api/creator/subscription-plan/:creatorId`
  - `PUT /api/creator/subscription-plan`
- Added additive `CreatorSubscriptionPlan` Prisma model/table.
- Creator content POST routes are included in idempotency protection.
- Existing Google Play verification endpoints remain the source of purchase verification.

## Viewer subscriptions
- Subscriber-only series now show a real **اشترك لمشاهدة المحتوى** button.
- The app loads the creator's Google Play product ID, opens Google Play billing, and sends the purchase token to `/api/content/subscription` for server-side verification.

## Android
- Version bumped to `3.8.0 (20)`.
