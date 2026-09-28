FROM node:20-bookworm-slim

WORKDIR /app

# Prisma requires OpenSSL in the runtime/build image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install backend dependencies first, then copy the Prisma schema before generate.
COPY backend/package.json ./package.json
COPY backend/package-lock.json* ./
RUN npm install --omit=dev

COPY backend/prisma ./prisma
RUN npx prisma@5.22.0 generate --schema=./prisma/schema.prisma

COPY backend/src ./src

ENV NODE_ENV=production
ENV PORT=10000
EXPOSE 10000

# Production startup is migration-safe: server.js performs only additive compatibility
# checks. Never run prisma db push automatically because it can drop live columns.
CMD ["node", "src/server.js"]
