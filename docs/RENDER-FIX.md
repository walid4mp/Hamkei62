# Render deployment

## If the Render service is configured as Docker
The repository root contains `Dockerfile`, so Render can build it directly.
The Docker image runs the Node/Express backend on port 10000.

Required environment variables:
- DATABASE_URL
- JWT_SECRET
- CORS_ORIGIN (default `*`)
- APP_URL
- ADMIN_EMAILS
- CLOUDINARY_CLOUD_NAME
- CLOUDINARY_API_KEY
- CLOUDINARY_API_SECRET

Optional LiveKit/storage variables are documented in `.env.example`.

## If using Render Native Node
Set Root Directory to `backend`, Build Command to:
`npm install && npx prisma generate && npx prisma db push --accept-data-loss`
Start Command:
`npm start`
Health Check Path:
`/api/health`
