# SocialNova V112 — Admin Media + TV + Reels + Live Gifts

## Implemented
- Admin can upload durable media through the existing `/api/upload` pipeline.
- New in-app Admin tab: **النشر والتفاعل** for publishing Reels, Stories and video posts.
- Admin engagement boosts now support POST, REEL, STORY, LIVE, MOVIE, SERIES and EPISODE for views + likes.
- Engagement boosts are stored in explicit `adminViews/adminLikes` counters and audited; they do not create fake users or fake Like rows.
- Follower increases now call creator milestone logic and include `demoFollowersCount`, so milestones/achievements unlock correctly.
- Nova TV is reachable directly from the Home header.
- Admin Nova TV forms now have upload buttons for video/poster/backdrop/trailer/thumbnail fields.
- Reels include a limited TV episode preview: one recent episode per series, interleaved periodically, with a **شاهد كل الحلقات** CTA.
- Paid episode previews never expose the protected video URL.
- Live gift artwork now falls back to preview artwork when image artwork is missing, improving gift visuals in LIVE.
- Live gift control is more prominent and shows the live gift counter.

## Validation
- `node --check backend/src/server.js` passes.
- Prisma/Flutter full validation could not be executed in this runtime because the project does not include installed Prisma CLI / Flutter SDK.
