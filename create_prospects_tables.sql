-- 1. Create prospects table for Google Sheets potential leads
CREATE TABLE IF NOT EXISTS prospects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    phone_number TEXT,
    secondary_phone_number TEXT,
    national_id TEXT,
    governorate TEXT,
    job_title TEXT,
    company_name TEXT,
    salary_amount NUMERIC,
    notes TEXT,
    raw_data JSONB DEFAULT '{}'::jsonb,
    assigned_to_id UUID,
    assigned_to_name TEXT,
    status TEXT DEFAULT 'pending', -- pending, contacted, converted, rejected
    is_converted BOOLEAN DEFAULT false,
    converted_client_id UUID REFERENCES clients(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create Google Sheets configuration table
CREATE TABLE IF NOT EXISTS google_sheets_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sheet_url TEXT NOT NULL,
    field_mappings JSONB DEFAULT '{}'::jsonb,
    auto_sync BOOLEAN DEFAULT true,
    last_synced_at TIMESTAMP WITH TIME ZONE,
    updated_by UUID,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE prospects ENABLE ROW LEVEL SECURITY;
ALTER TABLE google_sheets_config ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read and update prospects
CREATE POLICY "Allow authenticated read prospects" ON prospects FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert prospects" ON prospects FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated update prospects" ON prospects FOR UPDATE USING (true);
CREATE POLICY "Allow authenticated delete prospects" ON prospects FOR DELETE USING (true);

-- Allow config access
CREATE POLICY "Allow authenticated read google_sheets_config" ON google_sheets_config FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert google_sheets_config" ON google_sheets_config FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated update google_sheets_config" ON google_sheets_config FOR UPDATE USING (true);
