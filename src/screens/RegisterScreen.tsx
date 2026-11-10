import React, { useState } from "react";
import { View, Text, Pressable, ScrollView, Alert, Image } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import * as ImagePicker from "expo-image-picker";
import { GradientButton, Input, GlassCard, s } from "../components/ui";
import { supabase } from "../lib/supabase";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { AuthParams } from "../navigation/AuthStack";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function RegisterScreen({ navigation }: NativeStackScreenProps<AuthParams, "Register">) {
  const { t } = useI18n();
  const [form, setForm] = useState({ full_name: "", username: "", email: "", phone: "", password: "" });
  const [avatar, setAvatar] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof form, v: string) => setForm((f) => ({ ...f, [k]: v }));

  const pick = async () => {
    const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.7 });
    if (!r.canceled) setAvatar(r.assets[0].uri);
  };

  const register = async () => {
    if (!form.email || !form.password || !form.username) return Alert.alert("", t("signUpSub"));
    setBusy(true);
    const { data, error } = await supabase.auth.signUp({
      email: form.email, password: form.password,
      options: { data: { full_name: form.full_name, username: form.username, phone: form.phone } },
    });
    setBusy(false);
    if (error) return Alert.alert("⚠️", error.message);
    (navigation as any).navigate("Otp", { email: form.email });
  };

  return (
    <LinearGradient colors={["#0D0E15", "#1A1233", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", padding: 24, gap: 16 }}>
        <Text style={[s.title, { textAlign: "center" }]}>{t("signUpTitle")}</Text>
        <Text style={[s.sub, { textAlign: "center" }]}>{t("signUpSub")}</Text>
        <Pressable onPress={pick} style={{ alignSelf: "center" }}>
          {avatar ? (
            <Image source={{ uri: avatar }} style={{ width: 96, height: 96, borderRadius: 48 }} />
          ) : (
            <LinearGradient colors={[colors.primary, colors.secondary]} style={{ width: 96, height: 96, borderRadius: 48, alignItems: "center", justifyContent: "center" }}>
              <Text style={{ fontSize: 34 }}>📷</Text>
            </LinearGradient>
          )}
        </Pressable>
        <GlassCard style={{ padding: 20, gap: 12 }}>
          <Input icon="🧑" placeholder={t("fullName")} value={form.full_name} onChangeText={(v) => set("full_name", v)} />
          <Input icon="@" placeholder={t("username")} value={form.username} onChangeText={(v) => set("username", v)} autoCapitalize="none" />
          <Input icon="✉️" placeholder={t("email")} value={form.email} onChangeText={(v) => set("email", v)} keyboardType="email-address" />
          <Input icon="📱" placeholder={t("phone")} value={form.phone} onChangeText={(v) => set("phone", v)} keyboardType="phone-pad" />
          <Input icon="🔒" placeholder={t("password")} value={form.password} onChangeText={(v) => set("password", v)} secureTextEntry />
          <GradientButton label={t("createAccount")} onPress={register} busy={busy} />
        </GlassCard>
        <Text style={{ color: colors.muted, textAlign: "center" }}>
          <Text onPress={() => navigation.goBack()} style={{ color: colors.accent, fontWeight: "700" }}>
            {t("login")}
          </Text>
        </Text>
      </ScrollView>
    </LinearGradient>
  );
}
