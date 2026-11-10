import React from "react";
import { View, Text, Pressable, TextInput, ActivityIndicator, StyleSheet, ViewStyle, TextStyle } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown, useAnimatedStyle, useSharedValue, withRepeat, withTiming, Easing } from "react-native-reanimated";
import { colors } from "../theme";

export function GlassCard({ children, style }: { children: React.ReactNode; style?: ViewStyle }) {
  return (
    <View
      style={[
        { backgroundColor: "rgba(28,30,46,0.72)", borderRadius: 24, borderWidth: 1, borderColor: "rgba(139,92,246,0.22)", overflow: "hidden" },
        style,
      ]}
    >
      {children}
    </View>
  );
}

export function GradientButton({
  label, onPress, busy, style, labelStyle,
}: { label: string; onPress?: () => void; busy?: boolean; style?: ViewStyle; labelStyle?: TextStyle }) {
  return (
    <Pressable onPress={onPress} disabled={busy} style={[{ borderRadius: 999, overflow: "hidden" }, style]}>
      <LinearGradient colors={[colors.primary, colors.secondary]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingVertical: 15, alignItems: "center", justifyContent: "center" }}>
        {busy ? <ActivityIndicator color="#fff" /> : <Text style={[{ color: "#fff", fontWeight: "700", fontSize: 16 }, labelStyle]}>{label}</Text>}
      </LinearGradient>
    </Pressable>
  );
}

export function Input(props: React.ComponentProps<typeof TextInput> & { icon?: string }) {
  return (
    <View style={{ backgroundColor: "rgba(38,42,62,0.6)", borderRadius: 16, borderWidth: 1, borderColor: "rgba(139,92,246,0.25)", paddingHorizontal: 14, height: 52, justifyContent: "center", flexDirection: "row", alignItems: "center" }}>
      {!!props.icon && <Text style={{ marginRight: 8, fontSize: 16 }}>{props.icon}</Text>}
      <TextInput
        {...props}
        placeholderTextColor={colors.muted}
        style={{ flex: 1, color: "#fff", fontSize: 15 }}
        autoCapitalize={props.autoCapitalize ?? "none"}
      />
    </View>
  );
}

export function Avatar({ uri, size = 44, ring }: { uri?: string | null; size?: number; ring?: boolean }) {
  const inner = (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: colors.surface2, alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
      {uri ? <Animated.Image source={{ uri }} style={{ width: size, height: size }} sharedTransitionTag="avatar" /> : <Text style={{ color: colors.muted, fontSize: size / 3 }}>👤</Text>}
    </View>
  );
  if (!ring) return inner;
  return (
    <View style={{ padding: 2.5, borderRadius: (size + 5) / 2, borderWidth: 2, borderColor: colors.accent }}>
      {inner}
    </View>
  );
}

export function Logo({ size = 96 }: { size?: number }) {
  const rot = useSharedValue(-8);
  React.useEffect(() => {
    rot.value = withRepeat(withTiming(8, { duration: 1600, easing: Easing.inOut(Easing.ease) }), -1, true);
  }, [rot]);
  const style = useAnimatedStyle(() => ({ transform: [{ rotate: `${rot.value}deg` }] }));
  return (
    <Animated.View style={[{ alignItems: "center" }, style]}>
      <LinearGradient colors={[colors.primary, colors.secondary, colors.accent]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ width: size, height: size, borderRadius: size * 0.32, alignItems: "center", justifyContent: "center", shadowColor: colors.secondary, shadowOpacity: 0.6, shadowRadius: 24, shadowOffset: { width: 0, height: 8 } }}>
        <Text style={{ color: "#fff", fontSize: size * 0.5, fontWeight: "900" }}>S</Text>
      </LinearGradient>
    </Animated.View>
  );
}

export function Row({ children, gap = 10, style }: { children: React.ReactNode; gap?: number; style?: ViewStyle }) {
  return <View style={[{ flexDirection: "row", alignItems: "center", gap }, style]}>{children}</View>;
}

export function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <Animated.Text entering={FadeInDown.duration(400)} style={{ color: "#fff", fontSize: 18, fontWeight: "800", marginBottom: 10 }}>
      {children}
    </Animated.Text>
  );
}

export function Empty({ text }: { text: string }) {
  return (
    <View style={{ alignItems: "center", paddingVertical: 48 }}>
      <Text style={{ fontSize: 40, marginBottom: 8 }}>🌌</Text>
      <Text style={{ color: colors.muted }}>{text}</Text>
    </View>
  );
}

export const s = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.bg },
  title: { color: "#fff", fontSize: 26, fontWeight: "900" },
  sub: { color: colors.muted, fontSize: 14 },
});
