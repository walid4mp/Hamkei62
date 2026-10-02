# V173 — Messenger Groups Profile & Permissions

- Group profile page styled as a SocialNova profile/cover page.
- Group description supports short text such as: "قصيرة مع حبابي ...".
- Join button supports direct join or request-to-join.
- Pending join requests can be approved/rejected by group owner/admin.
- Group privacy: public/private.
- Group message permission: all members or admins only.
- Group member-add policy: admins only or all members (policy is stored for the group).
- Group management UI is shown only to owner/admin users; backend enforces the same permission.
- Private groups are hidden from the general groups directory unless the current user is already a member.
- Group profile is opened from the groups directory and from shared group cards.
- Group messages remain readable when only admins can speak; non-admin users see a locked composer.
- Fixed a V172 media-picker ordering bug where `isVideo` was read before declaration.
- Added group member and join-request APIs.

Verification:
- `node --check backend/src/server.js`: PASS.
- Flutter/Dart SDK is not installed in this environment, so Flutter analyze/build was not claimed.
- npm dependency installation timed out in the execution environment; backend test suite was therefore not rerun in this turn.
