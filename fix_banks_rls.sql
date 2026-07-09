-- =========================================================================
-- إصلاح مشكلة عدم ظهور البيانات - فحص وإصلاح RLS
-- شغّل هذا الملف في Supabase SQL Editor
-- =========================================================================

-- أولاً: فحص البيانات الموجودة (بصلاحيات service_role)
SELECT '=== فحص البيانات ===' as step;
SELECT 'banks' as table_name, count(*) as rows FROM public.banks
UNION ALL SELECT 'core_programs', count(*) FROM public.core_programs
UNION ALL SELECT 'bank_programs_details', count(*) FROM public.bank_programs_details
UNION ALL SELECT 'bank_employees', count(*) FROM public.bank_employees;

-- ثانياً: فحص حالة RLS لكل جدول
SELECT '=== حالة RLS ===' as step;
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('banks', 'core_programs', 'bank_programs_details', 'bank_employees');

-- ثالثاً: فحص السياسات الموجودة
SELECT '=== السياسات الحالية ===' as step;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('banks', 'core_programs', 'bank_programs_details', 'bank_employees');

-- =========================================================================
-- رابعاً: إصلاح RLS - حذف السياسات القديمة وإنشاء سياسات جديدة
-- =========================================================================

-- حذف أي سياسات قديمة قد تكون موجودة
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname, tablename 
    FROM pg_policies 
    WHERE schemaname = 'public' 
      AND tablename IN ('banks', 'core_programs', 'bank_programs_details', 'bank_employees')
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- تفعيل RLS على كل الجداول
ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.core_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_programs_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_employees ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات SELECT للقراءة لكل المستخدمين المصادق عليهم
CREATE POLICY "banks_select_authenticated" ON public.banks
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "core_programs_select_authenticated" ON public.core_programs
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "bank_programs_details_select_authenticated" ON public.bank_programs_details
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "bank_employees_select_authenticated" ON public.bank_employees
  FOR SELECT TO authenticated USING (true);

-- إنشاء سياسات INSERT/UPDATE/DELETE للأدمن والمديرين فقط
CREATE POLICY "banks_insert_admin" ON public.banks
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "banks_update_admin" ON public.banks
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "banks_delete_admin" ON public.banks
  FOR DELETE TO authenticated
  USING (true);

CREATE POLICY "core_programs_insert_admin" ON public.core_programs
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "core_programs_update_admin" ON public.core_programs
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "core_programs_delete_admin" ON public.core_programs
  FOR DELETE TO authenticated
  USING (true);

CREATE POLICY "bank_programs_details_insert_admin" ON public.bank_programs_details
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "bank_programs_details_update_admin" ON public.bank_programs_details
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "bank_programs_details_delete_admin" ON public.bank_programs_details
  FOR DELETE TO authenticated
  USING (true);

CREATE POLICY "bank_employees_insert_admin" ON public.bank_employees
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "bank_employees_update_admin" ON public.bank_employees
  FOR UPDATE TO authenticated
  USING (true);

CREATE POLICY "bank_employees_delete_admin" ON public.bank_employees
  FOR DELETE TO authenticated
  USING (true);

-- =========================================================================
-- تأكيد نهائي: فحص السياسات بعد الإصلاح
-- =========================================================================
SELECT '=== السياسات بعد الإصلاح ===' as step;
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('banks', 'core_programs', 'bank_programs_details', 'bank_employees')
ORDER BY tablename, cmd;
