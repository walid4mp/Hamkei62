import React, { createContext, useContext } from "react";
import { I18nManager } from "react-native";
import { useAppStore } from "../store/useAppStore";
import { applyRTL, type Lang } from "./rtl";

const dict = {
  ar: {
    appName: "SocialPlus", tagline: "أكثر من تواصل", splashTagline: "ربط الناس… نبني عالماً أفضل",
    welcomeBack: "مرحباً بعودتك", loginToContinue: "سجّل الدخول للمتابعة", email: "البريد الإلكتروني",
    password: "كلمة المرور", rememberMe: "تذكرني", forgotPassword: "نسيت كلمة المرور؟",
    login: "تسجيل الدخول", orContinueWith: "أو تابع عبر", noAccount: "ليس لديك حساب؟", createAccount: "إنشاء حساب",
    signUpTitle: "إنشاء حساب", signUpSub: "انضم إلى عالم جديد من التواصل", fullName: "الاسم الكامل",
    username: "اسم المستخدم", phone: "رقم الهاتف", avatar: "الصورة الشخصية",
    otpTitle: "تحقق من بريدك الإلكتروني", otpSentTo: "أدخل رمز التحقق المرسل إلى", verify: "تحقق",
    resendIn: "إعادة إرسال الرمز بعد", changeEmail: "تغيير البريد الإلكتروني",
    onboardingTitle: "اكتشف عالمك الجديد", onboardingSub: "تواصل • شارك • استكشف • استمتع", next: "التالي", start: "لنبدأ الآن",
    home: "الرئيسية", reels: "ريلز", create: "منشور", search: "البحث", chats: "المحادثات", profile: "البروفايل",
    stories: "القصص", myStory: "قصتي", notifications: "الإشعارات", settings: "الإعدادات",
    posts: "المنشورات", followers: "المتابعون", following: "المتابعة", editProfile: "تعديل الملف الشخصي",
    verified: "موثّق", whatsOnYourMind: "ماذا يدور في ذهنك؟", addMedia: "إضافة صور/فيديو",
    share: "مشاركة", photo: "صورة", video: "فيديو", location: "موقع", poll: "تصويت", feeling: "شعور",
    all: "الكل", unread: "غير مقروء", groups: "المجموعات", typeMessage: "اكتب رسالة…",
    wallet: "محفظتي", coins: "عملة", buyCoins: "شراء عملات", transactions: "سجل العمليات",
    transfer: "تحويل", withdraw: "سحب", sendGift: "إرسال هدية", topSupporters: "أفضل الداعمين",
    live: "مباشر", viewers: "مشاهد", addComment: "أضف تعليق…", follow: "متابعة", following2: "متابَع",
    searchPlaceholder: "ابحث عن مستخدمين، منشورات، هاشتاقات…", users: "المستخدمون", hashtags: "الهاشتاقات",
    suggestions: "مقترحات لك", account: "الحساب", privacy: "الخصوصية والأمان", appearance: "المظهر",
    language: "اللغة", help: "المساعدة والدعم", about: "حول التطبيق", logout: "تسجيل الخروج",
    blockedUsers: "المستخدمون المحظورون", devices: "إدارة الأجهزة", deleteAccount: "حذف الحساب",
    admin: "لوحة الإدارة", manageUsers: "إدارة المستخدمين", managePosts: "إدارة المنشورات",
    reports: "البلاغات", ads: "الإعلانات", gifts: "الهدايا والعملات", analytics: "الإحصائيات",
    activeUsers: "مستخدم نشط", totalUsers: "إجمالي المستخدمين", callEnded: "انتهت المكالمة",
    incomingCall: "مكالمة واردة", calling: "جارٍ الاتصال…", mute: "كتم", speaker: "مكبر",
    endCall: "إنهاء", camera: "كاميرا", thanks: "شكراً لكونك معنا", thanksSub: "معاً نصنع مجتمعاً أفضل ✨",
    later: "لاحقاً", trending: "رائج الآن", remix: "ريمكس", download: "تنزيل", save: "حفظ",
    originalSound: "الصوت الأصلي", newHighlight: "جديد", bio: "نبذة",
  },
  en: {
    appName: "SocialPlus", tagline: "More than social", splashTagline: "Connecting People — Creating a Better World",
    welcomeBack: "Welcome back", loginToContinue: "Sign in to continue", email: "Email",
    password: "Password", rememberMe: "Remember me", forgotPassword: "Forgot password?",
    login: "Log in", orContinueWith: "Or continue with", noAccount: "No account?", createAccount: "Create account",
    signUpTitle: "Create account", signUpSub: "Join a new world of connection", fullName: "Full name",
    username: "Username", phone: "Phone number", avatar: "Profile photo",
    otpTitle: "Verify your email", otpSentTo: "Enter the code sent to", verify: "Verify",
    resendIn: "Resend code in", changeEmail: "Change email",
    onboardingTitle: "Discover your new world", onboardingSub: "Connect • Share • Explore • Enjoy", next: "Next", start: "Let's start",
    home: "Home", reels: "Reels", create: "Post", search: "Search", chats: "Chats", profile: "Profile",
    stories: "Stories", myStory: "My story", notifications: "Notifications", settings: "Settings",
    posts: "Posts", followers: "Followers", following: "Following", editProfile: "Edit profile",
    verified: "Verified", whatsOnYourMind: "What's on your mind?", addMedia: "Add photo/video",
    share: "Share", photo: "Photo", video: "Video", location: "Location", poll: "Poll", feeling: "Feeling",
    all: "All", unread: "Unread", groups: "Groups", typeMessage: "Type a message…",
    wallet: "My wallet", coins: "coins", buyCoins: "Buy coins", transactions: "Transactions",
    transfer: "Transfer", withdraw: "Withdraw", sendGift: "Send gift", topSupporters: "Top supporters",
    live: "LIVE", viewers: "viewers", addComment: "Add a comment…", follow: "Follow", following2: "Following",
    searchPlaceholder: "Search users, posts, hashtags…", users: "Users", hashtags: "Hashtags",
    suggestions: "Suggestions for you", account: "Account", privacy: "Privacy & security", appearance: "Appearance",
    language: "Language", help: "Help & support", about: "About", logout: "Log out",
    blockedUsers: "Blocked users", devices: "Devices", deleteAccount: "Delete account",
    admin: "Admin dashboard", manageUsers: "Users", managePosts: "Posts",
    reports: "Reports", ads: "Ads", gifts: "Gifts & coins", analytics: "Analytics",
    activeUsers: "Active", totalUsers: "Total users", callEnded: "Call ended",
    incomingCall: "Incoming call", calling: "Calling…", mute: "Mute", speaker: "Speaker",
    endCall: "End", camera: "Camera", thanks: "Thanks for being with us", thanksSub: "Together we build a better community ✨",
    later: "Later", trending: "Trending now", remix: "Remix", download: "Download", save: "Save",
    originalSound: "Original sound", newHighlight: "New", bio: "Bio",
  },
} as const;

export type { Lang } from "./rtl";
export type TKey = keyof typeof dict["ar"];

const Ctx = createContext<{ t: (k: TKey) => string; lang: Lang; isRTL: boolean; setLang: (l: Lang) => void }>({
  t: (k) => dict.ar[k],
  lang: "ar",
  isRTL: true,
  setLang: () => {},
});

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const lang = useAppStore((s) => s.lang);
  const setLang = useAppStore((s) => s.setLang);
  return <Ctx.Provider value={{ t: (k) => dict[lang][k], lang, isRTL: lang === "ar", setLang }}>{children}</Ctx.Provider>;
}

export const useI18n = () => useContext(Ctx);
