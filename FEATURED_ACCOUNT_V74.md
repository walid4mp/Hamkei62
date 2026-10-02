# SocialNova V74 — Admin Featured Account

- Added admin control: `⭐ إبراز الحساب` / `إلغاء الإبراز`.
- Admin can set a featured priority from 0 to 10000.
- Enabling featured mode makes the account publicly discoverable (`isPrivate=false`, `hideFromSearch=false`, `hideFromSuggestions=false`) so the promotion requested by the administrator is actually visible to all users.
- Featured accounts are prioritized in:
  - global home feed public posts
  - global Reels
  - Stories
  - live rooms
  - suggested users
- Reels still count views only when a real user opens/views them. No fake views or fake followers are generated.
- Admin action is written to Audit Log as `ACCOUNT_FEATURED` / `ACCOUNT_UNFEATURED`.
- Existing per-Reel `featured` control remains independent.
