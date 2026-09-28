# SocialNova Device Ban

Added server-side device bans. Android uses Settings.Secure.ANDROID_ID and the server stores only a salted SHA-256 hash. A banned device is rejected at registration, login, and authenticated API requests. Admins can revoke a device ban.

Limitations: no client-only identifier can guarantee a permanent hardware ban against factory resets, OS changes, spoofing, or modified clients. For stronger enforcement on Google Play, combine this with Play Integrity / device attestation.
