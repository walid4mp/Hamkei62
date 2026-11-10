import React, { useEffect, useState } from "react";
import { View, Text, FlatList, Pressable, Image, Alert, ActivityIndicator } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown } from "react-native-reanimated";
import { supabase } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { Avatar, GlassCard, Empty, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Post, Profile } from "../lib/database.types";
import type { RootParams } from "../navigation/RootNavigator";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

const storiesSeed = ["Ahmed", "Sara", "Mohamed", "Lina"];

export function HomeScreen({ navigation }: any) {
  const { t } = useI18n();
  const profile = useAppStore((st) => st.profile);
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [liked, setLiked] = useState<Record<string, boolean>>({});

  const load = async () => {
    setLoading(true);
    const { data } = await supabase
      .from("posts")
      .select("*, profiles:profiles!posts_user_id_fkey(*)")
      .order("created_at", { ascending: false })
      .limit(20);
    setPosts((data as Post[]) ?? []);
    setLoading(false);
  };
  useEffect(() => {
    load();
  }, []);

  const toggleLike = async (p: Post) => {
    setLiked((m) => ({ ...m, [p.id]: !m[p.id] }));
    await supabase.rpc("toggle_post_like", { p_post_id: p.id });
    const me = useAppStore.getState().profile;
    if (!liked[p.id] && me && p.user_id !== me.id) {
      supabase.from("notifications").insert({ user_id: p.user_id, actor_id: me.id, kind: "like", entity_id: p.id }).then(() => {});
    }
    load();
  };

  return (
    <View style={s.screen}>
      <View style={{ paddingTop: 54, paddingHorizontal: 16, paddingBottom: 10, flexDirection: "row", alignItems: "center", justifyContent: "space-between" }}>
        <Text style={{ color: colors.accent, fontSize: 22, fontWeight: "900" }}>{t("appName")}</Text>
        <View style={{ flexDirection: "row", gap: 18 }}>
          <Pressable onPress={() => navigation.navigate("Search")}><Text style={{ fontSize: 20 }}>🔍</Text></Pressable>
          <Pressable onPress={() => navigation.navigate("Notifications")}><Text style={{ fontSize: 20 }}>🔔</Text></Pressable>
          <Pressable onPress={() => navigation.navigate("Settings")}><Text style={{ fontSize: 20 }}>⚙️</Text></Pressable>
        </View>
      </View>

      <FlatList
        data={posts}
        keyExtractor={(item) => item.id}
        onRefresh={load}
        refreshing={loading}
        ListHeaderComponent={
          <View style={{ paddingVertical: 12, paddingHorizontal: 12, gap: 14 }}>
            <FlatList
              horizontal
              showsHorizontalScrollIndicator={false}
              data={storiesSeed}
              keyExtractor={(x) => x}
              contentContainerStyle={{ gap: 14, paddingHorizontal: 4 }}
              renderItem={({ item }) => (
                <Pressable onPress={() => navigation.navigate("StoryViewer", {})} style={{ alignItems: "center", gap: 4 }}>
                  <Avatar ring size={60} />
                  <Text style={{ color: colors.muted, fontSize: 11 }}>{item}</Text>
                </Pressable>
              )}
              ListHeaderComponent={
                <Pressable onPress={() => navigation.navigate("Stories")} style={{ alignItems: "center", gap: 4 }}>
                  <View style={{ width: 60, height: 60, borderRadius: 30, borderWidth: 2, borderColor: colors.primary, alignItems: "center", justifyContent: "center" }}>
                    <Text style={{ color: "#fff", fontSize: 24 }}>＋</Text>
                  </View>
                  <Text style={{ color: colors.muted, fontSize: 11 }}>{t("myStory")}</Text>
                </Pressable>
              }
            />
          </View>
        }
        renderItem={({ item, index }) => {
          const p = item.profiles as Profile | undefined;
          return (
            <Animated.View entering={FadeInDown.delay(index * 60).duration(400)} style={{ paddingHorizontal: 14, marginBottom: 18 }}>
              <GlassCard style={{ padding: 14, gap: 12 }}>
                <View style={{ flexDirection: "row", alignItems: "center", gap: 10 }}>
                  <Pressable onPress={() => p?.id && navigation.navigate("Profile", { screen: "ProfileMain", params: { userId: p.id } })}>
                    <Avatar uri={p?.avatar_url} ring size={44} />
                  </Pressable>
                  <Pressable style={{ flex: 1 }} onPress={() => p?.id && navigation.navigate("Profile", { screen: "ProfileMain", params: { userId: p.id } })}>
                    <Text style={{ color: "#fff", fontWeight: "700" }}>
                      {p?.full_name ?? "مستخدم"} {p?.is_verified ? <Text style={{ color: colors.accent }}>✔︎</Text> : null}
                    </Text>
                    <Text style={{ color: colors.muted, fontSize: 12 }}>@{p?.username ?? "user"}</Text>
                  </Pressable>
                  <Pressable onPress={async () => { const me = useAppStore.getState().profile; if (me && item.user_id !== me.id) { await supabase.rpc("follow_user", { p_target: item.user_id }); Alert.alert(t("follow"), `@${p?.username}`); } }}>
                    <Text style={{ color: colors.accent, fontWeight: "700" }}>{t("follow")}</Text>
                  </Pressable>
                </View>
                {!!item.content && <Text style={{ color: "#fff", lineHeight: 22 }}>{item.content}</Text>}
                {item.media_urls?.length > 0 && (
                  <Image source={{ uri: item.media_urls[0] }} style={{ width: "100%", height: 220, borderRadius: 16 }} resizeMode="cover" />
                )}
                <View style={{ flexDirection: "row", gap: 22, alignItems: "center" }}>
                  <Pressable onPress={() => toggleLike(item)}>
                    <Text style={{ color: liked[item.id] ? colors.danger : "#fff", fontSize: 15 }}>
                      {liked[item.id] ? "❤️" : "🤍"} {(item.like_count ?? 0) + (liked[item.id] ? 1 : 0)}
                    </Text>
                  </Pressable>
                  <Pressable onPress={() => navigation.navigate("Comments", { postId: item.id })}><Text style={{ color: "#fff" }}>💬 {item.comment_count ?? 0}</Text></Pressable>
                  <Pressable><Text style={{ color: "#fff" }}>↗️ {t("share")}</Text></Pressable>
                  <Pressable style={{ marginInlineStart: "auto" }}><Text style={{ color: colors.muted }}>🔖</Text></Pressable>
                </View>
              </GlassCard>
            </Animated.View>
          );
        }}
        ListEmptyComponent={loading ? <ActivityIndicator color={colors.accent} style={{ marginTop: 40 }} /> : <Empty text="لا توجد منشورات بعد — ابدأ بالنشر!" />}
      />
    </View>
  );
}
