# SocialNova V68

- Fixed the production signup/login failure caused by missing `User.relationshipStatus` / `relationshipSince` columns.
- Added non-destructive startup schema compatibility.
- Added `/api/admin/status` and confirmed `/api/admin/overview` is part of the deployed server source.
- Added protected conversation search/review for authorized moderators with Audit Log entries.
- Redesigned the birthday picker into a premium Arabic wheel picker matching the SocialNova neon visual language.
- Kept the admin panel dark-neon glass visual system and expanded its administration navigation.
- Render/Docker remains safe by default: no destructive Prisma push at startup.
