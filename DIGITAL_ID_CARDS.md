# SocialNova Digital ID Cards

v28 adds a server-backed digital identity card.

- Personal QR uses `socialnova://profile/<userId>`.
- Verification badge reflects the existing account verification state; the card does not claim government/official identity verification automatically.
- Name, location, followers, posts, stories and store activity are read from the account and cannot be edited from the card.
- Card theme, shape, visibility and optional displayed counters are user preferences.
- Card can be shared as a PNG from the app.
- Backend endpoint: `GET /api/me/digital-card`.
- User preference fields are stored on `User` and updated through `PATCH /api/me`.

- The card can optionally show gender and full birth date; both are off by default and controlled by the user.
- The user can choose one of their groups to display on the card.
- Backend endpoint `GET /api/me/groups` supplies only groups the current user belongs to.
