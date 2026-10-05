# SocialNova — Unified Edition

This package combines the Social-Media application codebase with the SocialNova hosting/backend stack.

## Included
- Flutter social application from Social-Media-App (feed, stories, reels, comments, profiles, discovery, connections, blocked users, 1:1 and group chat, attachments, voice notes, reactions, stickers, link previews, chat search, calls, AI chat, AI writing/summarization, notifications, themes, biometric security/2FA controls, offline cache).
- SocialNova backend (Node.js/Express + Prisma/PostgreSQL), admin panel, backend seed and deployment assets.
- SocialNova Unity gifts integration assets and documentation.
- Android/iOS/web/desktop Flutter targets from the application project.

## Identity
The product name is **SocialNova**. The Flutter package name is `socialnova`.

## Architecture
The Flutter client retains the Social-Media application's Supabase/Realtime data layer so its existing feature modules remain intact. The included SocialNova backend is the hosting/API/admin layer and preserves the SocialNova PostgreSQL/Prisma schema and deployment setup.

Important: the two data layers are intentionally kept separate in this merge. Converting every existing Supabase repository to the SocialNova REST/Prisma API would be a separate data-migration project and cannot be safely achieved by copying files alone.

## Build
1. Install Flutter/Dart compatible with the project's `pubspec.yaml`.
2. Run `flutter pub get`.
3. Configure the existing Supabase/Firebase values required by the Flutter app.
4. For the backend, configure `backend/.env` from `backend/.env.example`, install dependencies and run its documented start command.
5. Never commit production secrets.

## Branding
App display name: SocialNova.
