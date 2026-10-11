# SocialNova Flutter Web deployment for Render (Docker runtime)
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter config --enable-web
RUN flutter pub get
ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""
ARG ZEGO_APP_ID="0"
ARG ZEGO_APP_SIGN=""
ARG FCM_PROJECT_ID=""
RUN flutter build web --release --base-href / \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
    --dart-define=ZEGO_APP_ID=${ZEGO_APP_ID} \
    --dart-define=ZEGO_APP_SIGN=${ZEGO_APP_SIGN} \
    --dart-define=FCM_PROJECT_ID=${FCM_PROJECT_ID}

FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 10000
CMD ["nginx", "-g", "daemon off;"]
