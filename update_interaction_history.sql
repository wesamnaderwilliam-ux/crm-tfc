-- =========================================================================
-- THE FUTURE CLUB (TFC) CRM - UPDATE INTERACTION HISTORY SCHEMA
-- Run this in your Supabase SQL Editor (https://supabase.com)
-- =========================================================================

-- 1. Add log_type column if not exists
alter table public.interaction_history 
add column if not exists log_type text default 'file_interaction' 
check (log_type in ('file_interaction', 'follow_up', 'bank_follow_up'));

-- 2. Add follow_up_date column if not exists
alter table public.interaction_history 
add column if not exists follow_up_date timestamp with time zone;
