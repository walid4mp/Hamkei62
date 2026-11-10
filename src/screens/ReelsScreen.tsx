import React, { useEffect, useRef, useState } from "react";
import { View, Text, FlatList, Pressable, ActivityIndicator, Dimensions, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { VideoView, useVideoPlayer } from "expo-video";
import * as ImagePicker from "expo-image-picker";
import { supabase, uploadMedia } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { Avatar, Empty, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Reel, Profile } from "../lib/database.types";

const H = Dimensions.get("window").height;

export function ReelsScreen() {
  const { t } = useI18n();
  const me = useAppStore((st: any) => st.profile);
  const [reels, setReels] = useState<Reel[]>([]);
  const [loading, setLoading] = useState(true);
  const [active, setActive] = useState(0);
  const [uploading, setUploading] = useState(false);
  const listRef = useRef<FlatList>(null);

  const load = async () => {
    setLoading(true);
    const { data } = await supabase
      .from("reels").select("*, profiles:profiles!reels_user_id_fkey(*)")
      .order("created_at", { ascending: false }).limit(20);
    setReels((data as Reel[]) ?? []);
    setLoading(false);
  };
  useEffect(() => { load(); }, []);

  const upload = async () => {
    if (!me) return Alert.alert("", "سجّل الدخول أولاً");
    const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Videos, quality: 0.8 });
    if (r.canceled) return;
    setUploading(true);
    const url = await uploadMedia("media", `reels/${me.id}/${Date.now()}.mp4`, r.assets[0].uri);
    if (!url) { setUploading(false); return Alert.alert("⚠️", "فشل رفع الفيديو"); }
    const cap = await new Promise<string>((res) => Alert.prompt?.("وصف الريل", "اكتب الوصف والوسوم", res, undefined, "") ?? res(""));
    const { error } = await supabase.from("reels").insert({ user_id: me.id, video_url: url, caption: cap || "" });
    setUploading(false);
    if (error) return Alert.alert("⚠️", error.message);
    Alert.alert("✅", "تم نشر الريل!");
    load();
  };

  const like = async (r: Reel) => { await supabase.rpc("toggle_reel_like", { p_reel: r.id }); load(); };
  const del = (r: Reel) => r.user_id !== me?.id ? null :
    Alert.alert("حذف الريل", "", [{ text: "إلغاء", style: "cancel" }, { text: "حذف", style: "destructive", onPress: async () => { await supabase.from("reels").delete().eq("id", r.id); load(); } }]);

  if (loading) return <View style={[s.screen, { alignItems: "center", justifyContent: "center" }]}><ActivityIndicator color={colors.accent} /></View>;

  return (
    <View style={s.screen}>
      <FlatList
        ref={listRef}
        data={reels}
        pagingEnabled
        keyExtractor={(r) => r.id}
        onViewableItemsChanged={({ viewableItems }) => { if (viewableItems[0]) setActive(viewableItems[0].index ?? 0); }}
        viewabilityConfig={{ itemVisiblePercentThreshold: 80 }}
        renderItem={({ item, index }) => (
          <ReelItem reel={item} active={index === active} onLike={like} onDelete={del} isMine={item.user_id === me?.id} />
        )}
        ListEmptyComponent={<Empty text="لا توجد ريلز بعد 🎬" />}
      />
      <Pressable onPress={upload} disabled={uploading} style={{ position: "absolute", bottom: 84, insetInlineStart: 18, backgroundColor: colors.primary, borderRadius: 999, paddingHorizontal: 18, paddingVertical: 12, shadowColor: "#000", shadowOpacity: 0.4, shadowRadius: 8, shadowOffset: { width: 0, height: 4 } }}>
        <Text style={{ color: "#fff", fontWeight: "800" }}>{uploading ? "…جارٍ الرفع" : "＋ ريل جديد"}</Text>
      </Pressable>
    </View>
  );
}

function ReelItem({ reel, active, onLike, onDelete, isMine }: any) {
  const { t } = useI18n();
  const player = useVideoPlayer(reel.video_url || "https://example.com/none.mp4", (p) => { p.loop = true; p.muted = false; });
  useEffect(() => {
    if (active && reel.video_url) player.play(); else player.pause();
  }, [active]);
  useEffect(() => { if (active) supabase.rpc("record_reel_view", { p_reel: reel.id }).then(() => {}); }, [active]);
  const p = reel.profiles as Profile | undefined;

  return (
    <View style={{ height: H, backgroundColor: "#000" }}>
      {reel.video_url ? (
        <VideoView player={player} style={{ width: "100%", height: "100%" }} contentFit="contain" />
      ) : (
        <LinearGradient colors={["#1a1a2e", "#0d0e15"]} style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 60 }}>🎥</Text>
        </LinearGradient>
      )}
      <View style={{ position: "absolute", bottom: 100, insetInlineEnd: 14, gap: 20, alignItems: "center" }}>
        <Pressable onPress={() => onLike(reel)}><Text style={{ fontSize: 26 }}>❤️</Text><Text style={{ color: "#fff", fontSize: 11, textAlign: "center" }}>{reel.like_count}</Text></Pressable>
        <Pressable><Text style={{ fontSize: 26 }}>💬</Text><Text style={{ color: "#fff", fontSize: 11, textAlign: "center" }}>{reel.comment_count}</Text></Pressable>
        <Pressable><Text style={{ fontSize: 26 }}>↗️</Text><Text style={{ color: "#fff", fontSize: 11, textAlign: "center" }}>{reel.share_count}</Text></Pressable>
        {isMine && <Pressable onPress={() => onDelete(reel)}><Text style={{ fontSize: 22 }}>🗑</Text></Pressable>}
      </View>
      <LinearGradient colors={["transparent", "rgba(0,0,0,0.85)"]} style={{ position: "absolute", bottom: 0, left: 0, right: 0, paddingTop: 30, padding: 16, paddingBottom: 90 }}>
        <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
          <Avatar uri={p?.avatar_url} size={38} ring />
          <Text style={{ color: "#fff", fontWeight: "800" }}>@{p?.username ?? "user"}</Text>
          <View style={{ borderRadius: 999, borderWidth: 1, borderColor: colors.accent, paddingHorizontal: 12, paddingVertical: 3 }}>
            <Text style={{ color: colors.accent, fontSize: 12, fontWeight: "700" }}>{t("follow")}</Text>
          </View>
        </View>
        {!!reel.caption && <Text style={{ color: "#fff", marginTop: 6 }}>{reel.caption}</Text>}
      </LinearGradient>
    </View>
  );
}
