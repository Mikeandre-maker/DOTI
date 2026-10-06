# DOTI — GitHub + Supabase Backend MVP

This repository is the backend foundation for DOTI.

## What is included

- PostgreSQL/Supabase database schema
- Supabase Auth profile trigger
- Customer and collector roles
- Collector verification status
- Pickup requests with GPS latitude/longitude
- Waste records
- Doti Points wallet
- Immutable-style wallet transaction table
- Utility/mobile-money payment intents
- Payment event/audit table
- Row Level Security policies
- Supabase Edge Function structure for payments and pickup completion
- DOTI logo in `assets/doti-logo.jpg`

## Important: I cannot create the cloud account for you

The database is fully defined in `supabase/migrations/001_doti_core.sql`, but it must be run inside a Supabase project that you own. I cannot create an external Supabase account or obtain your merchant credentials from this chat.

Supabase provides a full Postgres database and Auth, and recommends Row Level Security for tables exposed to the client. See the official documentation:
https://supabase.com/docs/guides/database/overview
https://supabase.com/docs/guides/database/postgres/row-level-security

## Setup

### 1. Create Supabase project
Create a project at https://supabase.com/

### 2. Create the database
Open SQL Editor and run:
`supabase/migrations/001_doti_core.sql`

Then optionally run:
`supabase/seed.sql`

### 3. Create your DOTI admin
Register your account through the app, then find your UUID under Supabase Authentication > Users.

Run:
`update public.profiles set role='admin' where id='YOUR-USER-UUID';`

### 4. Configure the frontend
Use your Supabase project URL and publishable key in the frontend configuration.

Never put the service-role/secret key in frontend code.

### 5. Deploy Edge Functions
Install the Supabase CLI, then:
`supabase init`
`supabase functions deploy create-payment-intent`
`supabase functions deploy payment-webhook`
`supabase functions deploy collector-complete-pickup`

Supabase Edge Functions are intended for server-side logic, webhooks and third-party integrations.

## Mobile money

The backend is ready for provider adapters for:
- MTN Mobile Money
- Airtel Money
- Zamtel Money

However, live payment processing cannot be activated by code alone. DOTI needs approved merchant/API access from each provider, and the provider credentials must be stored as server-side secrets.

Recommended flow:

User
→ DOTI
→ create-payment-intent Edge Function
→ MTN/Airtel/Zamtel API
→ provider callback/webhook
→ payment-webhook Edge Function
→ payment_intents status = Paid
→ receipt/notification

Never trust the browser to declare a payment successful.

## GPS

The frontend can collect browser GPS coordinates after permission is granted. For production, use HTTPS. The backend stores latitude/longitude with the pickup request.

Next production upgrade:
- interactive map
- collector proximity search
- route optimization
- live dispatch
- geofencing
- pickup proof/photo
- collector KYC

## Doti Points

The database separates:
- wallet balance
- wallet transactions
- waste records

For production, points should be credited/debited only through server-side/database functions, not by directly trusting browser calculations.

## Production security

Before accepting real money:
- verify collectors
- add rate limits
- add audit logs
- verify mobile-money webhooks
- implement atomic wallet transactions
- add consent/privacy/terms
- protect admin actions
- add backups/monitoring
