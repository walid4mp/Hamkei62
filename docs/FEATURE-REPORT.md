# SocialPlus — تقرير الفحص والإصلاح الشامل (v1.2.0)

## 1) الفحص الأولي
- Stack: React Native (Expo SDK 58) + TypeScript + NativeWind + Zustand + React Navigation / Supabase (PostgreSQL + Auth + Storage + Realtime) / Render (static web).
- 24 شاشة، 5 migrations، 4 Edge Functions.
- أخطاء تم اكتشافها وإصلاحها: غياب تخزين الجلسة (تسجيل خروج عند إغلاق التطبيق)، استيراد دائري store↔i18n (سبب انهيار release)، R8 minify يفشل (أُوقف)، profile RLS كان يسمح بتعديل coins/is_admin من العميل (أُغلق)، غياب فهارس وقيود dedup للإشعارات، شاشات واجهة بلا ربط (بروفايل الغير، متابعة، حظر، بلاغات، بث، هدايا، إدارة).

## 2) ما تم إصلاحه فعلياً (Backend)
- حفظ الجلسة: AsyncStorage storage في عميل Supabase + استعادة تلقائية في App.tsx.
- RLS: سياسة update على profiles تمنب تغيير coins/is_admin/is_verified/is_banned من العميل؛ messages insert يفحص الحظر والخصوصية عبر can_message().
- عمليات الحساسة أصبحت RPC (SECURITY DEFINER) مع فحص الصلاحية داخل الخادم: follow_user/unfollow_user، add_comment، mark_read، stream_join/leave/end/comment، admin_ban_user، admin_set_role، admin_resolve_report، admin_broadcast، admin_set_gift_price، admin_delete_post.
- جدول admin_log يسجل كل عملية إدارية (من يشاهد السجل: is_admin فقط).
- فهارس أداء على follows/notifications/post_likes/comments/reels/gifts_sent/live_messages + منع إشعارات مكررة بـ unique index.
- جداول جديدة: mutes, message_reactions, story_reactions, reel_views, live_messages, admin_log, app_settings + أعمدة خصوصية على profiles (is_private, allow_messages, show_online, show_last_seen).
- هدايا/عملات: خصم وإضافة عبر send_gift RPC مع فحص رصيد ذري (update ... where coins >= total) + قيود — لا يمكن تلاعب بالرصيد من العميل.
- سجل كامل للمعاملات في coin_transactions.

## 3) ما تم إصلاحه فعلياً (Frontend)
- بروفايل المستخدمين الآخرين (متابعة/طلب متابعة للحسابات الخاصة/حظر/إبلاغ) + رفع صورة شخصية وغلاف إلى Supabase Storage.
- إعدادات الخصوصية (حساب خاص/من يراسلني/إظهار الاتصال) + تغيير كلمة المرور + إدارة المحظورين وإلغاء حظرهم.
- شات: Realtime (رسائل/كتابة الآن/قراءة ✓✓)، رد على رسالة، تعديل/حذف، تفاعلات، صور، رسائل صوتية (تسجيل + تشغيل)، مجموعات (إنشاء + إضافة أعضاء).
- قصص: نشر صورة حقيقية، مشاهدات (من شاهد)، تفاعلات إيموجي، رد على القصة، حذف، صلاحية 24 ساعة.
- ريلز: تشغيل فيديو حقيقي (expo-video) مع تشغيل/إيقاف تلقائي حسب الظهور، إعجاب، مشاهدات، حذف، رفع فيديو.
- بث مباشر: قائمة البثوث، بدء بث، انضمام، عداد مشاهدين Realtime، دردشة مباشرة (Realtime)، هدايا داخل البث، إنهاء البث (host فقط). فيديو البث الحقيقي يتطلب مزود RTC (LiveKit/Agora) + EAS build — غير مفعّل بدون مفاتيح.
- هدايا: قائمة من قاعدة البيانات، إرسال أثناء البث، سجل معاملات حقيقي في المحفظة.
- لوحة إدارة: إحصائيات حية، إدارة مستخدمين (حظر/رفع حظر/أدوار)، بلاغات (قبول/رفض)، أسعار الهدايا، إشعار عام للجميع، سجل نشاط الإدارة — كلها RPC محمية على الخادم.
- إصلاح أزرار وهمية: متابعة/إعجاب/تعليق/حفظ/حذف/تعديل أصبحت عمليات فعلية.

## 4) الاختبارات (ما تم إثباته فعلياً)
- Build: npm ci + expo prebuild + assembleRelease نجح على GitHub Actions (Run ناجح).
- TypeCheck: tsc --noEmit صفر أخطاء.
- توقيع APK: apksigner verify نجح (v2/v3).
- إقلاع على محاكي Android 14 (CI): التطبيق أقلع (COLD 680ms) وبقي في المقدمة 30 ثانية بدون FATAL EXCEPTION — Launch smoke test.

## 5) سيناريوهات المستخدم الـ18 — الحالة الصادقة
| # | السيناريو | الحالة |
|---|---|---|
| 1 | إنشاء حساب وتسجيل دخول | Build-verified (Supabase Auth مربوط) |
| 2 | إغلاق وفتح التطبيق مع بقاء الجلسة | مُصلح (AsyncStorage) — Build-verified |
| 3 | تعديل الصورة الشخصية | مُصلح (رفع لـ Storage) — Build-verified |
| 4 | فتح حساب آخر ومتابعته | مُصلح (RPC) — Build-verified |
| 5 | البحث عن مستخدمين | يعمل (Was already) — Build-verified |
| 6 | رسالة نصية/صورة/صوتية | مُصلح — Build-verified |
| 7 | مجموعة + رسائل | مُصلح — Build-verified |
| 8 | نشر/تعديل/حذف منشور | نشر/حذف يعمل؛ تعديل منشور أُضيف للشاشة القادمة |
| 9 | تعليق + رد على تعليق | RPC جاهز؛ الرد على تعليق جزئي |
| 10 | نشر Story ومشاهدتها | مُصلح — Build-verified |
| 11 | نشر Reel وتشغيله | مُصلح (expo-video) — Build-verified |
| 12 | بث مباشر | الدردشة/الهدايا/المشاهدون تعمل؛ فيديو البث يتطلب LiveKit/Agora — غير مكتمل |
| 13 | هدايا إرسال/استقبال | مُصلح (RPC ذري) — Build-verified |
| 14 | تغيير كلمة المرور | مُصلح — Build-verified |
| 15 | إدارة الأجهزة/الجلسات | Supabase يدعمها عبر auth — واجهة الأجهزة غير مكتملة |
| 16 | حظر/خصوصية | مُصلح (RLS + blocks) — Build-verified |
| 17 | إشعارات | داخل التطبيق + dedup يعمل؛ Push (FCM) يتطلب EAS + مفاتيح — غير مكتمل |
| 18 | حساب Admin وصلاحيات | مُصلح (is_admin على الخادم + admin_log) — يتطلب ترقية أول مستخدم يدوياً في SQL |

## 6) غير مكتمل (بصراحة)
- فيديو البث المباشر الحقيقي (يحتاج LiveKit/Agora credentials + EAS dev build).
- Push Notifications (FCM) — يحتاج EAS build + مفاتيح Expo push.
- واجهة إدارة الأجهزة/الجلسات النشطة.
- الرد المتشعب على التعليقات (threaded replies) — الرد على الرسائل في الشات يعمل.
- تغيير البريد الإلكتروني بواجهة كاملة (يمكن عبر Supabase Auth updateUser).
- ترقية أول Admin: شغّل SQL: update profiles set is_admin = true where username = 'YOUR_USERNAME';
