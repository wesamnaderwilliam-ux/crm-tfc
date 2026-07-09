-- =========================================================================
-- TFC CRM - DISABLE RLS FOR DEVELOPMENT
-- Run this in Supabase SQL Editor to allow any mock/demo logins to read and write.
-- =========================================================================

-- Disable Row Level Security on all tables
alter table public.clients disable row level security;
alter table public.existing_loans disable row level security;
alter table public.credit_cards_requests disable row level security;
alter table public.interaction_history disable row level security;
alter table public.documents disable row level security;
alter table public.profiles disable row level security;
alter table public.roles_permissions disable row level security;

-- Drop existing policies to clean up
drop policy if exists "Allow select based on permissions grid" on public.clients;
drop policy if exists "Allow insert based on permissions grid" on public.clients;
drop policy if exists "Allow update based on permissions grid" on public.clients;
drop policy if exists "Allow delete based on permissions grid" on public.clients;

drop policy if exists "Loans RLS select" on public.existing_loans;
drop policy if exists "Loans RLS insert" on public.existing_loans;
drop policy if exists "Loans RLS update" on public.existing_loans;
drop policy if exists "Loans RLS delete" on public.existing_loans;

drop policy if exists "Cards RLS select" on public.credit_cards_requests;
drop policy if exists "Cards RLS insert" on public.credit_cards_requests;
drop policy if exists "Cards RLS update" on public.credit_cards_requests;
drop policy if exists "Cards RLS delete" on public.credit_cards_requests;

drop policy if exists "History RLS select" on public.interaction_history;
drop policy if exists "History RLS insert" on public.interaction_history;

drop policy if exists "Documents RLS select" on public.documents;
drop policy if exists "Documents RLS insert" on public.documents;
drop policy if exists "Documents RLS update" on public.documents;
drop policy if exists "Documents RLS delete" on public.documents;

drop policy if exists "Allow profile viewing to authenticated users" on public.profiles;
drop policy if exists "Allow profile edits to managers and self" on public.profiles;

drop policy if exists "Allow permissions grid view" on public.roles_permissions;
drop policy if exists "Allow managers to edit permissions grid" on public.roles_permissions;
