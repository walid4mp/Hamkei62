import React, { useEffect, useState } from "react";
import { View, Text, Pressable, Image, ScrollView, Alert } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import * as ImagePicker from "expo-image-picker";
import { supabase, uploadMedia } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { Avatar, GradientButton, Empty, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Post, Profile } from "../lib/database.types";

export function ProfileScreen({ navigation, route }: any) {
  const { t } = useI18n();
  const me = useAppStore((st: any) => st.profile);
  const refresh = useAppStore((st: any) => st.refreshProfile);
  const viewId: string | undefined = route?.params?.userId;
  const isMe = !viewId || viewId === me?.id;
  const [user, setUser] = useState<Profile | null>(isMe ? me : null);
  const [posts, setPosts] = useState<Post[]>([]);
  const [stats, setStats] = useState({ followers: 0, following: 0, posts: 0 });
  const [followState, setFollowState] = useState<"none" | "pending" | "following">("none");

  useEffect(() => {
    const uid = isMe ? me?.id : viewId;
    if (!uid) return;
    (async () => {
      if (!isMe) {
        const { data } = await supabase.from("profiles").select("*").eq("id", viewId).single();
        setUser(data as Profile);
        const { data: f } = await supabase.from("follows").select("status").eq("follower_id", me.id).eq("following_id", viewId).maybeSingle();
        setFollowState((f as any)?.status === "accepted" ? "following" : (f as any)?.status === "pending" ? "pending" : "none");
      }
      const [{ data: pp }, { count: fc }, { count: fg }, { count: pc }] = await Promise.all([
        supabase.from("posts").select("*").eq("user_id", uid).order("created_at", { ascending: false }),
        supabase.from("follows").select("*", { count: "exact", head: true }).eq("following_id", uid).eq("status", "accepted"),
        supabase.from("follows").select("*", { count: "exact", head: true }).eq("follower_id", uid).eq("status", "accepted"),
        supabase.from("posts").select("*", { count: "exact", head: true }).eq("user_id", uid),
      ]);
      setPosts((pp as Post[]) ?? []);
      setStats({ followers: fc ?? 0, following: fg ?? 0, posts: pc ?? 0 });
    })();
  }, [viewId, me?.id]);

  const pickImage = async (kind: "avatar" | "cover") => {
    if (!isMe || !me) return;
    const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ImagePicker.MediaTypeOptions.Images, quality: 0.7 });
    if (r.canceled) return;
    const url = await uploadMedia("media", `${me.id}/${kind}-${Date.now()}.jpg`, r.assets[0].uri);
    if (!url) return Alert.alert("⚠️", "فشل رفع الصورة");
    const { error } = await supabase.from("profiles").update(kind === "avatar" ? { avatar_url: url } : { cover_url: url }).eq("id", me.id);
    if (error) return Alert.alert("⚠️", error.message);
    await refresh();
  };

  const toggleFollow = async () => {
    if (!me || isMe || !user) return;
    if (followState === "none") {
      const { data } = await supabase.rpc("follow_user", { p_target: user.id });
      setFollowState(data === "pending" ? "pending" : "following");
    } else {
      await supabase.rpc("unfollow_user", { p_target: user.id });
      setFollowState("none");
    }
  };

  const block = () =>
    Alert.alert("حظر المستخدم", `حظر @${user?.username}؟`, [
      { text: "إلغاء", style: "cancel" },
      { text: "حظر", style: "destructive", onPress: async () => {
        await supabase.from("blocks").insert({ blocker_id: me.id, blocked_id: user!.id });
        await supabase.rpc("unfollow_user", { p_target: user!.id });
        Alert.alert("✅", "تم الحظر"); navigation.goBack();
      } },
    ]);

  const report = () =>
    Alert.prompt?.("الإبلاغ", "سبب البلاغ؟", async (reason: string) => {
      if (!reason) return;
      await supabase.from("reports").insert({ reporter_id: me.id, entity_type: "user", entity_id: user!.id, reason });
      Alert.alert("✅", "تم إرسال البلاغ");
    }) ?? Alert.alert("", "البلاغ متاح قريباً على هذا الجهاز");

  if (!user) return <View style={s.screen}><Empty text="الملف الشخصي" /></View>;

  return (
    <ScrollView style={s.screen} contentContainerStyle={{ paddingBottom: 90 }}>
      <Pressable onPress={() => isMe && pickImage("cover")}>
        {user.cover_url ? (
          <Image source={{ uri: user.cover_url }} style={{ width: "100%", height: 150, backgroundColor: colors.surface2 }} />
        ) : (
          <LinearGradient colors={[colors.primary, colors.secondary]} style={{ width: "100%", height: 150 }} />
        )}
      </Pressable>
      <View style={{ paddingHorizontal: 16, marginTop: -50 }}>
        <View style={{ flexDirection: "row", alignItems: "flex-end", gap: 12 }}>
          <Pressable onPress={() => isMe && pickImage("avatar")}>
            <Avatar uri={user.avatar_url} size={96} ring />
          </Pressable>
          <View style={{ flex: 1, alignItems: "flex-end", paddingBottom: 6, gap: 6 }}>
            {isMe ? (
              <GradientButton label={t("editProfile")} onPress={() => navigation.navigate("EditProfile")} style={{ paddingVertical: 0 }} labelStyle={{ fontSize: 13 }} />
            ) : (
              <View style={{ flexDirection: "row", gap: 8 }}>
                <Pressable onPress={toggleFollow} style={{ borderRadius: 999, paddingHorizontal: 18, paddingVertical: 8, backgroundColor: followState === "none" ? colors.primary : colors.surface2, borderWidth: 1, borderColor: followState === "none" ? colors.primary : colors.border }}>
                  <Text style={{ color: "#fff", fontWeight: "700", fontSize: 13 }}>
                    {followState === "following" ? t("following2") : followState === "pending" ? "⏳ طلب مُرسل" : t("follow")}
                  </Text>
                </Pressable>
                <Pressable onPress={block} style={{ borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8, backgroundColor: colors.surface2, borderWidth: 1, borderColor: colors.border }}>
                  <Text style={{ color: colors.danger, fontSize: 13 }}>🚫</Text>
                </Pressable>
                <Pressable onPress={report} style={{ borderRadius: 999, paddingHorizontal: 14, paddingVertical: 8, backgroundColor: colors.surface2, borderWidth: 1, borderColor: colors.border }}>
                  <Text style={{ color: colors.muted, fontSize: 13 }}>🚩</Text>
                </Pressable>
              </View>
            )}
          </View>
        </View>
        <View style={{ flexDirection: "row", alignItems: "center", gap: 6, marginTop: 10 }}>
          <Text style={{ color: "#fff", fontSize: 20, fontWeight: "900" }}>{user.full_name}</Text>
          {!!user.is_verified && <Text style={{ color: colors.accent, fontSize: 16 }}>✔︎ {t("verified")}</Text>}
          {!!user.is_private && <Text style={{ color: colors.muted, fontSize: 12 }}>🔒 خاص</Text>}
          {user.is_banned && <Text style={{ color: colors.danger, fontSize: 12 }}>محظور</Text>}
        </View>
        <Text style={{ color: colors.muted }}>@{user.username}</Text>
        {!!user.bio && <Text style={{ color: "#fff", marginTop: 8, lineHeight: 20 }}>{user.bio}</Text>}
        <View style={{ flexDirection: "row", marginTop: 18, justifyContent: "space-around" }}>
          {[[stats.posts, t("posts")], [stats.followers, t("followers")], [stats.following, t("following")]].map(([n, l], i) => (
            <View key={i} style={{ alignItems: "center" }}>
              <Text style={{ color: "#fff", fontSize: 18, fontWeight: "900" }}>{String(n)}</Text>
              <Text style={{ color: colors.muted, fontSize: 12 }}>{String(l)}</Text>
            </View>
          ))}
        </View>
        {isMe && (
          <View style={{ flexDirection: "row", gap: 12, marginTop: 20 }}>
            <Pressable onPress={() => navigation.navigate("Wallet")} style={{ flex: 1, backgroundColor: colors.surface2, borderRadius: 16, padding: 14, alignItems: "center", borderWidth: 1, borderColor: colors.border }}>
              <Text style={{ fontSize: 20 }}>🪙</Text>
              <Text style={{ color: "#fff", marginTop: 4 }}>{me?.coins ?? 0} {t("coins")}</Text>
            </Pressable>
            <Pressable onPress={() => navigation.navigate("Settings")} style={{ flex: 1, backgroundColor: colors.surface2, borderRadius: 16, padding: 14, alignItems: "center", borderWidth: 1, borderColor: colors.border }}>
              <Text style={{ fontSize: 20 }}>⚙️</Text>
              <Text style={{ color: "#fff", marginTop: 4 }}>{t("settings")}</Text>
            </Pressable>
          </View>
        )}
        <Text style={{ color: "#fff", fontWeight: "800", marginTop: 22, marginBottom: 10 }}>{t("posts")}</Text>
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 4 }}>
          {posts.map((p) => (
            <View key={p.id} style={{ width: "32%", aspectRatio: 1, borderRadius: 10, backgroundColor: colors.surface2, alignItems: "center", justifyContent: "center" }}>
              {p.media_urls?.[0] ? <Image source={{ uri: p.media_urls[0] }} style={{ width: "100%", height: "100%", borderRadius: 10 }} /> : <Text style={{ color: colors.muted }}>Aa</Text>}
            </View>
          ))}
        </View>
        {!isMe && posts.length === 0 && !!user.is_private && followState !== "following" && (
          <Text style={{ color: colors.muted, textAlign: "center", marginTop: 20 }}>🔒 هذا الحساب خاص — تابع للحصول على الموافقة</Text>
        )}
      </View>
    </ScrollView>
  );
}
