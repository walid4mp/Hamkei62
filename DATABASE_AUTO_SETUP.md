# Automatic database setup

The backend now creates the complete Prisma schema automatically when it starts against a **brand-new PostgreSQL database**.

## What happens

1. `backend/src/bootstrap-db.js` checks whether the PostgreSQL `User` table exists.
2. If the database is empty, it runs `prisma db push --skip-generate --accept-data-loss` **once** to create all 82 Prisma models/tables from `backend/prisma/schema.prisma`.
3. `backend/src/server.js` then applies additive compatibility tables/columns required by older SocialNova releases (channels, app releases, admin assignments, device controls, creator catalog, calls, etc.).
4. `seed.js` runs idempotently after the schema exists.
5. On an existing database, the bootstrap does **not** run a destructive reset or drop data; the compatibility layer only adds missing structures.

## Required backend variable

```text
DATABASE_URL=postgresql://...
```

The same PostgreSQL database can be used by Render or another PostgreSQL provider. Do not put a PostgreSQL service-role password in the Flutter application.

## Prisma validation

From `backend/`:

```bash
npm ci
npx prisma validate
node src/bootstrap-db.js
npm test
```

## Supabase note

The Flutter application also has direct Supabase integrations for some legacy/mobile features. Those are separate from the Prisma/Render database. The application constants list the required Supabase tables/RPCs; a new Supabase project still needs its own SQL migrations or equivalent schema before those direct queries can work.
