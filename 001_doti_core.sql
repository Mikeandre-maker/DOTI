
-- DOTI production-oriented MVP database
-- Supabase/PostgreSQL
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  role text not null default 'customer'
    check (role in ('customer','collector','admin')),
  collector_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.collector_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  business_name text,
  vehicle_type text,
  registration_number text,
  service_area text,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','approved','rejected','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pickup_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  collector_id uuid references public.profiles(id) on delete set null,
  material text not null,
  location_text text not null,
  latitude double precision,
  longitude double precision,
  pickup_type text not null default 'Instant'
    check (pickup_type in ('Instant','Scheduled')),
  scheduled_for timestamptz,
  status text not null default 'Pending'
    check (status in ('Pending','Accepted','EnRoute','Collected','Completed','Cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  completed_at timestamptz
);

create table if not exists public.waste_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  pickup_id uuid references public.pickup_requests(id) on delete set null,
  material text not null,
  kg numeric(12,2) not null check (kg > 0),
  points_earned integer not null default 0 check (points_earned >= 0),
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.wallet_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  points_balance bigint not null default 0 check (points_balance >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('waste_reward','utility_redemption','adjustment','refund')),
  points integer not null,
  reference_type text,
  reference_id uuid,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  service text not null check (service in ('Electricity','Water','Internet','Airtime','Other')),
  method text not null check (method in ('DOTI Points','MTN Mobile Money','Airtel Money','Zamtel Money')),
  account_reference text not null,
  amount_zmw numeric(12,2) not null check (amount_zmw > 0),
  status text not null default 'Pending'
    check (status in ('Pending','Processing','Paid','Failed','Cancelled')),
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid references public.payment_intents(id) on delete set null,
  provider text not null,
  provider_event_id text,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(provider, provider_event_id)
);

create index if not exists idx_pickups_customer on public.pickup_requests(customer_id);
create index if not exists idx_pickups_collector on public.pickup_requests(collector_id);
create index if not exists idx_pickups_status on public.pickup_requests(status);
create index if not exists idx_waste_user on public.waste_records(user_id);
create index if not exists idx_wallet_tx_user on public.wallet_transactions(user_id);
create index if not exists idx_payments_user on public.payment_intents(user_id);

-- Profile + wallet creation after signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name','DOTI User'),
    coalesce(new.raw_user_meta_data->>'phone',''),
    case when new.raw_user_meta_data->>'role'='collector' then 'collector' else 'customer' end
  );

  insert into public.wallet_accounts(user_id) values(new.id)
  on conflict do nothing;

  if new.raw_user_meta_data->>'role'='collector' then
    insert into public.collector_profiles(user_id)
    values(new.id) on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Keep updated_at current.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists collector_profiles_updated_at on public.collector_profiles;
create trigger collector_profiles_updated_at before update on public.collector_profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists wallet_updated_at on public.wallet_accounts;
create trigger wallet_updated_at before update on public.wallet_accounts
for each row execute procedure public.set_updated_at();

drop trigger if exists payment_updated_at on public.payment_intents;
create trigger payment_updated_at before update on public.payment_intents
for each row execute procedure public.set_updated_at();

-- Prevent clients from changing privileged role/verification fields.
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql as $$
begin
  if old.role <> new.role
     or old.collector_verified <> new.collector_verified then
    raise exception 'Privileged profile fields can only be changed by an administrator';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_privileges on public.profiles;
create trigger protect_profile_privileges
before update on public.profiles
for each row execute procedure public.protect_profile_privileges();

-- RLS.
alter table public.profiles enable row level security;
alter table public.collector_profiles enable row level security;
alter table public.pickup_requests enable row level security;
alter table public.waste_records enable row level security;
alter table public.wallet_accounts enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.payment_intents enable row level security;
alter table public.payment_events enable row level security;

create policy profiles_self_or_admin on public.profiles
for select to authenticated
using (
  auth.uid() = id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy profiles_self_update on public.profiles
for update to authenticated
using (auth.uid()=id)
with check (auth.uid()=id);

create policy collector_profile_self_or_admin on public.collector_profiles
for select to authenticated
using (
  auth.uid()=user_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy pickup_customer_insert on public.pickup_requests
for insert to authenticated
with check (auth.uid()=customer_id);

create policy pickup_participant_read on public.pickup_requests
for select to authenticated
using (
  auth.uid()=customer_id or auth.uid()=collector_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy pickup_collector_update on public.pickup_requests
for update to authenticated
using (
  auth.uid()=collector_id
  or (
    collector_id is null
    and exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='collector' and a.collector_verified=true)
  )
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
)
with check (
  auth.uid()=collector_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy waste_self_read on public.waste_records
for select to authenticated
using (
  auth.uid()=user_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy wallet_self_read on public.wallet_accounts
for select to authenticated
using (
  auth.uid()=user_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy wallet_tx_self_read on public.wallet_transactions
for select to authenticated
using (
  auth.uid()=user_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy payment_self_insert on public.payment_intents
for insert to authenticated
with check (auth.uid()=user_id);

create policy payment_self_read on public.payment_intents
for select to authenticated
using (
  auth.uid()=user_id
  or exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin')
);

create policy payment_events_admin_read on public.payment_events
for select to authenticated
using (exists(select 1 from public.profiles a where a.id=auth.uid() and a.role='admin'));

-- Server-only functions can write wallet/payment state.
revoke all on table public.wallet_accounts from anon, authenticated;
revoke all on table public.wallet_transactions from anon, authenticated;
revoke all on table public.payment_events from anon, authenticated;

-- Example admin promotion after creating your own account:
-- update public.profiles set role='admin' where id='YOUR-USER-UUID';
