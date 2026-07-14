-- =========================================================================
-- THE FUTURE CLUB (TFC) CRM - DATABASE SCHEMA
-- Execute this script in your Supabase SQL Editor (https://supabase.com)
-- =========================================================================

-- Enable UUID generation extension
create extension if not exists "uuid-ossp";

-- 1. Create Roles and Permissions grid table
create table if not exists public.roles_permissions (
    role text primary key,
    can_view_clients boolean default false,
    can_edit_clients boolean default false,
    can_delete_clients boolean default false,
    can_approve_loans boolean default false,
    can_view_analytics boolean default false,
    can_manage_roles boolean default false,
    field_visibility jsonb default '{}'::jsonb
);
-- Duplicate block removed

-- Seed permissions for the three groups: manager, company_employee, bank_employee
insert into public.roles_permissions (role, can_view_clients, can_edit_clients, can_delete_clients, can_approve_loans, can_view_analytics, can_manage_roles)
values 
('admin', true, true, true, true, true, true),
('manager', true, true, true, true, true, false),
('company_employee', true, true, false, false, false, false),
('bank_employee', true, false, false, true, true, false)
on conflict (role) do nothing;

-- Ensure that existing managers have this permission revoked
update public.roles_permissions set can_manage_roles = false where role != 'admin';

-- 2. Create User Profiles table
create table if not exists public.profiles (
    id uuid references auth.users on delete cascade primary key,
    full_name text not null,
    role text not null default 'company_employee' references public.roles_permissions(role),
    email text,
    password text,
    confirm_password text,
    phone_number text,
    national_id text,
    hiring_date date,
    is_confirmed boolean default false,
    manager_id uuid references public.profiles(id) on delete set null,
    employee_status text default 'active' check (employee_status in ('active', 'on_leave', 'terminated')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Create Clients table
create table if not exists public.clients (
    id uuid default uuid_generate_v4() primary key,
    full_name text not null,
    phone_number text not null,
    secondary_phone_number text,
    national_id text unique,
    birth_date date not null,
    employment_type text not null check (employment_type in ('private_sector', 'government_sector', 'government_employee', 'business_owner', 'doctor_clinic', 'doctor_hospital', 'pharmacist', 'pharmacist_owner', 'military', 'faculty', 'teacher', 'freelance', 'retired', 'other')),
    company_name text,
    business_data jsonb default '[]'::jsonb,
    job_title text,
    is_insured boolean default false,
    salary_transfer_method text not null check (salary_transfer_method in ('bank_transfer', 'cash')),
    salary_bank_details jsonb default '[]'::jsonb,
    cash_salary_amount numeric(15,2),
    credit_score integer not null default 600 check (credit_score >= 300 and credit_score <= 850),
    requested_amount numeric(15,2) not null default 0.0,
    governorate text not null,
    representative_name text,
    created_by uuid references public.profiles(id) on delete set null,
    status text not null default 'pending' check (status in ('pending', 'iscore_inquiry', 'preparing_documents', 'under_review', 'at_bank', 'approved', 'rejected')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. Create Existing Loans table
create table if not exists public.existing_loans (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete cascade not null,
    bank_name text not null,
    installment_value numeric(12,2) not null default 0.0,
    notes text
);

-- 5. Create Credit Cards and Card Requests table
create table if not exists public.credit_cards_requests (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete cascade not null,
    bank_name text not null,
    value numeric(12,2) not null default 0.0,
    five_percent_calc numeric(12,2) generated always as (value * 0.05) stored,
    type text not null check (type in ('card', 'request')),
    duration text,
    installment numeric(12,2) not null default 0.0,
    highest_value numeric(12,2) not null default 0.0,
    notes text
);

-- 6. Create Interaction History Log table
create table if not exists public.interaction_history (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete cascade not null,
    action_type text not null,
    notes text not null,
    created_by uuid references public.profiles(id) on delete set null,
    created_by_name text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. Trigger: Automate updated_at field on Client changes
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

-- 8. Trigger: Create a profile record automatically on user sign up in Supabase Auth
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
    );
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- =========================================================================
-- ROW LEVEL SECURITY (RLS) SETUP
-- =========================================================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.roles_permissions enable row level security;
alter table public.clients enable row level security;
alter table public.existing_loans enable row level security;
alter table public.credit_cards_requests enable row level security;
alter table public.interaction_history enable row level security;

-- Helper function to check if the current user has a specific permission
create or replace function public.current_user_has_permission(permission_column text)
returns boolean as $$
declare
    user_role text;
    has_permission boolean;
begin
    -- Get user role
    select role into user_role from public.profiles where id = auth.uid();
    
    -- If no user, or profile doesn't exist, deny
    if user_role is null then
        return false;
    end if;

    -- Query roles_permissions table dynamically using dynamic SQL
    execute format('select %I from public.roles_permissions where role = %L', permission_column, user_role)
    into has_permission;

    return coalesce(has_permission, false);
end;
$$ language plpgsql security definer;

-- RLS Policies for Profiles: Users can view all profiles if confirmed, but only self or admin/manager can update
create policy "Allow profile viewing to authenticated users" 
on public.profiles for select to authenticated 
using (
    auth.uid() = id 
    or (select is_confirmed from public.profiles where id = auth.uid()) = true
);

create policy "Allow profile edits to self and admin/manager" 
on public.profiles for update to authenticated 
using (
    auth.uid() = id 
    or (
        (select is_confirmed from public.profiles where id = auth.uid()) = true
        and (
            (select role from public.profiles where id = auth.uid()) = 'admin'
            or (select role from public.profiles where id = auth.uid()) = 'manager'
        )
    )
);

-- RLS Policies for Roles & Permissions: Anyone can view, only managers/admins can edit
create policy "Allow permissions grid view" 
on public.roles_permissions for select to authenticated using (
    (select is_confirmed from public.profiles where id = auth.uid()) = true
);

create policy "Allow managers to edit permissions grid" 
on public.roles_permissions for all to authenticated 
using (
    (select is_confirmed from public.profiles where id = auth.uid()) = true
    and public.current_user_has_permission('can_manage_roles')
);

-- RLS Policies for Clients table
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

create policy "Allow insert based on ownership" 
on public.clients for insert to authenticated 
with check (
    (select is_confirmed from public.profiles where id = auth.uid()) = true
    and public.current_user_has_permission('can_edit_clients')
    and (created_by = auth.uid() or created_by is null)
);

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

-- RLS Policies for Existing Loans, Credit Cards Requests, and Interaction History (tied to client permissions)
create policy "Loans RLS select" on public.existing_loans for select to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Loans RLS insert" on public.existing_loans for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
create policy "Loans RLS update" on public.existing_loans for update to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Loans RLS delete" on public.existing_loans for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

create policy "Cards RLS select" on public.credit_cards_requests for select to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Cards RLS insert" on public.credit_cards_requests for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
create policy "Cards RLS update" on public.credit_cards_requests for update to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Cards RLS delete" on public.credit_cards_requests for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

create policy "History RLS select" on public.interaction_history for select to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "History RLS insert" on public.interaction_history for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));

-- 7. Create Documents table
create table if not exists public.documents (
    id uuid default uuid_generate_v4() primary key,
    client_id uuid references public.clients(id) on delete cascade not null,
    document_name text not null,
    document_url text not null,
    status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.documents enable row level security;
create policy "Documents RLS select" on public.documents for select to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Documents RLS insert" on public.documents for insert to authenticated with check (exists (select 1 from public.clients where id = client_id));
create policy "Documents RLS update" on public.documents for update to authenticated using (exists (select 1 from public.clients where id = client_id));
create policy "Documents RLS delete" on public.documents for delete to authenticated using (exists (select 1 from public.clients where id = client_id));

-- Insert dummy seed clients for testing
insert into public.clients (full_name, phone_number, national_id, birth_date, employment_type, company_name, job_title, is_insured, salary_transfer_method, credit_score, requested_amount, governorate, representative_name, status)
values
('أحمد القحطاني', '0512345678', '10029384758694', '1988-10-15', 'private_sector', 'شركة الزيت العربية للاستشارات', 'مستشار تقني رئيسي', true, 'bank_transfer', 742, 1250000.00, 'الرياض', 'خالد عبد الله', 'under_review'),
('سارة المنصوري', '0543210987', '20019283746594', '1995-04-20', 'government_sector', 'وزارة المالية والتخطيط', 'محلل مالي أول', true, 'bank_transfer', 810, 850000.00, 'جدة', 'منى أحمد', 'approved'),
('محمد الشمري', '0509876543', '10087654321098', '1990-12-05', 'freelance', 'الشمري للاستشارات القانونية', 'محامٍ حر', false, 'cash', 580, 300000.00, 'الدمام', 'عمر فاروق', 'pending')
on conflict (national_id) do nothing;

-- =========================================================================
-- 8. Banks Directory Tables
-- =========================================================================

-- Banks
create table if not exists public.banks (
    id uuid default uuid_generate_v4() primary key,
    bank_name text not null unique,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Core Programs (base program templates)
create table if not exists public.core_programs (
    id uuid default uuid_generate_v4() primary key,
    program_name text not null unique,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Bank Programs Details (linking banks to programs with specific rates)
create table if not exists public.bank_programs_details (
    id uuid default uuid_generate_v4() primary key,
    bank_id uuid references public.banks(id) on delete cascade not null,
    program_id uuid references public.core_programs(id) on delete cascade not null,
    description text,
    interest_rate numeric(5,2),
    max_loan_amount numeric(15,2),
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique (bank_id, program_id)
);

-- Bank Employees (contact persons)
create table if not exists public.bank_employees (
    id uuid default uuid_generate_v4() primary key,
    bank_id uuid references public.banks(id) on delete cascade not null,
    employee_name text not null,
    phone_1 text,
    phone_2 text,
    job_title text,
    email text,
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for Banks Directory
alter table public.banks enable row level security;
create policy "Banks select" on public.banks for select to authenticated using (true);
create policy "Banks insert" on public.banks for insert to authenticated with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "Banks update" on public.banks for update to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "Banks delete" on public.banks for delete to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);

alter table public.core_programs enable row level security;
create policy "CorePrograms select" on public.core_programs for select to authenticated using (true);
create policy "CorePrograms insert" on public.core_programs for insert to authenticated with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "CorePrograms update" on public.core_programs for update to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "CorePrograms delete" on public.core_programs for delete to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);

alter table public.bank_programs_details enable row level security;
create policy "BankPrograms select" on public.bank_programs_details for select to authenticated using (true);
create policy "BankPrograms insert" on public.bank_programs_details for insert to authenticated with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "BankPrograms update" on public.bank_programs_details for update to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "BankPrograms delete" on public.bank_programs_details for delete to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);

alter table public.bank_employees enable row level security;
create policy "BankEmployees select" on public.bank_employees for select to authenticated using (true);
create policy "BankEmployees insert" on public.bank_employees for insert to authenticated with check (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "BankEmployees update" on public.bank_employees for update to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
create policy "BankEmployees delete" on public.bank_employees for delete to authenticated using (
    (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
);
