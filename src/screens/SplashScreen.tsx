import React, { useEffect } from "react";
import { View, Text } from "react-native";
import * as ExpoSplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown, FadeInUp, withDelay, withTiming, useSharedValue, withSpring, Easing } from "react-native-reanimated";
import { Logo } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function SplashScreen({ navigation }: NativeStackScreenProps<RootParams, "Splash">) {
  const { t } = useI18n();
  const glow = useSharedValue(0.4);
  useEffect(() => {
    glow.value = withDelay(200, withTiming(1, { duration: 1200, easing: Easing.inOut(Easing.ease) }));
    const id = setTimeout(() => {
      ExpoSplashScreen.hideAsync().catch(() => {});
      navigation.replace("Onboarding");
    }, 2200);
    return () => clearTimeout(id);
  }, [navigation, glow]);

  return (
    <LinearGradient colors={["#0D0E15", "#141B3A", "#0D0E15"]} style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <StatusBar style="light" />
      <Animated.View entering={FadeInUp.springify().damping(12)} style={{ alignItems: "center", gap: 18 }}>
        <Logo size={110} />
        <Animated.Text entering={FadeInDown.delay(300).duration(700)} style={{ color: "#fff", fontSize: 30, fontWeight: "900", letterSpacing: 1 }}>
          {t("appName")}
        </Animated.Text>
        <Animated.Text entering={FadeInDown.delay(500).duration(700)} style={{ color: colors.muted, fontSize: 15 }}>
          {t("tagline")}
        </Animated.Text>
      </Animated.View>
      <Animated.View entering={FadeInDown.delay(700).duration(900)} style={{ position: "absolute", bottom: 70, alignItems: "center" }}>
        <View style={{ width: 220, height: 6, borderRadius: 3, backgroundColor: colors.surface2, overflow: "hidden" }}>
          <Animated.View style={{ width: "100%", height: "100%", backgroundColor: colors.accent, opacity: glow }} />
        </View>
        <Text style={{ color: colors.muted, marginTop: 14, fontSize: 12, textAlign: "center" }}>{t("splashTagline")}</Text>
      </Animated.View>
    </LinearGradient>
  );
}
