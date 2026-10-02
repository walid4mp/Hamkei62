# SocialNova V73 — Conversation Review Fix

- Changed admin conversation review from requiring two manually selected users to a two-step flow:
  1. Search and select one user.
  2. Load all users that person has exchanged private messages with.
  3. Select a conversation to open its messages.
- Added `GET /api/admin/conversations/user/:userId` for the conversation list.
- Hardened conversation message filtering so deleted-message flags no longer cause the review query to fail.
- Audit logging is attempted but cannot turn a valid conversation review into HTTP 500 if an older production database temporarily lacks `AuditLog`.
- Verified `server.js` and `seed.js` syntax with Node.
