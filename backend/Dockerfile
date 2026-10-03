FROM node:22-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY prisma ./prisma
RUN npx prisma generate
COPY src ./src
ENV NODE_ENV=production
EXPOSE 4000
CMD ["npm","start"]
