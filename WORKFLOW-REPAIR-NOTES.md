# SocialNova — workflow repair bundle

This archive is based on the `Social-Media-App-main (1).zip` source archive available in the conversation and contains workflow repairs:

- Pins the release workflow to Flutter 3.44.3 to match the CI workflow and current dependency requirements.
- Adds a manual GitHub Actions workflow to run `dart format .` and commit formatting-only changes to `main`.
- Fixes the Supabase keep-alive URL construction so it no longer depends on an empty `SUPABASE_FUNCTIONS_URL` secret and fails clearly on HTTP errors.

## Before using
1. Review `.github/workflows/format-dart.yml` and run it from GitHub Actions → Format Dart files → Run workflow. The workflow needs repository `contents: write` permission and branch protection must allow the bot to push.
2. Add `SUPABASE_ANON_KEY` under Settings → Secrets and variables → Actions. Never put the key directly in this file.
3. The Supabase Edge Function `keep-alive` must already exist and be deployed. If it does not, this workflow will report an HTTP error; the workflow cannot create a server function by itself.
4. This is not a claim that the entire Flutter application builds or that Supabase-backed screens are fixed. CI must be rerun after formatting; analyzer, tests, signing secrets, and the reported app 404s require their own verification.
