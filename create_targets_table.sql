-- 1. Create employee_targets table
create table if not exists public.employee_targets (
    id uuid default uuid_generate_v4() primary key,
    employee_id uuid not null references public.profiles(id) on delete cascade,
    target_amount numeric(15,2) not null default 0.0,
    target_month text not null, -- Format: YYYY-MM (e.g. '2026-07')
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(employee_id, target_month)
);

-- Enable RLS
alter table public.employee_targets enable row level security;

-- Create policies
create policy "Targets select all" on public.employee_targets 
    for select to authenticated using (true);

create policy "Targets insert admin_manager" on public.employee_targets 
    for insert to authenticated with check (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );

create policy "Targets update admin_manager" on public.employee_targets 
    for update to authenticated using (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );

create policy "Targets delete admin_manager" on public.employee_targets 
    for delete to authenticated using (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );
