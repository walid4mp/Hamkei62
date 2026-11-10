import React, { useState } from "react";
import { View, Text, Pressable, TextInput, ScrollView, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import * as ImagePicker from "expo-image-picker";
import { supabase } from "../lib/supabase";
import { GradientButton, GlassCard, Row, s } from "../components/ui";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export function CreatePostScreen({ navigation }: any) {
  const { t } = useI18n();
  const profile = useAppStore((st) => st.profile);
  const [text, setText] = useState("");
  const [media, setMedia] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  const pick = async () => {
    const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.7, allowsMultipleSelection: true });
    if (!r.canceled) setMedia(r.assets.map((a) => a.uri));
  };

  const share = async () => {
    if (!profile || (!text.trim() && !media.length)) return Alert.alert("", t("whatsOnYourMind"));
    setBusy(true);
    let urls: string[] = [];
    for (const uri of media) {
      const ext = uri.split(".").pop() ?? "jpg";
      const path = `posts/${profile.id}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
      const res = await fetch(uri);
      const blob = await res.blob();
      const { error: upErr } = await supabase.storage.from("media").upload(path, blob, { contentType: blob.type });
      if (!upErr) urls.push(`${process.env.EXPO_PUBLIC_SUPABASE_URL}/storage/v1/object/public/media/${path}`);
    }
    const { error } = await supabase.from("posts").insert({
      user_id: profile.id, content: text, media_urls: urls, media_type: urls.length ? (media[0].endsWith(".mp4") ? "video" : "image") : "text",
    });
    setBusy(false);
    if (error) return Alert.alert("⚠️", error.message);
    setText("");
    setMedia([]);
    Alert.alert("✅", "تم النشر!");
  };

  return (
    <LinearGradient colors={["#0D0E15", "#141B3A", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ padding: 18, paddingTop: 60, gap: 16 }}>
        <Row>
          <Text style={{ color: "#fff", fontSize: 20, fontWeight: "900", flex: 1 }}>{t("create")}</Text>
          <GradientButton label={t("share")} onPress={share} busy={busy} style={{ paddingHorizontal: 24, paddingVertical: 0 }} labelStyle={{ fontSize: 14 }} />
        </Row>
        <GlassCard style={{ padding: 16, gap: 12 }}>
          <Row gap={10}>
            <Text style={{ fontSize: 30 }}>🧑</Text>
            <Text style={{ color: "#fff", fontWeight: "700" }}>{profile?.username ?? "أنت"}</Text>
          </Row>
          <TextInput
            value={text}
            onChangeText={setText}
            placeholder={t("whatsOnYourMind")}
            placeholderTextColor={colors.muted}
            multiline
            style={{ color: "#fff", minHeight: 100, fontSize: 16, textAlignVertical: "top" }}
          />
          <Pressable onPress={pick} style={{ borderWidth: 1.5, borderStyle: "dashed", borderColor: colors.primary, borderRadius: 16, padding: 22, alignItems: "center" }}>
            <Text style={{ color: colors.accent }}>🖼 {t("addMedia")}</Text>
            {media.length > 0 && <Text style={{ color: colors.muted, marginTop: 6 }}>{media.length} ملف</Text>}
          </Pressable>
        </GlassCard>
        <View style={{ flexDirection: "row", justifyContent: "space-around", backgroundColor: colors.surface2, borderRadius: 20, padding: 14, borderWidth: 1, borderColor: colors.border }}>
          {[[t("photo"), "🖼"], [t("video"), "🎥"], [t("location"), "📍"], [t("poll"), "📊"], [t("feeling"), "😊"]].map(([l, g], i) => (
            <Pressable key={i} style={{ alignItems: "center", gap: 4 }}>
              <Text style={{ fontSize: 20 }}>{g}</Text>
              <Text style={{ color: colors.muted, fontSize: 11 }}>{l}</Text>
            </Pressable>
          ))}
        </View>
        <Pressable onPress={() => navigation.navigate("Stories")} style={{ alignItems: "center", padding: 10 }}>
          <Text style={{ color: colors.accent }}>✨ إنشاء قصة جديدة</Text>
        </Pressable>
      </ScrollView>
    </LinearGradient>
  );
}
