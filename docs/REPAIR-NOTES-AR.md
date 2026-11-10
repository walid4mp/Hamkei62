# SocialPlus repair notes (2026-11-10)

## What was changed
- Removed hard-coded demo conversations from the chat list. It now displays only conversations belonging to the signed-in user.
- Fixed ChatRoomScreen to read `route.params` from React Navigation instead of guessing the active route from navigation state.
- Added user lookup from the chat screen and a real direct-conversation creation RPC.
- Added group creation through a database RPC.
- Made search results open the selected user's profile.
- Made post authors in the feed open their profiles.
- Added a comments screen and connected the feed comment action to it.
- Added migration `00007_messaging_repair.sql` to provide participant-scoped conversation policies and conversation creation functions.

## Required Supabase step
Before testing messaging, open Supabase Dashboard → SQL Editor and run the complete file:

`supabase/migrations/00007_messaging_repair.sql`

Run the previous migrations `00001` through `00006` first if they have not already been applied. Do not run this migration against a different Supabase project than the one configured in the app.

## Required app configuration
Set the actual project values in `.env` (or your EAS/CI environment):
- `EXPO_PUBLIC_SUPABASE_URL`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY`

Use the project's public anon/publishable key only. Never put a `service_role` key in the mobile app or commit it to GitHub.

## Build
```bash
npm ci
npx expo-doctor
npx tsc --noEmit
npx expo prebuild --platform android
cd android
./gradlew assembleRelease
```

## Important verification limits
The archive was inspected and patched, but a full dependency install/build could not be completed in this environment (the `npm ci` attempt timed out). The app has not been connected to your live Supabase project or tested on a physical phone. The migration must be applied and the app must be tested with two separate accounts to verify direct messages, group creation, group membership, comments, search and profile navigation. Video calling/live video still require their own RTC provider credentials.
