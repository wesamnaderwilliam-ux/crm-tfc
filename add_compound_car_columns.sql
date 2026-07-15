-- Migration to add Compound Units and Modern Cars tracking to clients table

ALTER TABLE public.clients 
ADD COLUMN IF NOT EXISTS has_compound_unit boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS has_modern_car boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS compound_units_data jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS modern_cars_data jsonb DEFAULT '[]'::jsonb;
