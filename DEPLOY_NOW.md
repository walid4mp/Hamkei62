# SocialNova V68 — Deploy checklist

1. Deploy this project from repository root so Render uses `Dockerfile` at the root.
2. Keep `PRISMA_PUSH` unset or `false`. The server now performs only additive compatibility changes for the relationship fields and never drops production columns/tables.
3. Ensure `DATABASE_URL` and `JWT_SECRET` are set.
4. For an ordinary admin account, put its exact email in `ADMIN_EMAILS`. A `DEVELOPER` role bypasses that list.
5. After deploy, open `/api/health`. Expected JSON contains `ok: true`.
6. Log into `/` and open the Admin panel. The panel now includes a protected conversation-review area; access is controlled by `CONVERSATION_REVIEW`/admin privileges and every opened conversation is written to Audit Log.
7. The previous 404s happened because the deployed revision did not contain the admin route block. This package contains explicit `/api/admin/status` and `/api/admin/overview` routes.

## Database compatibility
The production database previously reported that `User.relationshipStatus` did not exist. Startup now executes only:
- `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "relationshipStatus" ...`
- `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "relationshipSince" ...`

No destructive Prisma push is executed automatically.
