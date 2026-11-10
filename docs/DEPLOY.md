# دليل النشر الكامل

## 1. Supabase
```bash
supabase login
supabase link --project-ref iugcevwsgxmomqjbgqoq
supabase db push          # يطبق migrations/ على القاعدة
supabase functions deploy ai-content-filter
supabase functions deploy ai-recommendations
supabase functions deploy grant-gift
supabase functions deploy withdraw-coins
```
> بديل: الصق محتوى `migrations/*.sql` في SQL Editor داخل لوحة Supabase.

## 2. Render (Blueprint)
1. Dashboard → New → Blueprint → اختر المستودع `walid4mp/socialplus-full`.
2. Render يقرأ `render.yaml` ويبني Static Site من `expo export -p web`.
3. أضف البيئة: `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`.

## 3. المتغيرات
| المتغير | أين | ملاحظة |
|---|---|---|
| EXPO_PUBLIC_SUPABASE_URL | Expo + Render | عام |
| EXPO_PUBLIC_SUPABASE_ANON_KEY | Expo + Render | عام (محمي بـ RLS) |
| SUPABASE_SERVICE_ROLE_KEY | Edge Functions فقط | سري — لا يوضع في العميل |
