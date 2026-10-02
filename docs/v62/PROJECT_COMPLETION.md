# SocialNova V62 — Project Baseline

This package is built directly from the original `Hamkei62-SocialNova-v7.zip`.
All original files are preserved; new files are additive.

## Feature scope
The requested product scope is recorded in `backend-seed/v62_feature_manifest.json`.
The existing V7 application already contains production code for several social,
media, messenger, wallet, group, story and live foundations. New modules are
kept isolated so they can be wired to the existing APIs without replacing them.

## Important verification boundary
A complete source archive is not the same thing as a production-ready release.
Flutter/Dart SDK and a configured runtime are required to prove `flutter analyze`
and `flutter build apk --release`. Database migrations, secrets, payment provider
configuration, Google Play products, Firebase, LiveKit and ad-network accounts
must also be configured before those integrations can operate in production.
