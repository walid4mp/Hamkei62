# Deploy SocialNova V72

1. Push this project to the repository connected to Render.
2. Keep `PRISMA_PUSH=false`. V72 performs additive compatibility checks during startup.
3. Redeploy the `hamkei62` service.
4. Confirm logs show `[SocialNova] API listening on 10000` and no `P2021` for `AuditLog` or `ChatTheme`.
5. Open `/api/health`; it should return JSON containing `"ok":true`.
6. Test Messenger chat background, Digital ID, profile privacy, relationship status, Reels, Stories, and Live from the Android app.
