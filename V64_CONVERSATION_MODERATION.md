# V64 — Conversation Moderation Center

Adds an authorized, read-only conversation review workflow.

Backend:
- GET /api/admin/conversations/:userId/:peerId
- GET /api/admin/audit-logs
- Conversation moderator access controlled by CONVERSATION_MODERATOR_EMAILS (developers are allowed).
- Every conversation view creates an AuditLog record.

Flutter:
- ConversationModerationCenterPage
- Admin dashboard entry point

No password or user-session impersonation is used.


## V65 Developer / Moderator permissions

Admin staff can be assigned custom permissions or a full moderation profile. `DEVELOPER` remains the super-admin role and is the only role allowed to change staff permissions.
