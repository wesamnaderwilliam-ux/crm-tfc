-- 1. Create expenses table
create table if not exists public.expenses (
    id uuid default uuid_generate_v4() primary key,
    title text not null,
    amount numeric(15,2) not null default 0.0,
    expense_date date not null default current_date,
    notes text,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.expenses enable row level security;

-- Create policies
create policy "Expenses select authenticated" on public.expenses 
    for select to authenticated using (true);

create policy "Expenses insert admin_manager" on public.expenses 
    for insert to authenticated with check (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );

create policy "Expenses update admin_manager" on public.expenses 
    for update to authenticated using (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );

create policy "Expenses delete admin_manager" on public.expenses 
    for delete to authenticated using (
        (select role from public.profiles where id = auth.uid()) in ('admin', 'manager')
    );
