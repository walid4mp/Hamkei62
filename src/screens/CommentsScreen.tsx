import React, { useEffect, useState } from "react";
import { View, Text, TextInput, Pressable, FlatList, KeyboardAvoidingView, Platform, Alert } from "react-native";
import { supabase } from "../lib/supabase";
import { useAppStore } from "../store/useAppStore";
import { Avatar, s } from "../components/ui";
import { colors } from "../theme";

export function CommentsScreen({ route }: any) {
  const postId = route?.params?.postId as string;
  const me = useAppStore((st: any) => st.profile);
  const [rows, setRows] = useState<any[]>([]);
  const [value, setValue] = useState("");
  const [busy, setBusy] = useState(false);
  const load = async () => {
    if (!postId) return;
    const { data, error } = await supabase.from("comments")
      .select("id,content,created_at,user_id,profiles:profiles!comments_user_id_fkey(username,full_name,avatar_url)")
      .eq("post_id", postId).order("created_at", { ascending: true });
    if (error) Alert.alert("تعذر تحميل التعليقات", error.message);
    setRows(data ?? []);
  };
  useEffect(() => { load(); }, [postId]);
  const send = async () => {
    const content = value.trim();
    if (!content || !me?.id || !postId || busy) return;
    setBusy(true);
    const { error } = await supabase.rpc("add_comment", { p_post: postId, p_content: content });
    setBusy(false);
    if (error) return Alert.alert("تعذر إرسال التعليق", error.message);
    setValue("");
    load();
  };
  return (
    <KeyboardAvoidingView style={s.screen} behavior={Platform.OS === "ios" ? "padding" : undefined} keyboardVerticalOffset={80}>
      <Text style={{ color: "#fff", fontSize: 22, fontWeight: "900", padding: 16 }}>التعليقات</Text>
      <FlatList data={rows} keyExtractor={x => x.id} onRefresh={load} refreshing={false}
        ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center", marginTop: 40 }}>لا توجد تعليقات بعد. كن أول من يعلق.</Text>}
        renderItem={({ item }) => (
          <View style={{ flexDirection: "row", gap: 10, paddingHorizontal: 16, paddingVertical: 12 }}>
            <Avatar uri={item.profiles?.avatar_url} size={38} />
            <View style={{ flex: 1, backgroundColor: colors.surface, borderRadius: 14, padding: 12 }}>
              <Text style={{ color: "#fff", fontWeight: "800" }}>{item.profiles?.full_name || item.profiles?.username || "مستخدم"}</Text>
              <Text style={{ color: "#fff", marginTop: 5 }}>{item.content}</Text>
            </View>
          </View>
        )} />
      <View style={{ flexDirection: "row", gap: 8, padding: 12, borderTopWidth: 1, borderTopColor: colors.border }}>
        <TextInput value={value} onChangeText={setValue} placeholder="اكتب تعليقاً..." placeholderTextColor={colors.muted}
          style={{ flex: 1, color: "#fff", backgroundColor: colors.surface2, borderRadius: 22, paddingHorizontal: 16, minHeight: 46 }} />
        <Pressable onPress={send} disabled={!value.trim() || busy} style={{ backgroundColor: colors.primary, borderRadius: 24, paddingHorizontal: 18, justifyContent: "center" }}>
          <Text style={{ color: "#fff", fontWeight: "800" }}>{busy ? "..." : "إرسال"}</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}
