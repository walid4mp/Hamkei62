import React, { useEffect, useState } from "react";
import { View, Text, Pressable } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { GradientButton, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function VideoCallScreen({ navigation }: NativeStackScreenProps<RootParams, "VideoCall">) {
  const { t } = useI18n();
  const name = (navigation.getState().routes.at(-1)?.params as any)?.name ?? "Sara";
  const [sec, setSec] = useState(24);
  const [cam, setCam] = useState(true);
  useEffect(() => {
    const id = setInterval(() => setSec((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const mm = String(Math.floor(sec / 60)).padStart(2, "0");
  const ss = String(sec % 60).padStart(2, "0");

  return (
    <LinearGradient colors={["#0a0a14", "#141428", "#0a0a14"]} style={s.screen}>
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", gap: 12 }}>
        <Text style={{ fontSize: 80 }}>🎬</Text>
        <Text style={{ color: "#fff", fontSize: 22, fontWeight: "900" }}>{name}</Text>
        <Text style={{ color: colors.accent }}>{mm}:{ss}</Text>
      </View>
      <View style={{ position: "absolute", top: 70, insetInlineEnd: 16, width: 110, height: 150, borderRadius: 16, backgroundColor: colors.surface2, borderWidth: 1, borderColor: colors.primary, alignItems: "center", justifyContent: "center" }}>
        <Text style={{ fontSize: 34 }}>🧑</Text>
        <Text style={{ color: colors.muted, fontSize: 10, marginTop: 4 }}>أنت</Text>
      </View>
      <View style={{ position: "absolute", top: 70, insetInlineStart: 16, backgroundColor: "rgba(0,0,0,0.5)", paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999 }}>
        <Text style={{ color: "#fff" }}>{mm}:{ss}</Text>
      </View>
      <View style={{ flexDirection: "row", gap: 18, marginBottom: 60, justifyContent: "center" }}>
        {[["🎥", () => setCam((c) => !c)], ["🎙", () => {}], ["🔄", () => {}]].map(([g, fn], i) => (
          <Pressable key={i} onPress={fn as any} style={{ width: 58, height: 58, borderRadius: 29, backgroundColor: "rgba(255,255,255,0.12)", alignItems: "center", justifyContent: "center" }}>
            <Text style={{ fontSize: 22 }}>{g as string}</Text>
          </Pressable>
        ))}
        <Pressable onPress={() => navigation.goBack()} style={{ width: 58, height: 58, borderRadius: 29, backgroundColor: colors.danger, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 22 }}>📴</Text>
        </Pressable>
      </View>
      <Text style={{ color: colors.muted, fontSize: 11, textAlign: "center", marginBottom: 24 }}>WebRTC — يتطلب EAS dev build + TURN/LiveKit</Text>
    </LinearGradient>
  );
}
