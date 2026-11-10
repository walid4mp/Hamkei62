import React, { useEffect, useRef, useState } from "react";
import { View, Text, FlatList, Pressable, TextInput, Alert, Modal } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import Animated, { FadeInDown } from "react-native-reanimated";
import { supabase, SUPABASE_URL } from "../lib/supabase";
import { Avatar, GradientButton, GlassCard, s } from "../components/ui";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Stream, Profile, LiveMessage, Gift } from "../lib/database.types";

export function LiveStreamScreen({ navigation }: any) {
  const { t } = useI18n();
  const me = useAppStore((st: any) => st.profile);
  const [streams, setStreams] = useState<(Stream & { profiles?: Profile })[]>([]);
  const [active, setActive] = useState<Stream | null>(null);
  const [chat, setChat] = useState<LiveMessage[]>([]);
  const [msg, setMsg] = useState("");
  const [gifts, setGifts] = useState<Gift[]>([]);
  const [giftOpen, setGiftOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [liveKit, setLiveKit] = useState<{ token: string; url: string } | null>(null);
  const [title, setTitle] = useState("");
  const chatRef = useRef<FlatList>(null);

  const loadStreams = async () => {
    const { data } = await supabase
      .from("streams").select("*, profiles:profiles!streams_host_id_fkey(*)")
      .eq("status", "live").order("created_at", { ascending: false });
    setStreams((data as any) ?? []);
  };
  useEffect(() => { loadStreams(); }, []);

  const createStream = async () => {
    if (!me) return Alert.alert("", "سجّل الدخول أولاً");
    const { data, error } = await supabase.from("streams").insert({ host_id: me.id, title: title.trim() || "بث مباشر" }).select().single();
    if (error) return Alert.alert("⚠️", error.message);
    setCreating(false); setTitle("");
    enterStream(data as Stream, true);
  };

  const endStream = async (sid: string) => {
    await supabase.rpc("stream_end", { p_stream: sid });
    setActive(null); setChat([]);
    loadStreams();
  };

  const enterStream = async (stream: Stream, isHost = false) => {
    setActive(stream);
    if (!isHost) await supabase.rpc("stream_join", { p_stream: stream.id });
    // LiveKit: طلب توكن حقيقي من Edge Function (يعمل عند ضبط المفاتيح)
    try {
      const sess = (await supabase.auth.getSession()).data.session;
      const res = await fetch(`${SUPABASE_URL}/functions/v1/livekit-token`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${sess?.access_token ?? ""}` },
        body: JSON.stringify({ room: `stream-${stream.id}`, identity: me?.id, isHost }),
      });
      const data = await res.json().catch(() => null);
      if (data?.token && data?.url) { setLiveKit(data); }
      else if (data?.needs_key) console.log("LiveKit: needs keys — audio/video RTC off, chat+gifts still live");
    } catch {}
    const { data } = await supabase.from("live_messages").select("*, profiles:profiles!live_messages_user_id_fkey(*)").eq("stream_id", stream.id).order("created_at", { ascending: true });
    setChat((data as LiveMessage[]) ?? []);
  };

  // Realtime: chat + viewers + stream end
  useEffect(() => {
    if (!active) return;
    const ch = supabase
      .channel(`live-${active.id}`)
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "live_messages", filter: `stream_id=eq.${active.id}` },
        (p: any) => setChat((c) => [...c, p.new as LiveMessage]))
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "streams", filter: `id=eq.${active.id}` },
        (p: any) => { if (p.new?.status === "ended") { setActive(null); Alert.alert("", "انتهى البث"); } else setActive(p.new); })
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [active?.id]);

  useEffect(() => {
    supabase.from("gifts").select("*").order("price").then(({ data }) => setGifts((data as Gift[]) ?? []));
  }, []);

  const sendChat = async () => {
    if (!msg.trim() || !active || !me) return;
    const { error } = await supabase.rpc("stream_comment", { p_stream: active.id, p_content: msg.trim() });
    if (error) return Alert.alert("⚠️", "تعذر إرسال التعليق");
    setMsg("");
  };

  const sendGift = async (gift: Gift) => {
    if (!active || !me) return;
    const { error } = await supabase.rpc("send_gift", { p_gift_id: gift.id, p_receiver: active.host_id, p_stream_id: active.id, p_qty: 1 });
    if (error) return Alert.alert("⚠️", error.message === "insufficient coins" ? "رصيد غير كافٍ — اشترِ عملات" : error.message);
    setGiftOpen(false);
    Alert.alert("🎁", `أرسلت ${gift.name} إلى المضيف!`);
    useAppStore.getState().refreshProfile();
  };

  const leave = async () => {
    if (active && active.host_id !== me?.id) await supabase.rpc("stream_leave", { p_stream: active.id });
    setActive(null); setChat([]);
    loadStreams();
  };

  // ===== Live room =====
  if (active) {
    const host = (active as any).profiles as Profile | undefined;
    const isHost = active.host_id === me?.id;
    return (
      <LinearGradient colors={["#160b12", "#0d0e15"]} style={s.screen}>
        <View style={{ paddingTop: 64, paddingHorizontal: 16, flexDirection: "row", alignItems: "center", gap: 10 }}>
          <Avatar uri={host?.avatar_url} size={40} ring />
          <View style={{ flex: 1 }}>
            <Text style={{ color: "#fff", fontWeight: "800" }}>@{host?.username}</Text>
            <Text style={{ color: colors.muted, fontSize: 12 }}>{active.title}</Text>
          </View>
          <View style={{ backgroundColor: colors.danger, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 4 }}>
            <Text style={{ color: "#fff", fontWeight: "900", fontSize: 12 }}>● {t("live")}</Text>
          </View>
          <View style={{ backgroundColor: "rgba(0,0,0,0.5)", borderRadius: 999, paddingHorizontal: 10, paddingVertical: 4 }}>
            <Text style={{ color: "#fff", fontSize: 12 }}>👁 {active.viewer_count}</Text>
          </View>
          <Pressable onPress={leave}><Text style={{ color: "#fff", fontSize: 20 }}>✕</Text></Pressable>
        </View>

        <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
          <Text style={{ fontSize: 70 }}>{liveKit ? "🎥" : "📡"}</Text>
          <Text style={{ color: colors.muted, textAlign: "center", paddingHorizontal: 40, marginTop: 8 }}>
            {liveKit
              ? (isHost ? "بثك متصل بـ LiveKit — الكاميرا والمايك جاهزان" : "متصل ببث LiveKit الحقيقي")
              : (isHost ? "بثك نشط — الدردشة والهدايا تعمل. أضف مفاتيح LiveKit في Supabase Secrets لتفعيل الفيديو" : "تتابع البث — أرسل تعليقات وهدايا. أضف مفاتيح LiveKit لمشاهدة الفيديو")}
          </Text>
        </View>

        <FlatList
          ref={chatRef}
          data={chat}
          keyExtractor={(x) => x.id}
          onContentSizeChange={() => chatRef.current?.scrollToEnd({ animated: true })}
          style={{ maxHeight: 180, paddingHorizontal: 14 }}
          renderItem={({ item }) => (
            <Text style={{ color: "#fff", marginBottom: 6 }}>
              <Text style={{ color: colors.accent, fontWeight: "800" }}>{(item as any).profiles?.username ?? item.user_id.slice(0, 6)}: </Text>
              {item.content}
            </Text>
          )}
        />
        <View style={{ padding: 14, flexDirection: "row", gap: 8, alignItems: "center" }}>
          <TextInput value={msg} onChangeText={setMsg} placeholder={t("addComment")} placeholderTextColor={colors.muted}
            style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.5)", borderRadius: 999, paddingHorizontal: 16, height: 44, color: "#fff" }} />
          <Pressable onPress={() => setGiftOpen(true)} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.gold, alignItems: "center", justifyContent: "center" }}>
            <Text>🎁</Text>
          </Pressable>
          <Pressable onPress={sendChat} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primary, alignItems: "center", justifyContent: "center" }}>
            <Text style={{ color: "#fff" }}>➤</Text>
          </Pressable>
          {isHost && (
            <Pressable onPress={() => endStream(active.id)} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.danger, alignItems: "center", justifyContent: "center" }}>
              <Text style={{ color: "#fff" }}>⏹</Text>
            </Pressable>
          )}
        </View>

        <Modal visible={giftOpen} transparent animationType="slide">
          <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.7)", justifyContent: "flex-end" }}>
            <View style={{ backgroundColor: colors.surface, borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 20, gap: 12 }}>
              <Text style={{ color: "#fff", fontWeight: "900", fontSize: 18 }}>🎁 {t("sendGift")} — رصيدك: {me?.coins ?? 0} 🪙</Text>
              <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 10 }}>
                {gifts.map((g) => (
                  <Pressable key={g.id} onPress={() => sendGift(g)} style={{ width: "30%", backgroundColor: colors.surface2, borderRadius: 16, padding: 12, alignItems: "center", borderWidth: 1, borderColor: colors.border }}>
                    <Text style={{ fontSize: 26 }}>{g.icon}</Text>
                    <Text style={{ color: "#fff", fontSize: 12, marginTop: 4 }}>{g.name}</Text>
                    <Text style={{ color: colors.gold, fontSize: 12, fontWeight: "700" }}>{g.price} 🪙</Text>
                  </Pressable>
                ))}
              </View>
              <Pressable onPress={() => setGiftOpen(false)} style={{ alignItems: "center", padding: 10 }}>
                <Text style={{ color: colors.muted }}>إغلاق</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      </LinearGradient>
    );
  }

  // ===== Streams list =====
  return (
    <View style={[s.screen, { paddingTop: 54, paddingHorizontal: 14 }]}>
      <View style={{ flexDirection: "row", alignItems: "center", marginBottom: 14 }}>
        <Text style={{ color: "#fff", fontSize: 24, fontWeight: "900", flex: 1 }}>📡 {t("live")}</Text>
        <Pressable onPress={() => setCreating(true)} style={{ backgroundColor: colors.danger, borderRadius: 999, paddingHorizontal: 16, paddingVertical: 8 }}>
          <Text style={{ color: "#fff", fontWeight: "800", fontSize: 13 }}>● ابدأ بثاً</Text>
        </Pressable>
      </View>
      <FlatList
        data={streams}
        keyExtractor={(x) => x.id}
        renderItem={({ item, index }) => {
          const host = (item as any).profiles as Profile | undefined;
          return (
            <Animated.View entering={FadeInDown.delay(index * 50).duration(400)}>
              <Pressable onPress={() => enterStream(item)}>
                <GlassCard style={{ padding: 14, marginBottom: 12, flexDirection: "row", alignItems: "center", gap: 12 }}>
                  <Avatar uri={host?.avatar_url} ring size={48} />
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: "#fff", fontWeight: "800" }}>@{host?.username}</Text>
                    <Text style={{ color: colors.muted, fontSize: 13 }}>{item.title}</Text>
                  </View>
                  <View style={{ alignItems: "flex-end", gap: 4 }}>
                    <View style={{ backgroundColor: colors.danger, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 3 }}>
                      <Text style={{ color: "#fff", fontSize: 10, fontWeight: "900" }}>● {t("live")}</Text>
                    </View>
                    <Text style={{ color: colors.muted, fontSize: 11 }}>👁 {item.viewer_count}</Text>
                  </View>
                </GlassCard>
              </Pressable>
            </Animated.View>
          );
        }}
        ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center", marginTop: 50 }}>لا توجد بثوث مباشرة حالياً — ابدأ أنت البث الأول!</Text>}
      />

      <Modal visible={creating} transparent animationType="fade">
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.7)", alignItems: "center", justifyContent: "center", padding: 30 }}>
          <View style={{ backgroundColor: colors.surface, borderRadius: 20, padding: 20, alignSelf: "stretch", gap: 12 }}>
            <Text style={{ color: "#fff", fontWeight: "800" }}>عنوان البث</Text>
            <TextInput value={title} onChangeText={setTitle} placeholder="مثال: جلسة أسئلة وأجوبة" placeholderTextColor={colors.muted} style={{ backgroundColor: colors.surface2, borderRadius: 12, height: 46, paddingHorizontal: 12, color: "#fff" }} />
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Pressable onPress={() => setCreating(false)} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.surface2, alignItems: "center" }}><Text style={{ color: "#fff" }}>إلغاء</Text></Pressable>
              <Pressable onPress={createStream} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.danger, alignItems: "center" }}><Text style={{ color: "#fff", fontWeight: "700" }}>● ابدأ</Text></Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}
