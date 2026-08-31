-- =========================================================================
-- FIX & UPGRADE PROSPECTS TABLE AND RLS POLICIES (SAFE VERSION)
-- Execute this complete script in Supabase SQL Editor: https://supabase.com/dashboard
-- =========================================================================

-- 1. Enable extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- 2. Drop the foreign key constraints first if they exist
alter table if exists public.prospects 
    drop constraint if exists prospects_assigned_to_id_fkey,
    drop constraint if exists prospects_converted_client_id_fkey;

-- 3. Create or Update Prospects Table
create table if not exists public.prospects (
    id uuid default gen_random_uuid() primary key,
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
    status text not null default 'pending',
    is_converted boolean default false,
    converted_client_id text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Alter columns to TEXT safely
do $$
begin
    -- Change assigned_to_id type to text
    if exists (
        select 1 
        from information_schema.columns 
        where table_schema = 'public' 
          and table_name = 'prospects' 
          and column_name = 'assigned_to_id' 
          and data_type != 'text'
    ) then
        alter table public.prospects alter column assigned_to_id type text using assigned_to_id::text;
    end if;

    -- Change converted_client_id type to text
    if exists (
        select 1 
        from information_schema.columns 
        where table_schema = 'public' 
          and table_name = 'prospects' 
          and column_name = 'converted_client_id' 
          and data_type != 'text'
    ) then
        alter table public.prospects alter column converted_client_id type text using converted_client_id::text;
    end if;

    -- Ensure all columns exist
    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'secondary_phone_number') then
        alter table public.prospects add column secondary_phone_number text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'national_id') then
        alter table public.prospects add column national_id text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'governorate') then
        alter table public.prospects add column governorate text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'job_title') then
        alter table public.prospects add column job_title text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'company_name') then
        alter table public.prospects add column company_name text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'salary_amount') then
        alter table public.prospects add column salary_amount numeric(15,2);
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'notes') then
        alter table public.prospects add column notes text;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'raw_data') then
        alter table public.prospects add column raw_data jsonb default '{}'::jsonb;
    end if;

    if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'prospects' and column_name = 'is_converted') then
        alter table public.prospects add column is_converted boolean default false;
    end if;
end $$;

-- 5. Enable RLS
alter table public.prospects enable row level security;

-- 6. Drop old restrictive policies
drop policy if exists "prospects_select_all" on public.prospects;
drop policy if exists "prospects_insert_all" on public.prospects;
drop policy if exists "prospects_update_all" on public.prospects;
drop policy if exists "prospects_delete_all" on public.prospects;
drop policy if exists "Allow authenticated read prospects" on public.prospects;
drop policy if exists "Allow authenticated insert prospects" on public.prospects;
drop policy if exists "Allow authenticated update prospects" on public.prospects;
drop policy if exists "Allow authenticated delete prospects" on public.prospects;
drop policy if exists "Allow all read prospects" on public.prospects;
drop policy if exists "Allow all insert prospects" on public.prospects;
drop policy if exists "Allow all update prospects" on public.prospects;
drop policy if exists "Allow all delete prospects" on public.prospects;

-- 7. Create Open Policies (SELECT, INSERT, UPDATE, DELETE)
create policy "Allow all read prospects"
on public.prospects for select
using (true);

create policy "Allow all insert prospects"
on public.prospects for insert
with check (true);

create policy "Allow all update prospects"
on public.prospects for update
using (true)
with check (true);

create policy "Allow all delete prospects"
on public.prospects for delete
using (true);

-- 8. Google Sheets Config Table & Policies
create table if not exists public.google_sheets_config (
    id uuid default gen_random_uuid() primary key,
    sheet_url text not null default '',
    field_mappings jsonb default '{}'::jsonb,
    auto_sync boolean default false,
    last_synced_at timestamp with time zone,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.google_sheets_config enable row level security;

drop policy if exists "google_sheets_config_select" on public.google_sheets_config;
drop policy if exists "google_sheets_config_insert" on public.google_sheets_config;
drop policy if exists "google_sheets_config_update" on public.google_sheets_config;
drop policy if exists "Allow all read google_sheets_config" on public.google_sheets_config;
drop policy if exists "Allow all insert google_sheets_config" on public.google_sheets_config;
drop policy if exists "Allow all update google_sheets_config" on public.google_sheets_config;

create policy "Allow all read google_sheets_config"
on public.google_sheets_config for select
using (true);

create policy "Allow all insert google_sheets_config"
on public.google_sheets_config for insert
with check (true);

create policy "Allow all update google_sheets_config"
on public.google_sheets_config for update
using (true)
with check (true);
