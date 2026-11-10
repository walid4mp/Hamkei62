import React, { useEffect, useState } from "react";
import { View, Text, ScrollView, Pressable, TextInput, Alert, Modal, FlatList } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { supabase } from "../lib/supabase";
import { GlassCard, s } from "../components/ui";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Profile, Report, Gift, Post } from "../lib/database.types";

type Tab = "users" | "reports" | "gifts" | "log";

export function AdminScreen({ navigation }: any) {
  const { t } = useI18n();
  const [tab, setTab] = useState<Tab>("users");
  const [stats, setStats] = useState({ users: 0, posts: 0, reports: 0, banned: 0 });
  const [users, setUsers] = useState<Profile[]>([]);
  const [reports, setReports] = useState<Report[]>([]);
  const [gifts, setGifts] = useState<Gift[]>([]);
  const [log, setLog] = useState<any[]>([]);
  const [q, setQ] = useState("");
  const [editingGift, setEditingGift] = useState<Gift | null>(null);
  const [giftPrice, setGiftPrice] = useState("");

  const loadAll = async () => {
    const [{ count: uc }, { count: pc }, { count: rc }, { count: bc }] = await Promise.all([
      supabase.from("profiles").select("*", { count: "exact", head: true }),
      supabase.from("posts").select("*", { count: "exact", head: true }),
      supabase.from("reports").select("*", { count: "exact", head: true }).eq("status", "open"),
      supabase.from("profiles").select("*", { count: "exact", head: true }).eq("is_banned", true),
    ]);
    setStats({ users: uc ?? 0, posts: pc ?? 0, reports: rc ?? 0, banned: bc ?? 0 });
    loadTab();
  };

  const loadTab = async () => {
    if (tab === "users") {
      let req = supabase.from("profiles").select("*").order("created_at", { ascending: false }).limit(50);
      if (q.trim()) req = req.ilike("username", `%${q.replace(/^@/, "")}%`);
      const { data } = await req;
      setUsers((data as Profile[]) ?? []);
    } else if (tab === "reports") {
      const { data } = await supabase.from("reports").select("*").order("created_at", { ascending: false }).limit(50);
      setReports((data as Report[]) ?? []);
    } else if (tab === "gifts") {
      const { data } = await supabase.from("gifts").select("*").order("price");
      setGifts((data as Gift[]) ?? []);
    } else if (tab === "log") {
      const { data } = await supabase.from("admin_log").select("*").order("created_at", { ascending: false }).limit(50);
      setLog(data ?? []);
    }
  };
  useEffect(() => { loadAll(); }, []);
  useEffect(() => { loadTab(); }, [tab, q]);

  const ban = (u: Profile) =>
    Alert.alert(u.is_banned ? "إلغاء الحظر" : "حظر الحساب", `@${u.username}`, [
      { text: "إلغاء", style: "cancel" },
      { text: "تأكيد", style: "destructive", onPress: async () => {
        const { error } = await supabase.rpc("admin_ban_user", { p_target: u.id, p_ban: !u.is_banned });
        if (error) return Alert.alert("⚠️", error.message);
        Alert.alert("✅", "تم التنفيذ"); loadAll();
      } },
    ]);

  const setRole = (u: Profile) =>
    Alert.alert("تغيير الصلاحية", `${u.is_admin ? "إزالة" : "منح"} صلاحية الإدارة عن @${u.username}؟`, [
      { text: "إلغاء", style: "cancel" },
      { text: "تأكيد", style: "destructive", onPress: async () => {
        const { error } = await supabase.rpc("admin_set_role", { p_target: u.id, p_admin: !u.is_admin });
        if (error) return Alert.alert("⚠️", error.message);
        loadAll();
      } },
    ]);

  const resolve = (r: Report, status: "resolved" | "rejected") =>
    Alert.alert("معالجة البلاغ", r.reason, [
      { text: "إلغاء", style: "cancel" },
      { text: "تأكيد", onPress: async () => {
        const { error } = await supabase.rpc("admin_resolve_report", { p_report: r.id, p_status: status });
        if (error) return Alert.alert("⚠️", error.message);
        loadAll();
      } },
    ]);

  const saveGiftPrice = async () => {
    if (!editingGift) return;
    const price = parseInt(giftPrice, 10);
    const { error } = await supabase.rpc("admin_set_gift_price", { p_gift: editingGift.id, p_price: price });
    if (error) return Alert.alert("⚠️", error.message);
    setEditingGift(null); setGiftPrice("");
    loadTab();
  };

  const broadcast = () => {
    Alert.prompt?.("إشعار عام", "نص الإشعار لجميع المستخدمين:", async (body: string) => {
      if (!body) return;
      const { error } = await supabase.rpc("admin_broadcast", { p_title: body, p_body: body });
      Alert.alert(error ? "⚠️" : "✅", error ? error.message : "تم إرسال الإشعار للجميع");
    }) ?? Alert.alert("", "غير مدعوم على هذا الجهاز");
  };

  return (
    <LinearGradient colors={["#0D0E15", "#131c3f", "#0D0E15"]} style={s.screen}>
      <View style={{ paddingTop: 54, paddingHorizontal: 14, flex: 1 }}>
        <View style={{ flexDirection: "row", alignItems: "center", marginBottom: 12 }}>
          <Text style={{ color: "#fff", fontSize: 22, fontWeight: "900", flex: 1 }}>🛡 {t("admin")}</Text>
          <Pressable onPress={() => navigation.goBack()}><Text style={{ color: colors.muted }}>‹ رجوع</Text></Pressable>
        </View>
        <View style={{ flexDirection: "row", gap: 8, marginBottom: 12 }}>
          {[[stats.users, "مستخدم"], [stats.posts, "منشور"], [stats.reports, "بلاغ مفتوح"], [stats.banned, "محظور"]].map(([n, l], i) => (
            <GlassCard key={i} style={{ flex: 1, padding: 10, alignItems: "center" }}>
              <Text style={{ color: "#fff", fontSize: 16, fontWeight: "900" }}>{String(n)}</Text>
              <Text style={{ color: colors.muted, fontSize: 10 }}>{String(l)}</Text>
            </GlassCard>
          ))}
        </View>
        <View style={{ flexDirection: "row", gap: 6, marginBottom: 12 }}>
          {([["users", "المستخدمون"], ["reports", "البلاغات"], ["gifts", "الهدايا"], ["log", "السجل"]] as const).map(([k, l]) => (
            <Pressable key={k} onPress={() => setTab(k)} style={{ flex: 1, paddingVertical: 8, borderRadius: 999, backgroundColor: tab === k ? colors.primary : colors.surface2, alignItems: "center" }}>
              <Text style={{ color: tab === k ? "#fff" : colors.muted, fontSize: 12, fontWeight: "700" }}>{l}</Text>
            </Pressable>
          ))}
        </View>

        {tab === "users" && (
          <View style={{ flex: 1 }}>
            <TextInput value={q} onChangeText={setQ} placeholder="ابحث باسم المستخدم…" placeholderTextColor={colors.muted}
              style={{ backgroundColor: colors.surface2, borderRadius: 12, height: 42, paddingHorizontal: 12, color: "#fff", marginBottom: 10 }} />
            <FlatList
              data={users}
              keyExtractor={(u) => u.id}
              renderItem={({ item }) => (
                <GlassCard style={{ padding: 12, marginBottom: 8, flexDirection: "row", alignItems: "center", gap: 10 }}>
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: "#fff", fontWeight: "700" }}>@{item.username} {item.is_admin ? "🛡" : ""}{item.is_banned ? " ⛔" : ""}</Text>
                    <Text style={{ color: colors.muted, fontSize: 11 }}>{item.coins} 🪙 {item.is_verified ? "· موثّق ✔︎" : ""}</Text>
                  </View>
                  <Pressable onPress={() => ban(item)} style={{ backgroundColor: item.is_banned ? colors.success : colors.danger, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6 }}>
                    <Text style={{ color: "#fff", fontSize: 12 }}>{item.is_banned ? "رفع الحظر" : "حظر"}</Text>
                  </Pressable>
                  <Pressable onPress={() => setRole(item)} style={{ backgroundColor: colors.surface2, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6, borderWidth: 1, borderColor: colors.border }}>
                    <Text style={{ color: "#fff", fontSize: 12 }}>🛡</Text>
                  </Pressable>
                </GlassCard>
              )}
            />
          </View>
        )}

        {tab === "reports" && (
          <FlatList
            data={reports}
            keyExtractor={(r) => r.id}
            renderItem={({ item }) => (
              <GlassCard style={{ padding: 12, marginBottom: 8, gap: 6 }}>
                <Text style={{ color: "#fff", fontSize: 13 }}>🚩 {item.entity_type} — {item.reason}</Text>
                <Text style={{ color: colors.muted, fontSize: 11 }}>{item.status} · {new Date(item.created_at).toLocaleString("ar")}</Text>
                {item.status === "open" && (
                  <View style={{ flexDirection: "row", gap: 8 }}>
                    <Pressable onPress={() => resolve(item, "resolved")} style={{ flex: 1, backgroundColor: colors.success, borderRadius: 10, padding: 8, alignItems: "center" }}>
                      <Text style={{ color: "#fff", fontSize: 12 }}>قبول (معالجة)</Text>
                    </Pressable>
                    <Pressable onPress={() => resolve(item, "rejected")} style={{ flex: 1, backgroundColor: colors.surface2, borderRadius: 10, padding: 8, alignItems: "center", borderWidth: 1, borderColor: colors.border }}>
                      <Text style={{ color: "#fff", fontSize: 12 }}>رفض</Text>
                    </Pressable>
                  </View>
                )}
              </GlassCard>
            )}
            ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center" }}>لا توجد بلاغات</Text>}
          />
        )}

        {tab === "gifts" && (
          <View>
            <Pressable onPress={broadcast} style={{ backgroundColor: colors.secondary, borderRadius: 14, padding: 12, alignItems: "center", marginBottom: 12 }}>
              <Text style={{ color: "#fff", fontWeight: "800" }}>📢 إرسال إشعار عام لجميع المستخدمين</Text>
            </Pressable>
            {gifts.map((g) => (
              <GlassCard key={g.id} style={{ padding: 12, marginBottom: 8, flexDirection: "row", alignItems: "center", gap: 10 }}>
                <Text style={{ fontSize: 22 }}>{g.icon}</Text>
                <Text style={{ color: "#fff", flex: 1 }}>{g.name}</Text>
                <Pressable onPress={() => { setEditingGift(g); setGiftPrice(String(g.price)); }} style={{ backgroundColor: colors.surface2, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6, borderWidth: 1, borderColor: colors.border }}>
                  <Text style={{ color: colors.gold, fontWeight: "700" }}>{g.price} 🪙 ✎</Text>
                </Pressable>
              </GlassCard>
            ))}
          </View>
        )}

        {tab === "log" && (
          <FlatList
            data={log}
            keyExtractor={(x) => x.id}
            renderItem={({ item }) => (
              <View style={{ paddingVertical: 8, borderBottomWidth: 1, borderBottomColor: colors.border }}>
                <Text style={{ color: "#fff", fontSize: 13 }}>{item.action}</Text>
                <Text style={{ color: colors.muted, fontSize: 11 }}>{String(item.target ?? "")} · {new Date(item.created_at).toLocaleString("ar")}</Text>
              </View>
            )}
            ListEmptyComponent={<Text style={{ color: colors.muted, textAlign: "center" }}>السجل فارغ</Text>}
          />
        )}
      </View>

      <Modal visible={!!editingGift} transparent animationType="fade">
        <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.7)", alignItems: "center", justifyContent: "center", padding: 30 }}>
          <View style={{ backgroundColor: colors.surface, borderRadius: 20, padding: 20, alignSelf: "stretch", gap: 12 }}>
            <Text style={{ color: "#fff", fontWeight: "800" }}>سعر {editingGift?.name}</Text>
            <TextInput value={giftPrice} onChangeText={setGiftPrice} keyboardType="number-pad" style={{ backgroundColor: colors.surface2, borderRadius: 12, height: 46, paddingHorizontal: 12, color: "#fff" }} />
            <View style={{ flexDirection: "row", gap: 10 }}>
              <Pressable onPress={() => setEditingGift(null)} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.surface2, alignItems: "center" }}><Text style={{ color: "#fff" }}>إلغاء</Text></Pressable>
              <Pressable onPress={saveGiftPrice} style={{ flex: 1, padding: 12, borderRadius: 12, backgroundColor: colors.primary, alignItems: "center" }}><Text style={{ color: "#fff", fontWeight: "700" }}>حفظ</Text></Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </LinearGradient>
  );
}
