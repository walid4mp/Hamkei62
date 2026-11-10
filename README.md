# SocialPlus — تطبيق تواصل اجتماعي Full Stack 💜

<div align="center">

**Expo (React Native) + TypeScript + NativeWind + Zustand + Supabase + PostgreSQL + Edge Functions**

ألوان العلامة: `#5B67F1` · `#8B5CF6` · `#00D4FF` — وضع ليلي كامل، Glassmorphism، عربي/إنجليزي مع RTL.

</div>

## 🚀 التشغيل السريع

```bash
git clone https://github.com/walid4mp/socialplus-full.git
cd socialplus-full
cp .env.example .env   # ضع مفاتيح Supabase الخاصة بك
npm install
npx expo start         # اضغط i للمحاكي أو امسح QR بـ Expo Go
```

## ☁️ إعداد Supabase (الإنتاج)

1. أنشئ مشروعاً على [supabase.com](https://supabase.com).
2. من SQL Editor شغّل الملفات بالترتيب:
   - `supabase/migrations/00001_init.sql` — كل الجداول + دوال + RLS
   - `supabase/migrations/00002_storage.sql` — bucket عام `media` + سياساته
3. (اختياري) انشر دوال Edge:
   ```bash
   supabase login
   supabase link --project-ref <PROJECT-REF>
   supabase functions deploy ai-content-filter
   supabase functions deploy ai-recommendations
   supabase functions deploy grant-gift
   supabase functions deploy withdraw-coins
   ```
4. فعّل مزوّدي OAuth (Google / Apple / Facebook) من Authentication → Providers.
5. ضع `EXPO_PUBLIC_SUPABASE_URL` و `EXPO_PUBLIC_SUPABASE_ANON_KEY` في `.env`.

## 🌐 النشر على Render

يقرأ Render تلقائياً ملف `render.yaml` (Blueprint):
- **Static Site**: `npm ci && npx expo export --platform web` → مجلد `dist`
- أضف متغيرَي Supabase في لوحة Render ثم Deploy.

## 📁 هيكل المشروع

```
socialplus/
├── App.tsx                     # نقطة الدخول + جسر المصادقة
├── global.css                  # Tailwind (NativeWind)
├── src/
│   ├── theme/                  # الألوان والهوامش والتدرجات
│   ├── i18n/                   # عربي/إنجليزي + RTL
│   ├── lib/                    # عميل Supabase + أنواع DB
│   ├── store/                  # Zustand (الجلسة، الملف، اللغة)
│   ├── components/             # واجهة مشتركة (Glass, Buttons, Logo…)
│   ├── screens/                # 23 شاشة كاملة
│   └── navigation/             # Root + Auth + Bottom Tabs
├── supabase/
│   ├── migrations/             # جداول + RLS + دوال SQL
│   └── functions/              # Edge Functions (AI, Gifts, Withdraw)
└── render.yaml                 # Blueprint نشر Render
```

## 📱 الشاشات (23)

| # | الشاشة | # | الشاشة |
|---|--------|---|--------|
| 1 | Splash متحركة | 13 | البث المباشر |
| 2 | Onboarding (4 شرائح) | 14 | الإشعارات |
| 3 | تسجيل الدخول | 15 | البحث والهاشتاقات |
| 4 | إنشاء الحساب | 16 | إنشاء منشور |
| 5 | تحقق OTP | 17 | الإعدادات (عربي/إنجليزي) |
| 6 | شاشة الختام | 18 | المحفظة والعملات |
| 7 | الصفحة الرئيسية | 19 | لوحة الإدارة |
| 8 | الريلز | 20 | المحادثات |
| 9 | القصص + العارض | 21 | غرفة الدردشة (Realtime) |
| 10 | البروفايل + الإحصائيات | 22 | مكالمة صوتية |
| 11 | تعديل الملف | 23 | مكالمة فيديو |
| 12 | المحفظة | | |

## 🗄️ قاعدة البيانات (22 جدولاً)

`profiles, follows, posts, post_likes, comments, saved_posts, stories, story_views, reels, reel_likes, conversations, conversation_members, messages, notifications, streams, gifts, gifts_sent, coin_transactions, reports, blocks, ads, rate_limits`

كل الجداول محمية بـ **Row Level Security** + دوال SQL آمنة: `toggle_post_like`, `buy_coins`, `send_gift`.

## 🔒 الأمان

- Supabase Auth (Email+OTP، OAuth: Google/Apple/Facebook)
- RLS على كل جدول
- Rate limiting table + Edge Functions للتحقق من العملات من جانب السيرفر
- مفاتيح الخدمة (service_role) **لا تُخزَّن** في التطبيق إطلاقاً

## ⚠️ ملاحظات إنتاجية

- **WebRTC (المكالمات/البث الحقيقي)**: يتطلب EAS dev build + مزوّد TURN/LiveKit/Agora — الشاشات الحالية جاهزة كواجهة.
- **شراء العملات الحقيقي**: اربط `buy_coins` ببوابة دفع (Stripe IAP/RevenueCat) قبل الإطلاق.
