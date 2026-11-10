import React, { useState, useEffect } from "react";
import { View, Text, Pressable, ScrollView, Alert, Switch, TextInput } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { supabase } from "../lib/supabase";
import { GlassCard, GradientButton, s } from "../components/ui";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

function Input(props: any) {
  return (
    <View style={{ backgroundColor: "rgba(38,42,62,0.6)", borderRadius: 14, borderWidth: 1, borderColor: "rgba(139,92,246,0.25)", paddingHorizontal: 12, height: 48, justifyContent: "center" }}>
      <TextInput {...props} placeholderTextColor={colors.muted} style={{ color: "#fff", fontSize: 14 }} />
    </View>
  );
}

export function SettingsScreen({ navigation }: any) {
  const { t, lang, setLang } = useI18n();
  const me = useAppStore((st) => st.profile);
  const isAdmin = useAppStore((st) => st.isAdmin);
  const [notif, setNotif] = useState(true);
  const [privateAcc, setPrivateAcc] = useState(false);
  const [newPass, setNewPass] = useState("");
  const [busy, setBusy] = useState(false);
  const [priv, setPriv] = useState({ is_private: false, allow_messages: "everyone" as string, show_online: true });
  const [blocked, setBlocked] = useState<{ blocked_id: string; username?: string }[]>([]);

  useEffect(() => {
    if (!me) return;
    setPriv({ is_private: !!me.is_private, allow_messages: me.allow_messages ?? "everyone", show_online: me.show_online !== false });
  }, [me?.id]);

  const savePriv = async (patch: Record<string, any>) => {
    if (!me) return;
    setPriv((p) => ({ ...p, ...patch }));
    await supabase.from("profiles").update(patch).eq("id", me.id);
  };

  const changePass = async () => {
    if (newPass.length < 6) return Alert.alert("⚠️", "كلمة المرور 6 أحرف على الأقل");
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: newPass });
    setBusy(false);
    setNewPass("");
    Alert.alert(error ? "⚠️" : "✅", error ? error.message : "تم تغيير كلمة المرور");
  };

  const loadBlocked = async () => {
    if (!me) return;
    const { data } = await supabase.from("blocks").select("blocked_id, profiles:profiles!blocks_blocked_id_fkey(username)").eq("blocker_id", me.id);
    setBlocked(((data as any) ?? []).map((x: any) => ({ blocked_id: x.blocked_id, username: x.profiles?.username })));
  };

  const Item = ({ icon, label, onPress, danger }: any) => (
    <Pressable onPress={onPress} style={{ flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 13, borderBottomWidth: 1, borderBottomColor: colors.border }}>
      <Text style={{ fontSize: 18 }}>{icon}</Text>
      <Text style={{ color: danger ? colors.danger : "#fff", flex: 1, fontSize: 15 }}>{label}</Text>
      <Text style={{ color: colors.muted }}>‹</Text>
    </Pressable>
  );

  const logout = async () => {
    await supabase.auth.signOut();
    Alert.alert("✅", t("logout"));
  };

  return (
    <LinearGradient colors={["#0D0E15", "#101427", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ padding: 18, paddingTop: 60, gap: 16 }}>
        <Text style={s.title}>{t("settings")}</Text>
        <GlassCard style={{ padding: 16 }}>
          <Item icon="👤" label={t("account")} onPress={() => navigation.navigate?.("EditProfile") ?? null} />
          <Item icon="🔒" label={t("privacy")} onPress={() => {}} />
          <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 13, borderBottomWidth: 1, borderBottomColor: colors.border }}>
            <Text style={{ fontSize: 18, marginRight: 12 }}>🔔</Text>
            <Text style={{ color: "#fff", flex: 1 }}>{t("notifications")}</Text>
            <Switch value={notif} onValueChange={setNotif} trackColor={{ true: colors.primary }} />
          </View>
          <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 13, borderBottomWidth: 1, borderBottomColor: colors.border }}>
            <Text style={{ fontSize: 18, marginRight: 12 }}>🕵️</Text>
            <Text style={{ color: "#fff", flex: 1 }}>حساب خاص</Text>
            <Switch value={privateAcc} onValueChange={setPrivateAcc} trackColor={{ true: colors.primary }} />
          </View>
        </GlassCard>
        <GlassCard style={{ padding: 16 }}>
          <Text style={{ color: "#fff", fontWeight: "800", marginBottom: 8 }}>🔒 {t("privacy")}</Text>
          <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border }}>
            <Text style={{ color: "#fff", flex: 1 }}>حساب خاص (موافقة المتابعين)</Text>
            <Switch value={priv.is_private} onValueChange={(v) => savePriv({ is_private: v })} trackColor={{ true: colors.primary }} />
          </View>
          <View style={{ flexDirection: "row", alignItems: "center", paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border }}>
            <Text style={{ color: "#fff", flex: 1 }}>إظهار حالة الاتصال</Text>
            <Switch value={priv.show_online} onValueChange={(v) => savePriv({ show_online: v })} trackColor={{ true: colors.primary }} />
          </View>
          <Text style={{ color: colors.muted, fontSize: 12, marginTop: 8 }}>من يمكنه مراسلتي</Text>
          <View style={{ flexDirection: "row", gap: 8, marginTop: 6 }}>
            {([["everyone", "الجميع"], ["following", "من أتابعهم"], ["nobody", "لا أحد"]] as const).map(([k, l]) => (
              <Pressable key={k} onPress={() => savePriv({ allow_messages: k })} style={{ flex: 1, padding: 10, borderRadius: 12, backgroundColor: priv.allow_messages === k ? colors.primary : colors.surface2, alignItems: "center" }}>
                <Text style={{ color: "#fff", fontSize: 12 }}>{l}</Text>
              </Pressable>
            ))}
          </View>
        </GlassCard>
        <GlassCard style={{ padding: 16 }}>
          <Text style={{ color: "#fff", fontWeight: "800", marginBottom: 8 }}>🔑 {t("account")}</Text>
          <View style={{ gap: 10 }}>
            <Input icon="🔒" placeholder="كلمة المرور الجديدة" value={newPass} onChangeText={setNewPass} secureTextEntry />
            <GradientButton label="تغيير كلمة المرور" onPress={changePass} busy={busy} />
          </View>
        </GlassCard>
        <GlassCard style={{ padding: 16 }}>
          <Item icon="🚫" label={t("blockedUsers")} onPress={loadBlocked} />
          {blocked.map((b) => (
            <View key={b.blocked_id} style={{ flexDirection: "row", alignItems: "center", paddingVertical: 8 }}>
              <Text style={{ color: "#fff", flex: 1 }}>🚫 @{b.username ?? b.blocked_id.slice(0, 8)}</Text>
              <Pressable onPress={async () => { await supabase.from("blocks").delete().eq("blocker_id", me!.id).eq("blocked_id", b.blocked_id); loadBlocked(); }}>
                <Text style={{ color: colors.accent }}>إلغاء الحظر</Text>
              </Pressable>
            </View>
          ))}
          <Item icon="📱" label={t("devices")} onPress={() => {}} />
          <Item icon="🗑" label={t("deleteAccount")} danger onPress={() => Alert.alert(t("deleteAccount"), "اتصل بالدعم لحذف الحساب نهائياً")} />
        </GlassCard>
        <GlassCard style={{ padding: 16 }}>
          <Text style={{ color: "#fff", fontWeight: "800", marginBottom: 10 }}>{t("language")}</Text>
          <View style={{ flexDirection: "row", gap: 10 }}>
            {(["ar", "en"] as const).map((l) => (
              <Pressable key={l} onPress={() => setLang(l)} style={{ flex: 1, padding: 12, borderRadius: 14, backgroundColor: lang === l ? colors.primary : colors.surface2, alignItems: "center", borderWidth: 1, borderColor: lang === l ? colors.primary : colors.border }}>
                <Text style={{ color: "#fff", fontWeight: "700" }}>{l === "ar" ? "العربية 🇸🇦" : "English 🇬🇧"}</Text>
              </Pressable>
            ))}
          </View>
        </GlassCard>
        {isAdmin && (
          <GlassCard style={{ padding: 16 }}>
            <Item icon="🛡" label={t("admin")} onPress={() => navigation.navigate?.("Admin") ?? null} />
          </GlassCard>
        )}
        <GlassCard style={{ padding: 16 }}>
          <Item icon="❓" label={t("help")} onPress={() => {}} />
          <Item icon="ℹ️" label={`${t("about")} — v1.0.0`} onPress={() => {}} />
          <Item icon="🚪" label={t("logout")} danger onPress={logout} />
        </GlassCard>
      </ScrollView>
    </LinearGradient>
  );
}
