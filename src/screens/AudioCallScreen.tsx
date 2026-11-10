import React, { useEffect, useState } from "react";
import { View, Text, Pressable } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { useAnimatedStyle, useSharedValue, withRepeat, withTiming, Easing, FadeInUp } from "react-native-reanimated";
import { Avatar, GradientButton, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function AudioCallScreen({ navigation }: NativeStackScreenProps<RootParams, "AudioCall">) {
  const { t } = useI18n();
  const name = (navigation.getState().routes.at(-1)?.params as any)?.name ?? "Sara Mohammed";
  const [sec, setSec] = useState(24);
  const [muted, setMuted] = useState(false);
  const scale = useSharedValue(1);
  useEffect(() => {
    scale.value = withRepeat(withTiming(1.15, { duration: 1200, easing: Easing.inOut(Easing.ease) }), -1, true);
    const id = setInterval(() => setSec((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const wave = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const mm = String(Math.floor(sec / 60)).padStart(2, "0");
  const ss = String(sec % 60).padStart(2, "0");

  return (
    <LinearGradient colors={["#0D0E15", "#1B1240", "#0D0E15"]} style={[s.screen, { alignItems: "center", justifyContent: "center", gap: 20 }]}>
      <Animated.View entering={FadeInUp.springify()} style={{ alignItems: "center", gap: 10 }}>
        <Animated.View style={wave}><Avatar ring size={120} /></Animated.View>
        <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900" }}>{name}</Text>
        <Text style={{ color: colors.accent }}>{mm}:{ss}</Text>
        <View style={{ flexDirection: "row", alignItems: "flex-end", gap: 4, height: 40, marginTop: 10 }}>
          {[10, 22, 34, 26, 16, 30, 20, 12].map((h, i) => (
            <View key={i} style={{ width: 4, height: h, borderRadius: 2, backgroundColor: colors.secondary }} />
          ))}
        </View>
      </Animated.View>
      <View style={{ flexDirection: "row", gap: 16, marginTop: 40 }}>
        <Pressable onPress={() => setMuted((m) => !m)} style={{ width: 62, height: 62, borderRadius: 31, backgroundColor: muted ? colors.danger : colors.surface2, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 22 }}>{muted ? "🔇" : "🎙"}</Text>
        </Pressable>
        <Pressable style={{ width: 62, height: 62, borderRadius: 31, backgroundColor: colors.surface2, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 22 }}>🔊</Text>
        </Pressable>
        <Pressable style={{ width: 62, height: 62, borderRadius: 31, backgroundColor: colors.surface2, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 22 }}>➕</Text>
        </Pressable>
        <Pressable onPress={() => navigation.goBack()} style={{ width: 62, height: 62, borderRadius: 31, backgroundColor: colors.danger, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 22 }}>📴</Text>
        </Pressable>
      </View>
      <Text style={{ color: colors.muted, fontSize: 11, marginTop: 20 }}>WebRTC — يتطلب EAS dev build + TURN</Text>
    </LinearGradient>
  );
}
