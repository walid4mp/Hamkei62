# SocialNova V82 — Admin Profile Control

## Added
- Admin-only profile-open effects: GOLDEN_AURA, NEON_PORTAL, HEART_BURST, SPARKLES.
- Optional short HTTPS video shown when opening a profile.
- Duration control (1–15 seconds).
- Normal users cannot set or overwrite the protected `profileOpen*` fields through `/api/me`.
- Developer/admin audit trail for profile-effect changes.
- Delegated profile management with per-target permissions.
- Supported delegated actions: verification, ban/unban, feature/unfeature, NovaCoin adjustment, special features, and creator subscription grants.
- Assignment storage is additive and created safely at startup without dropping existing data.
- Profile UI exposes delegated controls only to an authorized manager for the assigned target.
- Existing profile customization, frames, animated backgrounds, music, pinned posts/reels, achievements and team display remain intact.
- CI/Render backend installation changed from `npm ci` to `npm install --no-audit --no-fund` because the repository lockfile was out of sync with the LiveKit/Multer dependencies; this allows the build environment to resolve the declared dependency graph.

## Security
- Profile effects are not user-editable through the normal profile endpoint.
- Delegated access is scoped to an explicit target user and explicit action permissions.
- Developer accounts retain full access.
- Admin actions are recorded in AuditLog.
