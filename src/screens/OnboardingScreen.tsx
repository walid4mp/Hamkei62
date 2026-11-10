import React, { useRef, useState } from "react";
import { View, Text, Pressable, Dimensions, FlatList } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown } from "react-native-reanimated";
import { GradientButton, GlassCard, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

const { width } = Dimensions.get("window");
const slides = [
  { emoji: "🌍", ar: "اكتشف عالمك الجديد", en: "Discover your new world", sub_ar: "تواصل • شارك • استكشف • استمتع", sub_en: "Connect • Share • Explore • Enjoy" },
  { emoji: "🎬", ar: "ريلز وقصص بلا حدود", en: "Endless reels & stories", sub_ar: "محتوى قصير يوافق ذوقك", sub_en: "Short content tuned to your taste" },
  { emoji: "💬", ar: "دردشة ومكالمات فورية", en: "Instant chat & calls", sub_ar: "رسائل، مكالمات صوت وفيديو، وبث مباشر", sub_en: "Messages, voice/video calls, live streams" },
  { emoji: "🎁", ar: "ادعم صنّاع المحتوى", en: "Support creators", sub_ar: "أرسل الهدايا وكن جزءاً من رحلتهم", sub_en: "Send gifts and join their journey" },
];

export function OnboardingScreen({ navigation }: NativeStackScreenProps<RootParams, "Onboarding">) {
  const { t, lang } = useI18n();
  const ref = useRef<FlatList>(null);
  const [i, setI] = useState(0);

  return (
    <LinearGradient colors={["#0D0E15", "#171233", "#0D0E15"]} style={s.screen}>
      <FlatList
        ref={ref}
        data={slides}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        keyExtractor={(_, k) => String(k)}
        onMomentumScrollEnd={(e) => setI(Math.round(e.nativeEvent.contentOffset.x / width))}
        renderItem={({ item, index }) => (
          <View style={{ width, paddingHorizontal: 24, alignItems: "center", justifyContent: "center", gap: 22 }}>
            <GlassCard style={{ padding: 30, alignItems: "center", gap: 14, width: width - 60 }}>
              <Text style={{ fontSize: 72 }}>{item.emoji}</Text>
              <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900", textAlign: "center" }}>{lang === "ar" ? item.ar : item.en}</Text>
              <Text style={{ color: colors.muted, fontSize: 15, textAlign: "center" }}>{lang === "ar" ? item.sub_ar : item.sub_en}</Text>
            </GlassCard>
          </View>
        )}
      />
      <View style={{ flexDirection: "row", justifyContent: "center", gap: 8, marginBottom: 20 }}>
        {slides.map((_, k) => (
          <View key={k} style={{ width: k === i ? 24 : 8, height: 8, borderRadius: 4, backgroundColor: k === i ? colors.accent : colors.surface2 }} />
        ))}
      </View>
      <Animated.View entering={FadeInDown.duration(500)} style={{ paddingHorizontal: 24, paddingBottom: 40, gap: 12 }}>
        <GradientButton label={i === slides.length - 1 ? t("start") : t("next")} onPress={() => (i === slides.length - 1 ? navigation.replace("Auth") : ref.current?.scrollToIndex({ index: i + 1 }))} />
        <Pressable onPress={() => navigation.replace("Auth")} style={{ alignItems: "center", padding: 8 }}>
          <Text style={{ color: colors.muted }}>{t("later")}</Text>
        </Pressable>
      </Animated.View>
    </LinearGradient>
  );
}
