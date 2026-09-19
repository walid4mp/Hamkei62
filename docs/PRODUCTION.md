# Production checklist

## Required
- PostgreSQL DATABASE_URL
- Strong JWT_SECRET
- HTTPS APP_URL
- Durable media storage is required. The backend now uses Cloudinary in production for images, videos, and audio; Render's local filesystem is only a development fallback.
- Set `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` in Render before uploading production media.
- For real multi-user Live video/audio, configure a WebRTC/SFU service such as LiveKit and add its server credentials. The included Socket.IO layer provides presence/signaling hooks but is not itself a media server.
- Firebase Cloud Messaging can be added for background push notifications; never ship service-account keys in the APK.

## Google Play
- Create a Play Console app named SocialNova.
- Replace launcher icon assets with final 512/1024 marketing artwork if desired.
- Set package/applicationId permanently before first production upload.
- Configure privacy policy, content rating, data safety, account deletion flow, moderation/reporting, and terms.
- Build an AAB for Play production: `flutter build appbundle --release`.
