# SocialNova V75 — Explore Global Search

Added a real authenticated `/api/search?q=` endpoint and connected the Flutter Explore/Search page to it.

Search results are grouped into:
- Users
- Reels / videos
- Public posts
- Public groups
- Live rooms
- Active public stories

Privacy rules:
- Users with `hideFromSearch` or banned users are excluded.
- Private users are excluded from public content discovery.
- Posts must be PUBLIC and not archived.
- Groups must be PUBLIC.
- Live rooms must be LIVE and hosted by a non-banned, non-private account.
- Stories must be active, not archived, and `EVERYONE` audience.
- Featured accounts are prioritized, but no fake views/followers are created.

Flutter navigation opens the real profile, reel, post, group, live room, or story viewer.
