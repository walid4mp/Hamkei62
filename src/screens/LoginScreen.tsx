import React, { useState } from "react";
import { View, Text, Pressable, ScrollView, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { GradientButton, Input, GlassCard, Logo, s } from "../components/ui";
import { supabase } from "../lib/supabase";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { AuthParams } from "../navigation/AuthStack";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function LoginScreen({ navigation }: NativeStackScreenProps<AuthParams, "Login">) {
  const { t } = useI18n();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);

  const login = async () => {
    if (!email || !password) return Alert.alert("", t("loginToContinue"));
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) Alert.alert("⚠️", error.message);
  };

  const social = async (provider: "google" | "apple" | "facebook") => {
    await supabase.auth.signInWithOAuth({ provider, options: { redirectTo: "socialplus://auth" } });
  };

  return (
    <LinearGradient colors={["#0D0E15", "#141B3A", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ flexGrow: 1, justifyContent: "center", padding: 24, gap: 16 }}>
        <View style={{ alignItems: "center", gap: 10, marginBottom: 10 }}>
          <Logo size={84} />
          <Text style={s.title}>{t("welcomeBack")}</Text>
          <Text style={s.sub}>{t("loginToContinue")}</Text>
        </View>
        <GlassCard style={{ padding: 20, gap: 14 }}>
          <Input icon="✉️" placeholder={t("email")} value={email} onChangeText={setEmail} keyboardType="email-address" />
          <Input icon="🔒" placeholder={t("password")} value={password} onChangeText={setPassword} secureTextEntry />
          <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
            <Text style={{ color: colors.muted }}>☑ {t("rememberMe")}</Text>
            <Pressable onPress={() => supabase.auth.resetPasswordForEmail(email)}>
              <Text style={{ color: colors.accent, fontSize: 13 }}>{t("forgotPassword")}</Text>
            </Pressable>
          </View>
          <GradientButton label={t("login")} onPress={login} busy={busy} />
          <View style={{ flexDirection: "row", alignItems: "center", gap: 10, marginVertical: 4 }}>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
            <Text style={{ color: colors.muted, fontSize: 12 }}>{t("orContinueWith")}</Text>
            <View style={{ flex: 1, height: 1, backgroundColor: colors.border }} />
          </View>
          <View style={{ flexDirection: "row", justifyContent: "center", gap: 16 }}>
            {[["🇬", "google"], ["", "apple"], ["🇫", "facebook"]].map(([g, p]) => (
              <Pressable key={p} onPress={() => social(p as any)} style={{ width: 54, height: 54, borderRadius: 16, backgroundColor: colors.surface2, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: colors.border }}>
                <Text style={{ fontSize: 22, color: "#fff" }}>{g}</Text>
              </Pressable>
            ))}
          </View>
        </GlassCard>
        <Text style={{ color: colors.muted, textAlign: "center" }}>
          {t("noAccount")}{" "}
          <Text onPress={() => navigation.push("Register")} style={{ color: colors.accent, fontWeight: "700" }}>
            {t("createAccount")}
          </Text>
        </Text>
      </ScrollView>
    </LinearGradient>
  );
}
