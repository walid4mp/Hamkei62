# SocialNova V94 — Final Consolidated Build

This package is based on the repository `main` snapshot supplied by the user (84cd5b89) and contains the V93 feature set already present in that snapshot.

## Consolidated features present
- V93 admin console and protected admin APIs.
- Gift engine with real WebP artwork/preview assets.
- Creator levels, milestones and rewards.
- Nova TV movies/series/seasons/episodes administration.
- Real call records, duration and call history.
- ARB localization pipeline and generated localizations.
- Live gift/join-request flows and related backend schema.
- Existing V90 hardening and prior SocialNova features.

## V94 repair applied in this package
- The login screen no longer performs a blocking server health probe during startup. Render free instances can sleep and take longer to wake, which caused a false "تعذر الوصول إلى الخادم" banner even though the login request itself already has retries.
- The explicit "إعادة المحاولة" action still performs the server health check.
- Backend JavaScript syntax, project JSON files, Python tooling syntax, and presence of the V93 feature files were statically checked in this environment.

## Production requirements
- Render must have a persistent `JWT_SECRET` set. The current service log showed it was missing, so the backend generated an ephemeral secret on boot.
- `DATABASE_URL` must point to the production PostgreSQL database.
- Admin login variables (`ADMIN_LOGIN_EMAIL` / `ADMIN_LOGIN_PASSWORD`) must be configured if the dedicated admin login is desired.
- LiveKit, storage/Cloudinary, FCM and Google Play verification remain dependent on their corresponding production credentials.
