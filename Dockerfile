# SocialNova / Hamkei62 — Flutter Web on Render (Docker runtime)
# Flutter version is pinned to 3.44.3 to match .github/workflows/ci.yml.
# The official Flutter SDK tarball is used because the previously pinned
# registry tag ghcr.io/cirruslabs/flutter:3.47.7 does NOT exist (404), which
# made every Docker build fail with "Exited with status 1".
FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git ca-certificates unzip xz-utils && rm -rf /var/lib/apt/lists/*
ENV FLUTTER_HOME=/opt/flutter
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.3-stable.tar.xz -o /tmp/f.tar.xz \
 && mkdir -p /opt && tar -xJf /tmp/f.tar.xz -C /opt && rm -f /tmp/f.tar.xz
ENV PATH="/opt/flutter/bin:${PATH}"
RUN git config --global --add safe.directory /opt/flutter \
 && flutter --version && flutter config --enable-web && flutter precache --web
WORKDIR /app
COPY . .
RUN flutter pub get

# These are the PUBLIC Supabase client values (publishable / anon key). They are
# compiled into the web bundle by design — safe to embed, and protected by RLS.
# Render overrides them via its env vars, which are passed as build args.
ARG SUPABASE_URL="https://exwvavqkjrnprbyknoih.supabase.co"
ARG SUPABASE_ANON_KEY="sb_publishable_oSOSFX6pWahlttNUbXHIBg_6irKUXcP"
ARG ZEGO_APP_ID="0"
ARG ZEGO_APP_SIGN=""
ARG FCM_PROJECT_ID=""
ARG GIPHY_API_KEY=""
RUN flutter build web --release --base-href / \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
    --dart-define=ZEGO_APP_ID=${ZEGO_APP_ID} \
    --dart-define=ZEGO_APP_SIGN=${ZEGO_APP_SIGN} \
    --dart-define=FCM_PROJECT_ID=${FCM_PROJECT_ID} \
    --dart-define=GIPHY_API_KEY=${GIPHY_API_KEY}

FROM nginx:1.27-alpine AS runtime
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 10000
CMD ["nginx", "-g", "daemon off;"]
