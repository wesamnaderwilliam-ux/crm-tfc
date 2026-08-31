-- =========================================================================
-- THE FUTURE CLUB (TFC) CRM - DISTRIBUTION TABLES
-- Execute this script in your Supabase SQL Editor (https://supabase.com)
-- =========================================================================

-- 1. Create distribution_entries table
create table if not exists public.distribution_entries (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete cascade not null,
    program_id uuid references public.core_programs(id) on delete cascade not null,
    bank_id uuid references public.banks(id) on delete cascade not null,
    employee_id uuid references public.bank_employees(id) on delete set null,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'closed')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique (client_id, program_id, bank_id)
);

-- 2. Add trigger for updated_at to automate modification date
drop trigger if exists trigger_distribution_entries_updated_at on public.distribution_entries;
create trigger trigger_distribution_entries_updated_at
before update on public.distribution_entries
for each row execute procedure public.handle_updated_at();

-- 3. Enable Row Level Security (RLS)
alter table public.distribution_entries enable row level security;

-- 4. RLS Policies

-- Allow select for authenticated users who have access to the associated client
drop policy if exists "Distribution select" on public.distribution_entries;
create policy "Distribution select" 
on public.distribution_entries for select to authenticated 
using (exists (select 1 from public.clients where id = client_id));

-- Allow insert for admin and manager only
drop policy if exists "Distribution insert" on public.distribution_entries;
create policy "Distribution insert" 
on public.distribution_entries for insert to authenticated 
with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    and exists (select 1 from public.clients where id = client_id)
);

-- Allow update for admin and manager only
drop policy if exists "Distribution update" on public.distribution_entries;
create policy "Distribution update" 
on public.distribution_entries for update to authenticated 
using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
)
with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);

-- Allow delete for admin and manager only
drop policy if exists "Distribution delete" on public.distribution_entries;
create policy "Distribution delete" 
on public.distribution_entries for delete to authenticated 
using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
