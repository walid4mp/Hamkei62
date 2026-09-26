# SocialNova Live — LiveKit setup

The mobile app now uses `livekit_client` for real-time camera/microphone/video and Android screen sharing.

## Server variables

Set these variables on the backend:

- `LIVEKIT_URL` — LiveKit WebSocket URL (`wss://...`)
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

The existing endpoint `/api/live/token` creates a short-lived room token for the authenticated user.

## Android screen sharing

The app requests MediaProjection permission before enabling screen share and starts an Android foreground service with `mediaProjection` type. The user must approve the system capture dialog.

## Production checklist

1. Deploy the Node/Prisma backend and verify `GET /api/health` returns `{ "ok": true }`.
2. Configure the three LiveKit environment variables.
3. Build the Flutter app with `--dart-define=API_URL=https://YOUR-API-HOST`.
4. Test camera, microphone, viewer join/leave, comments, and screen sharing on a physical Android device.
5. For iOS full-device screen sharing, add a ReplayKit Broadcast Extension; Android uses MediaProjection.
