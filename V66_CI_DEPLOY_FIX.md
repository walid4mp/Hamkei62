# V66 CI / Render fixes

1. Rewrote the dense Groups and Live Flutter build methods using explicit widget
   lists to remove the parser errors reported at social.dart lines 1165, 1166,
   1377, 1385 and nearby tokens.
2. GitHub Actions backend now uses `npm install --ignore-scripts` because the
   checked-in lockfile is out of sync with package.json. This avoids the
   `npm ci` EUSAGE failure while the lockfile is regenerated.
3. Docker/Render no longer runs a destructive Prisma `db push` automatically.
   It is opt-in with `PRISMA_PUSH=true`. This prevents production data loss.
4. The Render log showed existing data in columns/tables Prisma wanted to drop;
   accepting data loss blindly would delete those values. A proper migration or
   schema reconciliation should be performed before enabling PRISMA_PUSH.
