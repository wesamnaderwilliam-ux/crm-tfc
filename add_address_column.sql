-- Migration script to add address column to clients table in Supabase

ALTER TABLE public.clients 
ADD COLUMN IF NOT EXISTS address text;
