import React, { useEffect, useState } from "react";
import { View, Text, FlatList } from "react-native";
import { supabase } from "../lib/supabase";
import { Avatar, s } from "../components/ui";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { NotificationRow, Profile } from "../lib/database.types";

const seed = [
  { id: "1", u: "Ahmed Ali", m: "أعجب بمنشورك", g: "❤️", time: "9:40" },
  { id: "2", u: "Reem", m: "علّق على صورتك", g: "💬", time: "8:15" },
  { id: "3", u: "Omar", m: "بدأ بمتابعتك", g: "🧑‍🤝‍🧑", time: "أمس" },
  { id: "4", u: "Lina", m: "أرسلت لك رسالة", g: "✉️", time: "الأمس" },
  { id: "5", u: "Sara", m: "بدأت بثاً مباشراً 🔴", g: "📡", time: "الأمس" },
];

export function NotificationsScreen() {
  const { t } = useI18n();
  const me = useAppStore((st) => st.profile);
  const [rows, setRows] = useState<NotificationRow[]>([]);

  useEffect(() => {
    if (!me) return;
    supabase
      .from("notifications")
      .select("*, profiles:profiles!notifications_actor_id_fkey(*)")
      .eq("user_id", me.id)
      .order("created_at", { ascending: false })
      .limit(50)
      .then(({ data }) => setRows((data as NotificationRow[]) ?? []));
  }, [me?.id]);

  return (
    <View style={[s.screen, { paddingTop: 54, paddingHorizontal: 14 }]}>
      <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900", marginBottom: 12 }}>{t("notifications")}</Text>
      <FlatList
        data={[...rows.map((r) => ({ id: r.id, u: (r.profiles as Profile)?.username ?? "", m: r.kind, g: "🔔", time: "" })), ...seed]}
        keyExtractor={(x) => x.id}
        renderItem={({ item }) => (
          <View style={{ flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: colors.border }}>
            <Avatar size={44} />
            <View style={{ flex: 1 }}>
              <Text style={{ color: "#fff", fontWeight: "700" }}>{item.u}</Text>
              <Text style={{ color: colors.muted, fontSize: 13 }}>{item.m}</Text>
            </View>
            <Text style={{ fontSize: 18 }}>{item.g}</Text>
            <Text style={{ color: colors.muted, fontSize: 11 }}>{item.time}</Text>
          </View>
        )}
      />
    </View>
  );
}
