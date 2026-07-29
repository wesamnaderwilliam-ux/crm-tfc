-- =========================================================================
-- CREATE PROSPECTS TABLE + RLS POLICIES
-- Execute this in Supabase SQL Editor: https://supabase.com/dashboard
-- =========================================================================

-- 1. Create Prospects Table
create table if not exists public.prospects (
    id uuid default uuid_generate_v4() primary key,
    full_name text not null,
    phone_number text,
    secondary_phone_number text,
    national_id text,
    governorate text,
    job_title text,
    company_name text,
    salary_amount numeric(15,2),
    notes text,
    raw_data jsonb default '{}'::jsonb,
    assigned_to_id text,
    assigned_to_name text,
    status text not null default 'pending' check (status in ('pending', 'contacted', 'converted', 'rejected')),
    is_converted boolean default false,
    converted_client_id text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Enable RLS
alter table public.prospects enable row level security;

-- 3. RLS Policy: Allow ALL authenticated users to SELECT prospects
create policy "prospects_select_all"
on public.prospects for select to authenticated
using (true);

-- 4. RLS Policy: Allow ALL authenticated users to INSERT prospects
create policy "prospects_insert_all"
on public.prospects for insert to authenticated
with check (true);

-- 5. RLS Policy: Allow ALL authenticated users to UPDATE prospects
create policy "prospects_update_all"
on public.prospects for update to authenticated
using (true)
with check (true);

-- 6. RLS Policy: Allow ALL authenticated users to DELETE prospects
create policy "prospects_delete_all"
on public.prospects for delete to authenticated
using (true);

-- 7. Auto-update updated_at trigger
drop trigger if exists trigger_prospects_updated_at on public.prospects;
create trigger trigger_prospects_updated_at
before update on public.prospects
for each row execute procedure public.handle_updated_at();

-- 8. Create Google Sheets Config table (if not exists)
create table if not exists public.google_sheets_config (
    id uuid default uuid_generate_v4() primary key,
    sheet_url text not null default '',
    field_mappings jsonb default '{}'::jsonb,
    auto_sync boolean default false,
    last_synced_at timestamp with time zone
);

alter table public.google_sheets_config enable row level security;

create policy "google_sheets_config_select"
on public.google_sheets_config for select to authenticated
using (true);

create policy "google_sheets_config_insert"
on public.google_sheets_config for insert to authenticated
with check (true);

create policy "google_sheets_config_update"
on public.google_sheets_config for update to authenticated
using (true)
with check (true);
