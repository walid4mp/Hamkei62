import React, { useEffect, useState } from "react";
import { View, Text, Pressable, TextInput, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown } from "react-native-reanimated";
import { GradientButton, s } from "../components/ui";
import { supabase } from "../lib/supabase";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function OtpScreen({ navigation }: NativeStackScreenProps<RootParams, "Otp">) {
  const { t } = useI18n();
  const email = (navigation.getState().routes.at(-1)?.params as any)?.email ?? "";
  const [code, setCode] = useState(["", "", "", ""]);
  const [sec, setSec] = useState(45);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const id = setInterval(() => setSec((s) => (s > 0 ? s - 1 : 0)), 1000);
    return () => clearInterval(id);
  }, []);

  const verify = async () => {
    setBusy(true);
    await supabase.auth.verifyOtp({ email, token: code.join(""), type: "email" }).catch(() => {});
    setBusy(false);
    navigation.replace("Outro");
  };

  return (
    <LinearGradient colors={["#0D0E15", "#12224A", "#0D0E15"]} style={[s.screen, { alignItems: "center", justifyContent: "center", padding: 24, gap: 18 }]}>
      <Animated.View entering={FadeInDown.springify()} style={{ alignItems: "center", gap: 10 }}>
        <Text style={{ fontSize: 64 }}>📬</Text>
        <Text style={s.title}>{t("otpTitle")}</Text>
        <Text style={s.sub}>{t("otpSentTo")} {email || "example@mail.com"}</Text>
      </Animated.View>
      <View style={{ flexDirection: "row", gap: 12 }}>
        {code.map((c, k) => (
          <TextInput
            key={k}
            value={c}
            onChangeText={(v) => {
              const n = v.replace(/[^0-9]/g, "").slice(-1);
              setCode((p) => p.map((x, i) => (i === k ? n : x)));
            }}
            keyboardType="number-pad"
            maxLength={1}
            style={{ width: 58, height: 64, borderRadius: 16, backgroundColor: colors.surface2, borderWidth: 1.5, borderColor: c ? colors.accent : colors.border, color: "#fff", fontSize: 26, fontWeight: "800", textAlign: "center" }}
          />
        ))}
      </View>
      <Text style={{ color: colors.muted }}>{t("resendIn")} 00:{String(sec).padStart(2, "0")}</Text>
      <GradientButton label={t("verify")} onPress={verify} busy={busy} style={{ alignSelf: "stretch" }} />
      <Pressable onPress={() => navigation.goBack()}>
        <Text style={{ color: colors.accent }}>{t("changeEmail")}</Text>
      </Pressable>
    </LinearGradient>
  );
}
