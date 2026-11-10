import React, { useEffect, useState } from "react";
import { View, Text, Pressable, ScrollView, Alert, FlatList } from "react-native";
import { LinearGradient } from "react-native-linear-gradient";
import { supabase } from "../lib/supabase";
import { GradientButton, GlassCard, s } from "../components/ui";
import { useAppStore } from "../store/useAppStore";
import { useI18n } from "../i18n";
import { colors } from "../theme";
import type { Gift, GiftSent, Profile } from "../lib/database.types";

const reasonsAr: Record<string, string> = {
  purchase: "شراء عملات", gift_sent: "إرسال هدية", gift_received: "استلام هدية",
  withdrawal: "سحب", reward: "مكافأة", transfer: "تحويل",
};

export function WalletScreen({ navigation }: any) {
  const { t } = useI18n();
  const profile = useAppStore((st: any) => st.profile);
  const refresh = useAppStore((st: any) => st.refreshProfile);
  const [txs, setTxs] = useState<(GiftSent & { gift?: Gift })[]>([]);

  const loadTx = async () => {
    if (!profile) return;
    const { data } = await supabase
      .from("gifts_sent").select("*, gift:gifts!gifts_sent_gift_id_fkey(*), sender:profiles!gifts_sent_sender_id_fkey(username), receiver:profiles!gifts_sent_receiver_id_fkey(username)")
      .or(`sender_id.eq.${profile.id},receiver_id.eq.${profile.id}`)
      .order("created_at", { ascending: false }).limit(30);
    setTxs((data as any) ?? []);
  };
  useEffect(() => { loadTx(); }, [profile?.id]);

  const buy = async (amount: number) => {
    if (!profile) return Alert.alert("", "سجّل الدخول أولاً");
    const { error } = await supabase.rpc("buy_coins", { p_amount: amount });
    if (error) return Alert.alert("⚠️", error.message);
    await refresh();
    Alert.alert("✅", `تم شراء ${amount} ${t("coins")}`);
  };

  return (
    <LinearGradient colors={["#0D0E15", "#221a3f", "#0D0E15"]} style={s.screen}>
      <ScrollView contentContainerStyle={{ padding: 20, paddingTop: 70, gap: 18 }}>
        <Text style={s.title}>{t("wallet")}</Text>
        <GlassCard style={{ padding: 24, alignItems: "center", gap: 8 }}>
          <Text style={{ fontSize: 44 }}>🪙</Text>
          <Text style={{ color: "#fff", fontSize: 34, fontWeight: "900" }}>{profile?.coins ?? 0}</Text>
          <Text style={{ color: colors.muted }}>{t("coins")}</Text>
        </GlassCard>
        <GradientButton label={t("buyCoins")} onPress={() => buy(100)} />
        <View style={{ flexDirection: "row", gap: 10 }}>
          {[50, 100, 500].map((n) => (
            <Pressable key={n} onPress={() => buy(n)} style={{ flex: 1, backgroundColor: colors.surface2, borderRadius: 16, padding: 14, alignItems: "center", borderWidth: 1, borderColor: colors.border }}>
              <Text style={{ color: "#fff", fontWeight: "800" }}>+{n} 🪙</Text>
            </Pressable>
          ))}
        </View>
        <Text style={{ color: "#fff", fontWeight: "800", marginTop: 6 }}>🧾 {t("transactions")}</Text>
        {txs.map((tx) => {
          const isSend = tx.sender_id === profile?.id;
          return (
            <GlassCard key={tx.id} style={{ padding: 12, flexDirection: "row", alignItems: "center", gap: 10 }}>
              <Text style={{ fontSize: 20 }}>{tx.gift?.icon ?? "🎁"}</Text>
              <View style={{ flex: 1 }}>
                <Text style={{ color: "#fff", fontSize: 13 }}>{isSend ? "أرسلت" : "استلمت"} {tx.gift?.name}</Text>
                <Text style={{ color: colors.muted, fontSize: 11 }}>{new Date(tx.created_at).toLocaleString("ar")}</Text>
              </View>
              <Text style={{ color: isSend ? colors.danger : colors.success, fontWeight: "800" }}>
                {isSend ? "-" : "+"}{(tx.gift?.price ?? 0) * tx.quantity} 🪙
              </Text>
            </GlassCard>
          );
        })}
        {txs.length === 0 && <Text style={{ color: colors.muted, textAlign: "center" }}>لا توجد معاملات بعد</Text>}
        <Pressable onPress={() => navigation.goBack()} style={{ alignItems: "center", padding: 10 }}>
          <Text style={{ color: colors.muted }}>‹ رجوع</Text>
        </Pressable>
      </ScrollView>
    </LinearGradient>
  );
}
