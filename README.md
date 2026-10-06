# DOTI Public MVP

GitHub-ready static web MVP for DOTI. Includes the supplied DOTI logo, customer and waste-collector registration, central Supabase database, pickup requests, browser GPS capture, Doti Points demo records, utility/mobile-money payment options, collector jobs and an admin dashboard.

## Setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase SQL Editor.
3. Open `index.html` and replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_PUBLISHABLE_KEY` with your Supabase Project URL and Publishable/anon key. Never put a service-role/secret key in the browser.
4. Create a GitHub repository and upload `index.html`, `assets/`, and `supabase/`.
5. Enable GitHub Pages from the repository's Settings > Pages. The deployed site must use HTTPS for browser GPS.
6. Register your own account, then promote it to admin in Supabase SQL: `update public.profiles set role='admin' where id='YOUR-AUTH-USER-UUID';`

## GPS
The MVP uses the browser Geolocation API and stores latitude/longitude with a pickup request. Production should add maps, route optimization, address validation and location privacy/consent.

## Mobile money and utility payments
The UI supports DOTI Points, MTN Mobile Money, Airtel Money and Zamtel Money as payment methods and creates a `payment_intents` record. It does **not** move real money yet. Live payments require approved merchant accounts, provider APIs, secure server-side credentials, callbacks/webhooks and transaction reconciliation. Utility bill payments similarly require approved utility/payment-aggregator integrations.

## Recommended production additions
KYC for collectors; secure points ledger; admin controls; real-time dispatch; SMS/WhatsApp/push notifications; maps; payment gateway adapters; utility APIs; audit logs; privacy policy/terms; monitoring and backups.
