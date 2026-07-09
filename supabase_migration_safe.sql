-- =========================================================================
-- TFC CRM - SAFE MIGRATION SCRIPT v2
-- Handles existing tables with missing/different columns.
-- Run this in Supabase SQL Editor.
-- =========================================================================

-- Enable UUID generation extension
create extension if not exists "uuid-ossp";

-- =========================================================================
-- STEP 1: ENSURE ALL TABLES EXIST (minimal structure)
-- =========================================================================

create table if not exists public.roles_permissions (role text primary key);
create table if not exists public.profiles (id uuid primary key);
create table if not exists public.clients (id uuid default uuid_generate_v4() primary key);

-- =========================================================================
-- STEP 2: ADD ALL MISSING COLUMNS TO EACH TABLE
-- =========================================================================

-- roles_permissions columns
alter table public.roles_permissions add column if not exists can_view_clients boolean default false;
alter table public.roles_permissions add column if not exists can_edit_clients boolean default false;
alter table public.roles_permissions add column if not exists can_delete_clients boolean default false;
alter table public.roles_permissions add column if not exists can_approve_loans boolean default false;
alter table public.roles_permissions add column if not exists can_view_analytics boolean default false;
alter table public.roles_permissions add column if not exists can_manage_roles boolean default false;
alter table public.roles_permissions add column if not exists field_visibility jsonb default '{}'::jsonb;

-- profiles columns
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists role text default 'company_employee';
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists password text;
alter table public.profiles add column if not exists confirm_password text;
alter table public.profiles add column if not exists phone_number text;
alter table public.profiles add column if not exists national_id text;
alter table public.profiles add column if not exists hiring_date date;
alter table public.profiles add column if not exists is_confirmed boolean default false;
alter table public.profiles add column if not exists manager_id uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists employee_status text default 'active';
alter table public.profiles add column if not exists created_at timestamptz default now();

-- Add check constraint for employee_status if not exists
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'profiles_employee_status_check') then
        alter table public.profiles add constraint profiles_employee_status_check check (employee_status in ('active', 'on_leave', 'terminated'));
    end if;
exception when others then null;
end $$;

-- clients columns - handle rename from 'name' to 'full_name' if needed
do $$
begin
    -- If 'name' column exists but 'full_name' doesn't, rename it
    if exists (select 1 from information_schema.columns where table_schema='public' and table_name='clients' and column_name='name')
       and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='clients' and column_name='full_name')
    then
        alter table public.clients rename column name to full_name;
    end if;
end $$;

alter table public.clients add column if not exists full_name text;
alter table public.clients add column if not exists phone_number text;
alter table public.clients add column if not exists secondary_phone_number text;
alter table public.clients add column if not exists national_id text;
alter table public.clients add column if not exists birth_date date;
alter table public.clients add column if not exists employment_type text;
alter table public.clients add column if not exists company_name text;
alter table public.clients add column if not exists job_title text;
alter table public.clients add column if not exists is_insured boolean default false;
alter table public.clients add column if not exists salary_transfer_method text;
alter table public.clients add column if not exists salary_bank_details jsonb default '[]'::jsonb;
alter table public.clients add column if not exists cash_salary_amount numeric(15,2);
alter table public.clients add column if not exists credit_score integer default 600;
alter table public.clients add column if not exists requested_amount numeric(15,2) default 0.0;
alter table public.clients add column if not exists governorate text;
alter table public.clients add column if not exists representative_name text;
alter table public.clients add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.clients add column if not exists status text default 'pending';
alter table public.clients add column if not exists created_at timestamptz default now();
alter table public.clients add column if not exists updated_at timestamptz default now();

-- Ensure national_id column is nullable (optional)
alter table public.clients alter column national_id drop not null;

-- Add unique constraint on national_id if not exists
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'clients_national_id_key') then
        alter table public.clients add constraint clients_national_id_key unique (national_id);
    end if;
exception when others then
    null; -- skip if constraint already exists with different name
end $$;

-- =========================================================================
-- STEP 3: CREATE RELATED TABLES (the ones causing the join error)
-- =========================================================================

-- Existing Loans
create table if not exists public.existing_loans (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid not null,
    bank_name text not null,
    installment_value numeric(12,2) not null default 0.0,
    notes text
);

-- Add FK if not exists
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'existing_loans_client_id_fkey') then
        alter table public.existing_loans 
            add constraint existing_loans_client_id_fkey 
            foreign key (client_id) references public.clients(id) on delete cascade;
    end if;
exception when others then null;
end $$;

-- Credit Cards & Requests
create table if not exists public.credit_cards_requests (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid not null,
    bank_name text not null,
    value numeric(12,2) not null default 0.0,
    type text not null default 'card',
    duration text,
    installment numeric(12,2) not null default 0.0,
    highest_value numeric(12,2) not null default 0.0,
    notes text
);

-- Add five_percent_calc generated column if not exists
do $$
begin
    if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='credit_cards_requests' and column_name='five_percent_calc') then
        alter table public.credit_cards_requests 
            add column five_percent_calc numeric(12,2) generated always as (value * 0.05) stored;
    end if;
exception when others then null;
end $$;

-- Add FK if not exists
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'credit_cards_requests_client_id_fkey') then
        alter table public.credit_cards_requests 
            add constraint credit_cards_requests_client_id_fkey 
            foreign key (client_id) references public.clients(id) on delete cascade;
    end if;
exception when others then null;
end $$;

-- Interaction History
create table if not exists public.interaction_history (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid not null,
    action_type text not null,
    notes text not null default '',
    created_by uuid,
    created_by_name text,
    created_at timestamptz default now()
);

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'interaction_history_client_id_fkey') then
        alter table public.interaction_history 
            add constraint interaction_history_client_id_fkey 
            foreign key (client_id) references public.clients(id) on delete cascade;
    end if;
exception when others then null;
end $$;

-- Documents
create table if not exists public.documents (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid not null,
    document_name text not null,
    document_url text not null,
    status text not null default 'pending',
    created_at timestamptz default now()
);

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'documents_client_id_fkey') then
        alter table public.documents 
            add constraint documents_client_id_fkey 
            foreign key (client_id) references public.clients(id) on delete cascade;
    end if;
exception when others then null;
end $$;

-- =========================================================================
-- STEP 4: TRIGGERS
-- =========================================================================

create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_clients_updated_at on public.clients;
create trigger trigger_clients_updated_at
before update on public.clients
for each row execute procedure public.handle_updated_at();

create or replace function public.handle_new_user()
returns trigger as $$
declare
    user_role text;
begin
    user_role := coalesce(new.raw_user_meta_data->>'role', 'company_employee');
    
    -- Enforce admin role strictly for a specific email
    if lower(new.email) = 'wezonader@gmail.com' then
        user_role := 'admin';
    elsif user_role = 'admin' then
        user_role := 'manager'; -- Downgrade unauthorized admins
    end if;

    insert into public.profiles (
        id, 
        full_name, 
        role, 
        email, 
        password, 
        confirm_password,
        phone_number,
        national_id,
        hiring_date,
        is_confirmed
    )
    values (
        new.id, 
        coalesce(new.raw_user_meta_data->>'full_name', 'مستخدم جديد'), 
        user_role,
        new.email,
        new.raw_user_meta_data->>'password',
        new.raw_user_meta_data->>'confirm_password',
        new.raw_user_meta_data->>'phone_number',
        new.raw_user_meta_data->>'national_id',
        case 
            when new.raw_user_meta_data->>'hiring_date' is not null and new.raw_user_meta_data->>'hiring_date' <> '' then (new.raw_user_meta_data->>'hiring_date')::date
            else null
        end,
        (user_role = 'admin') -- admin is automatically confirmed
    )
    on conflict (id) do update set
        password = excluded.password,
        confirm_password = excluded.confirm_password,
        email = excluded.email,
        full_name = excluded.full_name,
        role = excluded.role,
        phone_number = excluded.phone_number,
        national_id = excluded.national_id,
        hiring_date = excluded.hiring_date,
        is_confirmed = excluded.is_confirmed;
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- =========================================================================
-- STEP 5: ROW LEVEL SECURITY
-- =========================================================================

alter table public.profiles enable row level security;
alter table public.roles_permissions enable row level security;
alter table public.clients enable row level security;
alter table public.existing_loans enable row level security;
alter table public.credit_cards_requests enable row level security;
alter table public.interaction_history enable row level security;
alter table public.documents enable row level security;

create or replace function public.current_user_has_permission(permission_column text)
returns boolean as $$
declare
    user_role text;
    has_permission boolean;
begin
    select role into user_role from public.profiles where id = auth.uid();
    if user_role is null then return false; end if;
    execute format('select %I from public.roles_permissions where role = %L', permission_column, user_role)
    into has_permission;
    return coalesce(has_permission, false);
end;
$$ language plpgsql security definer;

-- Profiles policies
drop policy if exists "Allow profile viewing to authenticated users" on public.profiles;
create policy "Allow profile viewing to authenticated users" 
on public.profiles for select to authenticated using (true);

drop policy if exists "Allow profile edits to managers and self" on public.profiles;
create policy "Allow profile edits to managers and self" 
on public.profiles for update to authenticated 
using (auth.uid() = id or public.current_user_has_permission('can_manage_roles'));

-- Roles policies
drop policy if exists "Allow permissions grid view" on public.roles_permissions;
create policy "Allow permissions grid view" 
on public.roles_permissions for select to authenticated using (true);

drop policy if exists "Allow managers to edit permissions grid" on public.roles_permissions;
create policy "Allow managers to edit permissions grid" 
on public.roles_permissions for all to authenticated 
using (public.current_user_has_permission('can_manage_roles'));

-- Clients policies
drop policy if exists "Allow select based on permissions grid" on public.clients;
drop policy if exists "Allow select based on role and ownership" on public.clients;
create policy "Allow select based on role and ownership" 
on public.clients for select to authenticated 
using (
    public.current_user_has_permission('can_view_clients')
    and (
        (select role from public.profiles where id = auth.uid()) = 'admin'
        or created_by = auth.uid()
        or representative_name = (select full_name from public.profiles where id = auth.uid())
        or (
            (select role from public.profiles where id = auth.uid()) = 'manager'
            and representative_name in (select full_name from public.profiles where manager_id = auth.uid())
        )
    )
);

drop policy if exists "Allow insert based on permissions grid" on public.clients;
drop policy if exists "Allow insert based on ownership" on public.clients;
create policy "Allow insert based on ownership" 
on public.clients for insert to authenticated 
with check (
    public.current_user_has_permission('can_edit_clients')
    and (created_by = auth.uid() or created_by is null)
);

drop policy if exists "Allow update based on permissions grid" on public.clients;
drop policy if exists "Allow update based on role and ownership" on public.clients;
create policy "Allow update based on role and ownership" 
on public.clients for update to authenticated 
using (
    (public.current_user_has_permission('can_edit_clients') or public.current_user_has_permission('can_approve_loans'))
    and (
        (select role from public.profiles where id = auth.uid()) = 'admin'
        or created_by = auth.uid()
        or representative_name = (select full_name from public.profiles where id = auth.uid())
        or (
            (select role from public.profiles where id = auth.uid()) = 'manager'
            and representative_name in (select full_name from public.profiles where manager_id = auth.uid())
        )
    )
);

drop policy if exists "Allow delete based on permissions grid" on public.clients;
drop policy if exists "Allow delete based on role and ownership" on public.clients;
create policy "Allow delete based on role and ownership" 
on public.clients for delete to authenticated 
using (
    public.current_user_has_permission('can_delete_clients')
    and (
        (select role from public.profiles where id = auth.uid()) = 'admin'
        or created_by = auth.uid()
        or representative_name = (select full_name from public.profiles where id = auth.uid())
        or (
            (select role from public.profiles where id = auth.uid()) = 'manager'
            and representative_name in (select full_name from public.profiles where manager_id = auth.uid())
        )
    )
);

-- Loans policies
drop policy if exists "Loans RLS select" on public.existing_loans;
create policy "Loans RLS select" on public.existing_loans for select to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Loans RLS insert" on public.existing_loans;
create policy "Loans RLS insert" on public.existing_loans for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Loans RLS update" on public.existing_loans;
create policy "Loans RLS update" on public.existing_loans for update to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Loans RLS delete" on public.existing_loans;
create policy "Loans RLS delete" on public.existing_loans for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

-- Cards policies
drop policy if exists "Cards RLS select" on public.credit_cards_requests;
create policy "Cards RLS select" on public.credit_cards_requests for select to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Cards RLS insert" on public.credit_cards_requests;
create policy "Cards RLS insert" on public.credit_cards_requests for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Cards RLS update" on public.credit_cards_requests;
create policy "Cards RLS update" on public.credit_cards_requests for update to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Cards RLS delete" on public.credit_cards_requests;
create policy "Cards RLS delete" on public.credit_cards_requests for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

-- History policies
drop policy if exists "History RLS select" on public.interaction_history;
create policy "History RLS select" on public.interaction_history for select to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "History RLS insert" on public.interaction_history;
create policy "History RLS insert" on public.interaction_history for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));

-- Documents policies
drop policy if exists "Documents RLS select" on public.documents;
create policy "Documents RLS select" on public.documents for select to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Documents RLS insert" on public.documents;
create policy "Documents RLS insert" on public.documents for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Documents RLS update" on public.documents;
create policy "Documents RLS update" on public.documents for update to authenticated using (exists (select 1 from public.clients where id = client_id));
drop policy if exists "Documents RLS delete" on public.documents;
create policy "Documents RLS delete" on public.documents for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

-- =========================================================================
-- STEP 5.5: UPDATE CLIENTS STATUS CHECK CONSTRAINT
-- =========================================================================
do $$
begin
    -- Drop old check constraint if it exists
    alter table public.clients drop constraint if exists clients_status_check;
    
    -- Add new check constraint with all 7 statuses
    alter table public.clients add constraint clients_status_check 
        check (status in ('pending', 'iscore_inquiry', 'preparing_documents', 'under_review', 'at_bank', 'approved', 'rejected'));
exception when others then
    raise notice 'Skipped status constraint update: %', sqlerrm;
end $$;

-- =========================================================================
-- STEP 6: SEED DATA (safe)
-- =========================================================================

insert into public.roles_permissions (role, can_view_clients, can_edit_clients, can_delete_clients, can_approve_loans, can_view_analytics, can_manage_roles)
values 
('admin', true, true, true, true, true, true),
('manager', true, true, true, true, true, false),
('company_employee', true, true, false, false, false, false),
('bank_employee', true, false, false, true, true, false)
on conflict (role) do nothing;

-- Ensure that existing managers have this permission revoked
update public.roles_permissions set can_manage_roles = false where role != 'admin';

-- Seed test clients (only if full_name column exists now)
do $$
begin
    insert into public.clients (full_name, phone_number, national_id, birth_date, employment_type, company_name, job_title, is_insured, salary_transfer_method, credit_score, requested_amount, governorate, representative_name, status)
    values
    ('أحمد القحطاني', '0512345678', '10029384758694', '1988-10-15', 'private_sector', 'شركة الزيت العربية للاستشارات', 'مستشار تقني رئيسي', true, 'bank_transfer', 742, 1250000.00, 'الرياض', 'خالد عبد الله', 'under_review'),
    ('سارة المنصوري', '0543210987', '20019283746594', '1995-04-20', 'government_sector', 'وزارة المالية والتخطيط', 'محلل مالي أول', true, 'bank_transfer', 810, 850000.00, 'جدة', 'منى أحمد', 'approved'),
    ('محمد الشمري', '0509876543', '10087654321098', '1990-12-05', 'freelance', 'الشمري للاستشارات القانونية', 'محامٍ حر', false, 'cash', 580, 300000.00, 'الدمام', 'عمر فاروق', 'pending')
    on conflict (national_id) do nothing;
exception when others then
    raise notice 'Skipped client seed data: %', sqlerrm;
end $$;

-- =========================================================================
-- DONE! All tables, columns, triggers, RLS, and seed data are ready.
-- =========================================================================
