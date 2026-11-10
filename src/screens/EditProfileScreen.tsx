import React, { useState } from "react";
import { View, Text, ScrollView, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { GradientButton, Input, s } from "../components/ui";
import { supabase } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function EditProfileScreen({ navigation }: NativeStackScreenProps<RootParams, "EditProfile">) {
  const { t } = useI18n();
  const profile = useAppStore((st) => st.profile);
  const refresh = useAppStore((st) => st.refreshProfile);
  const [form, setForm] = useState({
    full_name: profile?.full_name ?? "", username: profile?.username ?? "",
    bio: profile?.bio ?? "", website: profile?.website ?? "", phone: profile?.phone ?? "",
  });
  const set = (k: keyof typeof form, v: string) => setForm((f) => ({ ...f, [k]: v }));

  const save = async () => {
    if (!profile) return;
    const { error } = await supabase.from("profiles").update(form).eq("id", profile.id);
    if (error) return Alert.alert("⚠️", error.message);
    await refresh();
    navigation.goBack();
  };

  return (
    <LinearGradient colors={["#0D0E15", "#141B3A", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 70, gap: 14 }}>
        <Text style={s.title}>{t("editProfile")}</Text>
        <Input icon="🧑" placeholder={t("fullName")} value={form.full_name} onChangeText={(v) => set("full_name", v)} />
        <Input icon="@" placeholder={t("username")} value={form.username} onChangeText={(v) => set("username", v)} />
        <Input icon="📝" placeholder={t("bio")} value={form.bio} onChangeText={(v) => set("bio", v)} multiline />
        <Input icon="🔗" placeholder="Website" value={form.website} onChangeText={(v) => set("website", v)} />
        <Input icon="📱" placeholder={t("phone")} value={form.phone} onChangeText={(v) => set("phone", v)} />
        <GradientButton label={t("share")} onPress={save} />
      </ScrollView>
    </LinearGradient>
  );
}
