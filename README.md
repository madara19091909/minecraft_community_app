# Blockverse

Private social platform for a Minecraft community. Flutter + Supabase.

## Setup
1. Create a Supabase project. In the SQL editor run `supabase/migrations/0001_init_core.sql`.
2. Authentication → Providers: keep Email on, **disable "Allow new users to sign up"**.
3. Create users in Authentication → Users. Each gets a `pending` profile; set it up:
   ```sql
   update profiles set status='active',
     role_id=(select id from roles where key='owner')
   where username='your_username';
   ```
4. `cp .env.example env.json`, fill URL + **anon** key, then:
   ```
   flutter create --platforms=android .   # first time only (generates android/)
   flutter pub get
   flutter run --dart-define-from-file=env.json
   ```

## Migrations
Run `supabase/migrations/0001` … `0007` in order in the SQL editor.

## Optional build-time values
`TERMS_URL` and `PRIVACY_URL` (public links to your legal documents) can be added to `env.json`;
they enable the Terms / Privacy rows in Settings → About.

## CI
Add repo secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The workflow builds
APK (+AAB on push to main / manual) and uploads artifacts.
Release signing is not configured yet (debug-signed) — needed before Play Store.

## Security
Never commit `env.json`, keystores or the `service_role` key. All access rules live in RLS.
