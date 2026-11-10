import React, { useCallback, useEffect, useState } from "react";
import { View, Text, FlatList, Pressable, TextInput, Modal, ActivityIndicator, Alert } from "react-native";
import { useAppStore } from "../store/useAppStore";
import { supabase } from "../lib/supabase";
import { Avatar, Input, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";

type ChatRow = { id: string; title: string | null; is_group: boolean; last_message: string | null; updated_at: string };
type UserRow = { id: string; username: string; full_name: string | null; avatar_url: string | null };

export function ChatsScreen({ navigation }: any) {
  const { t } = useI18n();
  const me = useAppStore((st: any) => st.profile);
  const [filter, setFilter] = useState<"all" | "groups">("all");
  const [q, setQ] = useState("");
  const [chats, setChats] = useState<ChatRow[]>([]);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [groupOpen, setGroupOpen] = useState(false);
  const [groupName, setGroupName] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!me?.id) { setChats([]); setLoading(false); return; }
    setLoading(true);
    const { data, error } = await supabase.from("conversations")
      .select("id,title,is_group,last_message,updated_at,conversation_members!inner(user_id)")
      .eq("conversation_members.user_id", me.id)
      .order("updated_at", { ascending: false });
    if (error) Alert.alert("تعذر تحميل المحادثات", error.message);
    setChats((data as any[] ?? []).map(({ conversation_members, ...c }) => c));
    setLoading(false);
  }, [me?.id]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => {
    const term = q.trim().replace(/^@/, "");
    if (term.length < 2) { setUsers([]); return; }
    let active = true;
    const timer = setTimeout(async () => {
      const { data, error } = await supabase.from("profiles")
        .select("id,username,full_name,avatar_url")
        .ilike("username", `%${term}%`).neq("id", me?.id ?? "").limit(15);
      if (active) setUsers(error ? [] : (data as UserRow[] ?? []));
    }, 250);
    return () => { active = false; clearTimeout(timer); };
  }, [q, me?.id]);

  const openDirect = async (user: UserRow) => {
    if (!me?.id || busy) return;
    setBusy(true);
    const { data, error } = await supabase.rpc("create_direct_conversation", { p_other_user: user.id });
    setBusy(false);
    if (error || !data) return Alert.alert("تعذر بدء المحادثة", error?.message ?? "حاول مرة أخرى");
    navigation.navigate("ChatRoom", { conversationId: data, title: user.full_name || user.username });
    setQ(""); setUsers([]);
    load();
  };

  const createGroup = async () => {
    if (!me?.id || !groupName.trim() || busy) return;
    setBusy(true);
    const { data, error } = await supabase.rpc("create_group_conversation", { p_title: groupName.trim() });
    setBusy(false);
    if (error || !data) return Alert.alert("تعذر إنشاء المجموعة", error?.message ?? "حاول مرة أخرى");
    const title = groupName.trim();
    setGroupName(""); setGroupOpen(false);
    await load();
    navigation.navigate("ChatRoom", { conversationId: data, title });
  };

  const visible = chats.filter(c => filter === "all" || c.is_group);
  return (
    <View style={[s.screen, { paddingTop: 54, paddingHorizontal: 14 }]}>
      <View style={{ flexDirection: "row", alignItems: "center", marginBottom: 12 }}>
        <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900", flex: 1 }}>{t("chats")}</Text>
        <Pressable onPress={() => setGroupOpen(true)} style={{ backgroundColor: colors.primary, borderRadius: 999, paddingHorizontal: 14, paddingVertical: 9 }}>
          <Text style={{ color: "#fff", fontWeight: "800" }}>＋ مجموعة</Text>
        </Pressable>
      </View>
      <Input icon="🔍" placeholder="ابحث عن شخص لبدء محادثة" value={q} onChangeText={setQ} />
      {!!q.trim() && (
        <View style={{ backgroundColor: colors.surface, borderRadius: 14, marginTop: 8, paddingHorizontal: 12 }}>
          {users.map(u => (
            <Pressable key={u.id} onPress={() => openDirect(u)} style={{ flexDirection: "row", alignItems: "center", gap: 10, paddingVertical: 10 }}>
              <Avatar uri={u.avatar_url} size={42} />
              <View style={{ flex: 1 }}>
                <Text style={{ color: "#fff", fontWeight: "700" }}>{u.full_name || u.username}</Text>
                <Text style={{ color: colors.muted }}>@{u.username}</Text>
              </View>
              <Text style={{ color: colors.accent }}>رسالة</Text>
            </Pressable>
          ))}
          {!users.length && <Text style={{ color: colors.muted, padding: 12 }}>اكتب اسم مستخدم من حرفين على الأقل</Text>}
        </View>
      )}
      <View style={{ flexDirection: "row", gap: 8, marginVertical: 12 }}>
        {([["all", "الكل"], ["groups", "المجموعات"]] as const).map(([k, label]) => (
          <Pressable key={k} onPress={() => setFilter(k)} style={{ paddingHorizontal: 16, paddingVertical: 8, borderRadius: 999, backgroundColor: filter === k ? colors.primary : colors.surface2, borderWidth: 1, borderColor: colors.border }}>
            <Text style={{ color: filter === k ? "#fff" : colors.muted, fontWeight: "700" }}>{label}</Text>
          </Pressable>
        ))}
      </View>
      <Modal visible={groupOpen} transparent animationType="fade" onRequestClose={() => setGroupOpen(false)}>
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.75)", alignItems: "center", justifyContent: "center", padding: 26 }}>
          <View style={{ backgroundColor: colors.surface, borderRadius: 20, padding: 20, alignSelf: "stretch", gap: 14 }}>
            <Text style={{ color: "#fff", fontWeight: "800", fontSize: 18 }}>إنشاء مجموعة جديدة</Text>
            <TextInput value={groupName} onChangeText={setGroupName} placeholder="اسم المجموعة" placeholderTextColor={colors.muted} style={{ backgroundColor: colors.surface2, borderRadius: 12, height: 48, paddingHorizontal: 12, color: "#fff" }} />
            <Text style={{ color: colors.muted, fontSize: 12 }}>يمكنك إضافة الأعضاء من داخل المحادثة بعد الإنشاء.</Text>
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Pressable onPress={() => setGroupOpen(false)} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.surface2, alignItems: "center" }}><Text style={{ color: "#fff" }}>إلغاء</Text></Pressable>
              <Pressable disabled={!groupName.trim() || busy} onPress={createGroup} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.primary, alignItems: "center" }}><Text style={{ color: "#fff", fontWeight: "700" }}>{busy ? "..." : "إنشاء"}</Text></Pressable>
            </View>
          </View>
        </View>
      </Modal>
      {loading ? <ActivityIndicator color={colors.accent} style={{ marginTop: 30 }} /> : (
        <FlatList
          data={visible}
          keyExtractor={item => item.id}
          onRefresh={load}
          refreshing={loading}
          ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center", marginTop: 40 }}>لا توجد محادثات بعد. ابحث عن شخص لبدء محادثة.</Text>}
          renderItem={({ item }) => (
            <Pressable onPress={() => navigation.navigate("ChatRoom", { conversationId: item.id, title: item.title || (item.is_group ? "مجموعة" : "محادثة") })} style={{ flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: colors.border }}>
              <Avatar size={50} />
              <View style={{ flex: 1 }}>
                <Text style={{ color: "#fff", fontWeight: "700" }}>{item.title || (item.is_group ? "مجموعة" : "محادثة")}</Text>
                <Text style={{ color: colors.muted, fontSize: 13 }} numberOfLines={1}>{item.last_message || "ابدأ المحادثة..."}</Text>
              </View>
              <Text style={{ color: colors.muted, fontSize: 11 }}>{new Date(item.updated_at).toLocaleDateString()}</Text>
            </Pressable>
          )}
        />
      )}
    </View>
  );
}
