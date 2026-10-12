# Supabase setup for project `exwvavqkjrnprbyknoih`

## What is in here
- `migrations/20261012_create_missing_tables.sql`
  — creates the four tables the Flutter code calls that did not exist
  (`user_sticker_packs`, `reels_videos`, `fcm_tokens`, `comments_likes`),
  adds the columns the client reads (`posts.link_share_count`,
  `posts.is_suggested_for_you`, `users.tagline`, `messages.conversation_id`,
  `messages.client_message_id`, `messages.reply_to_*`, etc.),
  opens RLS so anon-read works on public content while writes stay
  owner-scoped via `auth.uid()`, and defines every stored procedure the
  Dart `.rpc(...)` calls reference.
- `migrations/20261012_storage_buckets.sql`
  — creates the `chat-media`, `avatars`, `stories`, `posts` buckets with
  public read; the upload code expects these names.

## How to apply these on Supabase

The schema owner password for direct PostgreSQL connections was not
provided in the conversation. There are two safe paths:

### A. SQL Editor (recommended, no password needed)
1. Open https://supabase.com/dashboard/project/exwvavqkjrnprbyknoih/sql/new
2. Paste `migrations/20261012_create_missing_tables.sql`
3. Run it. Re-paste the storage bucket SQL in a new query.
4. (Optional) verify with:
   ```sql
   select tablename from pg_tables
    where schemaname = 'public'
    order by tablename;
   ```

### B. CLI with a service-role key
If you do have the service-role key locally:
```bash
export SUPABASE_ACCESS_TOKEN=...      # from Account → Tokens
supabase link --project-ref exwvavqkjrnprbyknoih
psql "$(cat supabase/.temp/db-url)" \
  -f supabase/migrations/20261012_create_missing_tables.sql
psql "$(cat supabase/.temp/db-url)" \
  -f supabase/migrations/20261012_storage_buckets.sql
```

## What is intentionally NOT in here
- `sb_secret_…` keys — those are server-only and must not be committed
  or shipped to the Flutter client. They live in GitHub Actions secrets
  (`SUPABASE_SERVICE_ROLE_KEY`, etc.) if a CI job needs them.
- Passwords, JWT secrets, or anything that grants owner / superuser
  access to the Postgres role. The migration runs as the dashboard user.
