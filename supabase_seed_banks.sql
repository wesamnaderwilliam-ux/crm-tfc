-- =========================================================================
-- بيانات تأسيسية لدليل البنوك - يتم تشغيلها في Supabase SQL Editor
-- =========================================================================

-- 1. إدخال البنوك
INSERT INTO public.banks (id, bank_name) VALUES
  (gen_random_uuid(), 'البنك الأهلي المصري'),
  (gen_random_uuid(), 'بنك مصر'),
  (gen_random_uuid(), 'البنك التجاري الدولي (CIB)'),
  (gen_random_uuid(), 'بنك قطر الوطني الأهلي (QNB)'),
  (gen_random_uuid(), 'بنك القاهرة')
ON CONFLICT (bank_name) DO NOTHING;

-- 2. إدخال البرامج الأساسية
INSERT INTO public.core_programs (id, program_name) VALUES
  (gen_random_uuid(), 'تمويل شخصي بتعهد جهة العمل'),
  (gen_random_uuid(), 'التمويل العقاري (مبادرة 3%)'),
  (gen_random_uuid(), 'تمويل شخصي بدون تعهد'),
  (gen_random_uuid(), 'قرض السيارات'),
  (gen_random_uuid(), 'التمويل الشخصي للشركات الشريكة'),
  (gen_random_uuid(), 'بطاقات ائتمان البلاتينية'),
  (gen_random_uuid(), 'تمويل شخصي متكامل'),
  (gen_random_uuid(), 'قرض أصحاب المعاشات')
ON CONFLICT (program_name) DO NOTHING;

-- 3. ربط البرامج بالبنوك (bank_programs_details)
-- البنك الأهلي المصري
INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'برنامج التمويل الشخصي بضمان تحويل الراتب لموظفي الهيئات الحكومية والشركات الكبرى، يتميز بأطول فترة سداد وفائدة متناقصة.',
       12.50,
       2000000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'البنك الأهلي المصري'
  AND cp.program_name = 'تمويل شخصي بتعهد جهة العمل'
ON CONFLICT (bank_id, program_id) DO NOTHING;

INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'برنامج التمويل العقاري لمتوسطي ومحدودي الدخل ضمن مبادرة البنك المركزي المصري لمدد سداد تصل إلى 30 سنة وأقل عائد سنوي.',
       3.00,
       5000000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'البنك الأهلي المصري'
  AND cp.program_name = 'التمويل العقاري (مبادرة 3%)'
ON CONFLICT (bank_id, program_id) DO NOTHING;

-- بنك مصر
INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'تمويل شخصي مرن بدون الحاجة لتعهد جهة العمل بتحويل الراتب، متاح لموظفي القطاعين العام والخاص وأصحاب الأعمال الحرة.',
       14.20,
       1500000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'بنك مصر'
  AND cp.program_name = 'تمويل شخصي بدون تعهد'
ON CONFLICT (bank_id, program_id) DO NOTHING;

INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'تمويل السيارات الجديدة والمستعملة بمعدل فائدة تنافسي وإجراءات سريعة مع وثيقة تأمين مجانية على الحياة.',
       13.50,
       1000000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'بنك مصر'
  AND cp.program_name = 'قرض السيارات'
ON CONFLICT (bank_id, program_id) DO NOTHING;

-- البنك التجاري الدولي (CIB)
INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'تمويل نقدي مخصص لعملاء CIB المميزين أو بضمان وعاء ادخاري، مع سرعة فائقة في الحصول على الموافقة.',
       13.00,
       3000000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'البنك التجاري الدولي (CIB)'
  AND cp.program_name = 'التمويل الشخصي للشركات الشريكة'
ON CONFLICT (bank_id, program_id) DO NOTHING;

INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'بطاقة ائتمانية بحد ائتماني مرتفع ومميزات الدخول الحصري لصالات كبار الزوار بالمطارات وتجميع نقاط مكافآت مضاعفة.',
       24.00,
       500000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'البنك التجاري الدولي (CIB)'
  AND cp.program_name = 'بطاقات ائتمان البلاتينية'
ON CONFLICT (bank_id, program_id) DO NOTHING;

-- بنك قطر الوطني الأهلي (QNB)
INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'تمويل شخصي متكامل بأقساط شهرية متساوية وإمكانية دمج دخل الزوج أو الزوجة للحصول على قيمة تمويل أكبر.',
       12.90,
       2500000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'بنك قطر الوطني الأهلي (QNB)'
  AND cp.program_name = 'تمويل شخصي متكامل'
ON CONFLICT (bank_id, program_id) DO NOTHING;

-- بنك القاهرة
INSERT INTO public.bank_programs_details (id, bank_id, program_id, description, interest_rate, max_loan_amount)
SELECT gen_random_uuid(),
       b.id,
       cp.id,
       'قرض شخصي ميسر لأصحاب المعاشات والمستفيدين منها بفترات سداد مريحة وفائدة مخفضة.',
       14.50,
       1200000.00
FROM public.banks b, public.core_programs cp
WHERE b.bank_name = 'بنك القاهرة'
  AND cp.program_name = 'قرض أصحاب المعاشات'
ON CONFLICT (bank_id, program_id) DO NOTHING;

-- 4. إدخال موظفي البنوك
-- البنك الأهلي المصري
INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'أحمد رأفت',
       '01012345678',
       '0227980000',
       'مدير قطاع تمويل الأفراد',
       'ahmed.raafat@nbe.com.eg',
       'المسؤول الرئيسي لطلبات تمويل التعهدات والشركات الكبرى بالمنطقة المركزية.'
FROM public.banks b
WHERE b.bank_name = 'البنك الأهلي المصري';

INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'مي خالد',
       '01198765432',
       NULL,
       'أخصائي تمويل عقاري',
       'mai.khaled@nbe.com.eg',
       'متابعة مبادرة البنك المركزي للتمويل العقاري 3% و 8%.'
FROM public.banks b
WHERE b.bank_name = 'البنك الأهلي المصري';

-- بنك مصر
INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'شريف جلال',
       '01234567890',
       '0223910000',
       'نائب مدير الائتمان الاستهلاكي',
       's.galal@banquemisr.com',
       'مراجعة الموافقات السريعة للقروض الشخصية وتمويلات السيارات.'
FROM public.banks b
WHERE b.bank_name = 'بنك مصر';

-- البنك التجاري الدولي (CIB)
INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'نادية حسن',
       '01555544332',
       NULL,
       'مستشار الخدمات المصرفية المميزة',
       'nadia.hassan@cibeg.com',
       'المنسق المباشر لطلبات عملاء النخبة وبرامج التمويل العقاري الفاخر.'
FROM public.banks b
WHERE b.bank_name = 'البنك التجاري الدولي (CIB)';

-- بنك قطر الوطني الأهلي (QNB)
INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'عمرو فؤاد',
       '01098877665',
       NULL,
       'مسؤول تمويل التجزئة المصرفية',
       'amr.fouad@qnbalahli.com',
       'مختص بطلبات التمويل الشخصي والبطاقات الائتمانية لعملاء تحويل الراتب.'
FROM public.banks b
WHERE b.bank_name = 'بنك قطر الوطني الأهلي (QNB)';

-- بنك القاهرة
INSERT INTO public.bank_employees (id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes)
SELECT gen_random_uuid(),
       b.id,
       'طارق سليم',
       '01211223344',
       '0222630000',
       'مدير فرع عبد الخالق ثروت',
       'tarek.selim@bdc.com.eg',
       'متابعة كافة القروض الشخصية وقروض المعاشات الموجهة للفرع.'
FROM public.banks b
WHERE b.bank_name = 'بنك القاهرة';

-- =========================================================================
-- تحقق من البيانات
-- =========================================================================
SELECT 'banks' as table_name, count(*) as row_count FROM public.banks
UNION ALL
SELECT 'core_programs', count(*) FROM public.core_programs
UNION ALL
SELECT 'bank_programs_details', count(*) FROM public.bank_programs_details
UNION ALL
SELECT 'bank_employees', count(*) FROM public.bank_employees;
