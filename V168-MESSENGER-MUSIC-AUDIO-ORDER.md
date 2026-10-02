# SocialNova V168 — Messenger order + in-app audio

## Changes
- Conversations are explicitly sorted by the timestamp of their latest message on the backend.
- Flutter inbox defensively sorts again by `lastMessage.createdAt`, so the latest person you talked to is always first.
- Voice messages continue to use the in-app `just_audio` player with play/pause/progress and never require leaving SocialNova.
- Profile songs uploaded from the phone are stored as direct audio URLs and play inside SocialNova with the same audio player.
- Spotify/Apple Music/Deezer page URLs are not raw audio streams; those links are opened by the corresponding external app/browser because SocialNova cannot directly decode a provider webpage URL as an audio file.
