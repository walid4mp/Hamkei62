# SocialNova — إعداد Render (نسخة Flutter Web)

## ما الذي تحتويه هذه الحزمة؟
هذه الحزمة مبنية على كامل أرشيف `Hamkei62-main (22).zip` المرفوع، مع إضافة ملفات نشر الويب `Dockerfile` و`nginx.conf` وهذا الدليل. لم تُحذف ملفات التطبيق الأصلية.

## إعداد Render
1. ارفع محتويات هذا المجلد إلى جذر المستودع `walid4mp/Hamkei62` مع الحفاظ على ملفات Flutter كلها.
2. في Render أنشئ/عدّل خدمة من نوع **Docker**.
3. Root Directory: اتركه فارغًا.
4. Dockerfile Path: `./Dockerfile`.
5. لا تستخدم إعداد Java/Gradle لهذه الخدمة؛ هذا Dockerfile يبني Flutter Web ويقدمه عبر Nginx على المنفذ 10000.
6. أضف Build Args في Render إن كان التطبيق يقرأ هذه القيم عبر `String.fromEnvironment`:
   - `SUPABASE_URL` = رابط مشروع Supabase
   - `SUPABASE_ANON_KEY` = مفتاح Supabase publishable/anon فقط
   - `ZEGO_APP_ID` و`ZEGO_APP_SIGN` و`FCM_PROJECT_ID` عند الحاجة
7. انشر الخدمة ثم تحقق من `/healthz`.

## حدود مهمة
- هذه الخدمة تستضيف **واجهة Flutter Web فقط**. الأرشيف لا يحتوي على مجلد `backend/` مستقل، لذلك هذا لا ينشئ API ولا يصلح وحده أخطاء 404 الصادرة من API أو مشاكل مخطط Supabase.
- لا تضع `service_role` أو أي سر إداري داخل تطبيق Flutter؛ القيم `--dart-define` المضمّنة في الويب يمكن استخراجها من ملفات العميل. استخدم مفتاح anon/publishable وسياسات RLS آمنة.
- نجاح البناء غير مضمون قبل تشغيل CI؛ بعض حزم Flutter قد لا تدعم الويب. راجع أول خطأ في Build Logs إن فشل.
