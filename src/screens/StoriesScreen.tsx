import React, { useEffect, useState } from "react";
import { View, Text, FlatList, Pressable, Image, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import * as ImagePicker from "expo-image-picker";
import { supabase, uploadMedia } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { GlassCard, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Story, Profile } from "../lib/database.types";

export function StoriesScreen({ navigation }: any) {
  const { t } = useI18n();
  const me = useAppStore((st: any) => st.profile);
  const [stories, setStories] = useState<Story[]>([]);
  const [uploading, setUploading] = useState(false);

  const load = async () => {
    const { data } = await supabase
      .from("stories").select("*, profiles:profiles!stories_user_id_fkey(*)")
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false });
    setStories((data as Story[]) ?? []);
  };
  useEffect(() => { load(); }, []);

  const createStory = async () => {
    if (!me) return Alert.alert("", "سجّل الدخول أولاً");
    const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.7 });
    if (r.canceled) return;
    setUploading(true);
    const url = await uploadMedia("media", `stories/${me.id}/${Date.now()}.jpg`, r.assets[0].uri);
    setUploading(false);
    if (!url) return Alert.alert("⚠️", "فشل رفع القصة");
    const { error } = await supabase.from("stories").insert({ user_id: me.id, media_url: url });
    if (error) return Alert.alert("⚠️", error.message);
    Alert.alert("✅", "تم نشر القصة (تختفي بعد 24 ساعة)");
    load();
  };

  return (
    <View style={[s.screen, { paddingTop: 54, paddingHorizontal: 14 }]}>
      <View style={{ flexDirection: "row", alignItems: "center", marginBottom: 14 }}>
        <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900", flex: 1 }}>{t("stories")}</Text>
        <Pressable onPress={createStory} disabled={uploading} style={{ backgroundColor: colors.primary, borderRadius: 999, paddingHorizontal: 16, paddingVertical: 8 }}>
          <Text style={{ color: "#fff", fontWeight: "800", fontSize: 13 }}>{uploading ? "…" : "＋ قصة جديدة"}</Text>
        </Pressable>
      </View>
      <FlatList
        data={stories}
        numColumns={2}
        keyExtractor={(x) => x.id}
        columnWrapperStyle={{ gap: 12, marginBottom: 12 }}
        renderItem={({ item }) => {
          const p = item.profiles as Profile | undefined;
          const mine = item.user_id === me?.id;
          return (
            <Pressable onPress={() => navigation.navigate("StoryViewer", { userId: item.user_id })} style={{ flex: 1 }}>
              <GlassCard style={{ overflow: "hidden" }}>
                {item.media_url ? (
                  <Image source={{ uri: item.media_url }} style={{ width: "100%", height: 200 }} resizeMode="cover" />
                ) : (
                  <LinearGradient colors={[colors.primary, colors.secondary]} style={{ height: 200, alignItems: "center", justifyContent: "center" }}>
                    <Text style={{ fontSize: 40 }}>✨</Text>
                  </LinearGradient>
                )}
                <View style={{ padding: 10, flexDirection: "row", alignItems: "center", gap: 8 }}>
                  <Text style={{ fontSize: 18 }}>🧑</Text>
                  <Text style={{ color: "#fff", fontWeight: "700", fontSize: 13, flex: 1 }} numberOfLines={1}>{p?.username ?? "story"}</Text>
                  {mine && (
                    <Pressable onPress={() => Alert.alert("حذف القصة", "", [{ text: "إلغاء", style: "cancel" }, { text: "حذف", style: "destructive", onPress: async () => { await supabase.from("stories").delete().eq("id", item.id); load(); } }])}>
                      <Text>🗑</Text>
                    </Pressable>
                  )}
                </View>
              </GlassCard>
            </Pressable>
          );
        }}
        ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center", marginTop: 40 }}>لا توجد قصص نشطة</Text>}
      />
    </View>
  );
}
