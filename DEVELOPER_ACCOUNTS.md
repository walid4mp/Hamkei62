# SocialNova developer accounts

The seed creates five administrator/developer accounts. They are intended for local/staging development only.

| Username | Email | Password |
|---|---|---|
| devnova | devnova@socialnova.app | demo1234 |
| devdesign | devdesign@socialnova.app | demo1234 |
| devmedia | devmedia@socialnova.app | demo1234 |
| devsupport | devsupport@socialnova.app | demo1234 |
| devlive | devlive@socialnova.app | demo1234 |

Each developer is seeded with 25 clearly-labelled demo followers. The admin panel can add more **demo followers** to developer accounts. These are synthetic accounts and must not be presented as real users or real engagement in production.

## Database update

The `User.role` field is new. After pulling the update:

```bash
cd backend
npm install
npx prisma generate
npx prisma db push
npm run seed
```

For production, replace the seed password and configure `JWT_SECRET`. Do not use the demo credentials in a public deployment.

## Live / calls

The app now has a polished Live entry flow and chat. Actual camera/microphone broadcasting requires the existing LiveKit server variables in `backend/.env`. The profile/chat call controls intentionally do not fake a connected call: voice/video transport must be connected to a real VoIP/WebRTC provider before production use.
