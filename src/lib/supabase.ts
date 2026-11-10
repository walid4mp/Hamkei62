import "react-native-url-polyfill/auto";
import { createClient } from "@supabase/supabase-js";
import AsyncStorage from "@react-native-async-storage/async-storage";

const url = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "https://iugcevwsgxmomqjbgqoq.supabase.co";
const anon = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "sb_publishable_gk7nR55Sc-pSWGE1QYTBdw_XEJeSL9Q";

export const supabase = createClient(url, anon, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
    storage: AsyncStorage, // الجلسة تُحفظ باسم آمن وتُستعاد عند فتح التطبيق
  },
});
export const SUPABASE_URL = url;

// رفع ملف إلى bucket مع إرجاع الرابط العام
export async function uploadMedia(bucket: "media", path: string, uri: string): Promise<string | null> {
  try {
    const res = await fetch(uri);
    const blob = await res.blob();
    const clean = path.replace(/[^a-zA-Z0-9._\/-]/g, "_");
    const { error } = await supabase.storage.from(bucket).upload(clean, blob, { upsert: true, contentType: blob.type || "application/octet-stream" });
    if (error) return null;
    return `${url}/storage/v1/object/public/${bucket}/${clean}`;
  } catch {
    return null;
  }
}
