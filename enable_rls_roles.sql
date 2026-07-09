-- =========================================================================
-- TFC CRM - ENABLE RLS & ROLE-BASED ACCESS CONTROL (RBAC)
-- Run this in your Supabase SQL Editor to activate strict and dynamic RLS policies
-- =========================================================================

-- 0. Ensure 'host' is a valid value in the user_role enum if it is defined as an enum
alter type user_role add value if not exists 'host';
commit; -- Commit the transaction to ensure the new enum value is registered and usable in subsequent queries



-- 1. Enable RLS on all tables to secure the database
alter table public.profiles enable row level security;
alter table public.roles_permissions enable row level security;
alter table public.clients enable row level security;
alter table public.existing_loans enable row level security;
alter table public.credit_cards_requests enable row level security;
alter table public.interaction_history enable row level security;
alter table public.documents enable row level security;

-- 2. Make sure the 'host' (مضيف) role exists in roles_permissions, along with other roles
insert into public.roles_permissions (role, can_view_clients, can_edit_clients, can_delete_clients, can_approve_loans, can_view_analytics, can_manage_roles)
values 
('admin', true, true, true, true, true, true),
('manager', true, true, true, true, true, true),
('company_employee', true, true, false, false, false, false),
('bank_employee', true, false, false, true, true, false),
('host', true, false, false, false, false, false)
on conflict (role) do nothing;

-- 3. Helper function to check if the current authenticated user's role has a specific permission
create or replace function public.current_user_has_permission(permission_column text)
returns boolean as $$
declare
    user_role text;
    has_permission boolean;
begin
    -- Get user role from the profiles table linked to the authenticated user ID
    select role into user_role from public.profiles where id = auth.uid();
    
    -- If no user, or profile doesn't exist, deny access
    if user_role is null then
        return false;
    end if;

    -- Query the roles_permissions table dynamically to check the permission
    execute format('select %I from public.roles_permissions where role = %L', permission_column, user_role)
    into has_permission;

    return coalesce(has_permission, false);
end;
$$ language plpgsql security definer;

-- 4. Set up Policies for PROFILES
drop policy if exists "Allow profile viewing to authenticated users" on public.profiles;
create policy "Allow profile viewing to authenticated users" 
on public.profiles for select to authenticated using (true);

drop policy if exists "Allow profile edits to managers and self" on public.profiles;
create policy "Allow profile edits to managers and self" 
on public.profiles for update to authenticated 
using (auth.uid() = id or public.current_user_has_permission('can_manage_roles'));

-- 5. Set up Policies for ROLES_PERMISSIONS
drop policy if exists "Allow permissions grid view" on public.roles_permissions;
create policy "Allow permissions grid view" 
on public.roles_permissions for select to authenticated using (true);

drop policy if exists "Allow managers to edit permissions grid" on public.roles_permissions;
create policy "Allow managers to edit permissions grid" 
on public.roles_permissions for all to authenticated 
using (public.current_user_has_permission('can_manage_roles'));

-- 6. Set up Policies for CLIENTS
drop policy if exists "Allow select based on permissions grid" on public.clients;
create policy "Allow select based on permissions grid" 
on public.clients for select to authenticated 
using (public.current_user_has_permission('can_view_clients'));

drop policy if exists "Allow insert based on permissions grid" on public.clients;
create policy "Allow insert based on permissions grid" 
on public.clients for insert to authenticated 
with check (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Allow update based on permissions grid" on public.clients;
create policy "Allow update based on permissions grid" 
on public.clients for update to authenticated 
using (public.current_user_has_permission('can_edit_clients') or public.current_user_has_permission('can_approve_loans'));

drop policy if exists "Allow delete based on permissions grid" on public.clients;
create policy "Allow delete based on permissions grid" 
on public.clients for delete to authenticated 
using (public.current_user_has_permission('can_delete_clients'));

-- 7. Set up Policies for EXISTING_LOANS
drop policy if exists "Loans RLS select" on public.existing_loans;
create policy "Loans RLS select" on public.existing_loans for select to authenticated using (public.current_user_has_permission('can_view_clients'));

drop policy if exists "Loans RLS insert" on public.existing_loans;
create policy "Loans RLS insert" on public.existing_loans for insert to authenticated with check (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Loans RLS update" on public.existing_loans;
create policy "Loans RLS update" on public.existing_loans for update to authenticated using (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Loans RLS delete" on public.existing_loans;
create policy "Loans RLS delete" on public.existing_loans for delete to authenticated using (public.current_user_has_permission('can_edit_clients'));

-- 8. Set up Policies for CREDIT_CARDS_REQUESTS
drop policy if exists "Cards RLS select" on public.credit_cards_requests;
create policy "Cards RLS select" on public.credit_cards_requests for select to authenticated using (public.current_user_has_permission('can_view_clients'));

drop policy if exists "Cards RLS insert" on public.credit_cards_requests;
create policy "Cards RLS insert" on public.credit_cards_requests for insert to authenticated with check (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Cards RLS update" on public.credit_cards_requests;
create policy "Cards RLS update" on public.credit_cards_requests for update to authenticated using (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Cards RLS delete" on public.credit_cards_requests;
create policy "Cards RLS delete" on public.credit_cards_requests for delete to authenticated using (public.current_user_has_permission('can_edit_clients'));

-- 9. Set up Policies for DOCUMENTS
drop policy if exists "Documents RLS select" on public.documents;
create policy "Documents RLS select" on public.documents for select to authenticated using (public.current_user_has_permission('can_view_clients'));

drop policy if exists "Documents RLS insert" on public.documents;
create policy "Documents RLS insert" on public.documents for insert to authenticated with check (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Documents RLS update" on public.documents;
create policy "Documents RLS update" on public.documents for update to authenticated using (public.current_user_has_permission('can_edit_clients'));

drop policy if exists "Documents RLS delete" on public.documents;
create policy "Documents RLS delete" on public.documents for delete to authenticated using (public.current_user_has_permission('can_edit_clients'));

-- 10. Set up Policies for INTERACTION_HISTORY
drop policy if exists "History RLS select" on public.interaction_history;
create policy "History RLS select" on public.interaction_history for select to authenticated using (true);

drop policy if exists "History RLS insert" on public.interaction_history;
create policy "History RLS insert" on public.interaction_history for insert to authenticated with check (true);
