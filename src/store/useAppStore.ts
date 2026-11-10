import { create } from "zustand";
import { supabase } from "../lib/supabase";
import type { Profile } from "../lib/database.types";
import { applyRTL, type Lang } from "../i18n/rtl";

export type Session = Awaited<ReturnType<typeof supabase.auth.getSession>>["data"]["session"];

interface AppState {
  lang: Lang;
  session: Session | null;
  profile: Profile | null;
  isAdmin: boolean;
  hydrated: boolean;
  setLang: (l: Lang) => void;
  setSession: (s: Session | null) => void;
  setProfile: (p: Profile | null) => void;
  refreshProfile: () => Promise<void>;
}

export const useAppStore = create<AppState>((set, get) => ({
  lang: "ar",
  session: null,
  profile: null,
  isAdmin: false,
  hydrated: false,
  setLang: (l) => {
    applyRTL(l);
    set({ lang: l });
  },
  setSession: (s) => set({ session: s, hydrated: true }),
  setProfile: (p) => set({ profile: p, isAdmin: p?.is_admin ?? false }),
  refreshProfile: async () => {
    const s = get().session;
    if (!s) return set({ profile: null, isAdmin: false });
    const { data } = await supabase.from("profiles").select("*").eq("id", s.user.id).single();
    set({ profile: (data as Profile) ?? null, isAdmin: (data as Profile)?.is_admin ?? false });
  },
}));
