# SocialNova V9 — نسخة واحدة تجمع إنستقرام + تيك توك + مسنجر

تطبيق شبكة اجتماعية كامل (Flutter + Node/Express + Prisma/PostgreSQL + Socket.IO) بواجهة عربية داكنة احترافية.

## الميزات
- Home / Feed + Stories (إنشاء من المعرض + مشاهد أفقي كامل الشاشة).
- Posts نصية/صور/فيديو + إعجاب + تعليقات + حذف منشورك + خصوصية المنشور (عام/المتابعون/خاص).
- Reels: رفع فيديو من المعرض + مشغل عمودي كامل الشاشة + عدّاد مشاهدات.
- Messenger: صندوق محادثات + بحث مستخدمين + محادثة فردية فورية (Socket.IO + REST fallback).
- Groups: إنشاء/انضمام/مغادرة + محادثة جماعية.
- Live احترافي: غرفة عمودية بأسلوب TikTok، كاميرا/ميكروفون، تعليقات لحظية، معاينة المشاركين، مشاركة شاشة الهاتف على Android، وإيقاف البث.
- Profile احترافي: صورة + غلاف + Bio + موقع + مكان + تاريخ الميلاد + المنشورات + المتابعون/يتابع.
- Search عن المستخدمين، Notifications، Settings كاملة.
- نظام توثيق مدفوع بمستويين: توثيق عادي (شارة زرقاء) وتوثيق احترافي (شارة ذهبية) + سجل طلبات + موافقة إدارية.
- خصوصية: حساب خاص/عام، إخفاء عدد المتابعين/الذين تتابعهم، إظهار حالة الاتصال، طلبات الرسائل، الإشعارات.
- رفع الصور والفيديو من الهاتف إلى الخادم عبر `/api/upload`.

## إصلاحات
- زر تاريخ الميلاد يعمل الآن (كان `TextEditingController` يُنشأ داخل `build` فيُفقد الحدث) — صار حقلاً موجّهًا بالحالة مع تفويض تاريخ عربي.
- `Java/Kotlin JVM 17` موحّد عبر `compileOptions` + `kotlinOptions` + JDK 17 في GitHub Actions.
- AGP 8.7.3 / Kotlin 2.1.0 / Gradle cache، وإنشاء `local.properties` تلقائيًا في CI.

## الخادم
`render.yaml` يعرّف خدمة `socialnova-api` + قاعدة `socialnova-db`. بعد أول نشر شغّل تسجيل حساب من التطبيق.

## APK
Workflow: `.github/workflows/android.yml`. اضبط المتغير `API_URL` على عنوان Render.


## LiveKit / مشاركة الشاشة

أضف `LIVEKIT_URL` و`LIVEKIT_API_KEY` و`LIVEKIT_API_SECRET` إلى بيئة الخادم. التطبيق يستخدم `livekit_client` للبث الصوتي/الفيديو، وعلى Android يستخدم خدمة foreground مع MediaProjection لمشاركة الشاشة. يلزم موافقة المستخدم على نافذة مشاركة الشاشة في الهاتف.

## ملاحظة مهمة عن الخادم الحالي

إذا بقي التطبيق يعرض التحميل أو رسالة `ClientConnection closed while receiving data`، افحص أولاً عنوان `API_URL`. النسخة الحالية تقلل زمن الانتظار وتعيد محاولة الطلب والرفع تلقائيًا، لكن لا يمكن للتطبيق إصلاح DNS أو توقف خدمة الاستضافة نفسها. يجب أن يكون `/api/health` يعيد `{\"ok\":true}` قبل اختبار Messenger وProfile وNotifications وReels وLive.


## NovaCoin — العملات والهدايا والمحفظة
- عملة مستقلة باسم **NovaCoin (NVC)** وليست مرتبطة بعملات Telegram أو TikTok.
- محفظة داخل التطبيق: رصيد للشراء/الإرسال ورصيد منفصل قابل للسحب.
- باقات شراء جاهزة لربطها مع Google Play / App Store عبر `in_app_purchase`.
- هدايا رقمية: وردة، قلب، نجمة، تاج، صاروخ، مجرة.
- إرسال الهدايا في Live، المنشورات، Reels، ومن زر الهدية بجانب التعليقات.
- عند استلام هدية، يتحول جزء قابل للسحب إلى رصيد صاحب الحساب؛ النسبة الافتراضية 70% ويمكن تغييرها من الخادم.
- السحب يخصم رسمًا افتراضيًا 10% ويحوّل الباقي إلى قيمة نقدية محسوبة على أساس 100 NVC = 1 USD قبل الرسم.
- طلبات السحب تمر بحالة `PENDING` ثم يراجعها المشرف من API الإداري قبل `PAID` أو `REJECTED`، وعند الرفض يعاد الرصيد للمحفظة.
- السحب النقدي في الخادم مقيد بحساب موثق للعمر 18+؛ لا توجد أي طريقة لتجاوز التحقق.

### شراء العملات في المتاجر
العميل يستخدم `in_app_purchase` لفتح Google Play/App Store. الخادم **لا يضيف العملات لمجرد أن العميل أرسل طلبًا**؛ في الإنتاج يجب تفعيل التحقق الخادمي من إيصال/رمز الشراء لكل متجر. المتغير `IAP_VERIFICATION_MODE=DEMO` موجود للاختبار المحلي فقط، ولا ينبغي استخدامه في الإنتاج.

### قاعدة البيانات
بعد نشر نسخة الخادم شغّل:
`npx prisma db push`
ثم أعد تشغيل الخدمة حتى تُنشأ جداول `Wallet`, `WalletTransaction`, `Gift`, `GiftTransaction`, `PurchaseOrder`, و`WithdrawalRequest` وتُملأ الهدايا الافتراضية.
### CI / Flutter compatibility

The Android workflow uses Flutter 3.29.2 (Dart 3.7.x). The LiveKit Flutter dependency is pinned to `livekit_client: 2.5.4` because newer LiveKit 2.12+ releases require Dart 3.10+, which would make `flutter pub get` fail on this CI toolchain.
