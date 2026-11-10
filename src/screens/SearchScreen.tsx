import React, { useEffect, useState } from "react";
import { View, Text, FlatList, Pressable, TextInput } from "react-native";
import { supabase } from "../lib/supabase";
import { Avatar, GlassCard, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Profile } from "../lib/database.types";

const trending = [
  { tag: "#Travel", n: "1.2M منشور" },
  { tag: "#Fitness", n: "856K منشور" },
  { tag: "#Food", n: "1.1M منشور" },
  { tag: "#Technology", n: "742K منشور" },
];

function FollowBtn({ targetId, targetName }: { targetId: string; targetName: string }) {
  const { t } = useI18n();
  const [state, setState] = useState<"none" | "pending" | "following">("none");
  const go = async () => {
    if (state === "following") {
      await supabase.rpc("unfollow_user", { p_target: targetId });
      setState("none");
    } else {
      const { data } = await supabase.rpc("follow_user", { p_target: targetId });
      setState(data === "pending" ? "pending" : "following");
    }
  };
  return (
    <Pressable onPress={go} style={{ borderRadius: 999, borderWidth: 1, borderColor: colors.accent, paddingHorizontal: 14, paddingVertical: 5 }}>
      <Text style={{ color: colors.accent, fontSize: 12, fontWeight: "700" }}>
        {state === "following" ? t("following2") : state === "pending" ? "⏳" : t("follow")}
      </Text>
    </Pressable>
  );
}

export function SearchScreen({ navigation }: any) {
  const { t } = useI18n();
  const [q, setQ] = useState("");
  const [users, setUsers] = useState<Profile[]>([]);
  const [tab, setTab] = useState<"all" | "users" | "tags">("all");

  useEffect(() => {
    if (q.trim().length < 2) return setUsers([]);
    supabase.from("profiles").select("*").ilike("username", `%${q}%`).limit(10).then(({ data }) => setUsers((data as Profile[]) ?? []));
  }, [q]);

  return (
    <View style={[s.screen, { paddingTop: 54, paddingHorizontal: 14 }]}>
      <TextInput
        value={q}
        onChangeText={setQ}
        placeholder={t("searchPlaceholder")}
        placeholderTextColor={colors.muted}
        style={{ backgroundColor: colors.surface2, borderRadius: 16, paddingHorizontal: 16, height: 48, color: "#fff", borderWidth: 1, borderColor: colors.border }}
      />
      <View style={{ flexDirection: "row", gap: 8, marginVertical: 12 }}>
        {([["all", t("all")], ["users", t("users")], ["tags", t("hashtags")]] as const).map(([k, l]) => (
          <Pressable key={k} onPress={() => setTab(k)} style={{ paddingHorizontal: 16, paddingVertical: 7, borderRadius: 999, backgroundColor: tab === k ? colors.primary : colors.surface2, borderWidth: 1, borderColor: colors.border }}>
            <Text style={{ color: tab === k ? "#fff" : colors.muted, fontSize: 13 }}>{l}</Text>
          </Pressable>
        ))}
      </View>
      {tab !== "tags" && users.map((u) => (
        <View key={u.id} style={{ flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 8 }}>
          <Pressable onPress={() => navigation.navigate("Profile", { screen: "ProfileMain", params: { userId: u.id } })}>
            <Avatar uri={u.avatar_url} size={44} />
          </Pressable>
          <Pressable style={{ flex: 1 }} onPress={() => navigation.navigate("Profile", { screen: "ProfileMain", params: { userId: u.id } })}>
            <Text style={{ color: "#fff", fontWeight: "700" }}>{u.full_name ?? u.username} {u.is_verified ? <Text style={{ color: colors.accent }}>✔︎</Text> : null}</Text>
            <Text style={{ color: colors.muted, fontSize: 12 }}>@{u.username}</Text>
          </Pressable>
          <FollowBtn targetId={u.id} targetName={u.username} />
        </View>
      ))}
      {tab !== "users" && (
        <View style={{ marginTop: 10, gap: 8 }}>
          <Text style={{ color: "#fff", fontWeight: "800" }}>{t("suggestions")}</Text>
          {trending.map((x) => (
            <GlassCard key={x.tag} style={{ padding: 14, flexDirection: "row", justifyContent: "space-between", alignItems: "center" }}>
              <Text style={{ color: colors.accent, fontWeight: "800" }}>{x.tag}</Text>
              <Text style={{ color: colors.muted, fontSize: 12 }}>{x.n}</Text>
            </GlassCard>
          ))}
        </View>
      )}
    </View>
  );
}
