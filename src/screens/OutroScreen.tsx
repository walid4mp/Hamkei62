import React from "react";
import { View, Text } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown, FadeInUp } from "react-native-reanimated";
import { GradientButton, Logo, s } from "../components/ui";
import { useI18n } from "../i18n";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function OutroScreen({ navigation }: NativeStackScreenProps<RootParams, "Outro">) {
  const { t } = useI18n();
  return (
    <LinearGradient colors={["#0D0E15", "#1B1440", "#0D0E15"]} style={[s.screen, { alignItems: "center", justifyContent: "center", padding: 24, gap: 20 }]}>
      <Animated.View entering={FadeInUp.springify()}>
        <Logo size={100} />
      </Animated.View>
      <Animated.View entering={FadeInDown.delay(300).duration(700)} style={{ alignItems: "center", gap: 8 }}>
        <Text style={s.title}>{t("thanks")}</Text>
        <Text style={s.sub}>{t("thanksSub")}</Text>
      </Animated.View>
      <Animated.View entering={FadeInDown.delay(600).duration(700)} style={{ alignSelf: "stretch" }}>
        <GradientButton label={t("start")} onPress={() => navigation.replace("Main")} />
      </Animated.View>
    </LinearGradient>
  );
}
