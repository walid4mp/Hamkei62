// Edge Function: creator coin withdrawal request
// Deploy: supabase functions deploy withdraw-coins
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const { data: userData } = await supabase.auth.getUser(auth.replace("Bearer ", ""));
    const user = userData?.user;
    if (!user) return new Response("unauthorized", { status: 401 });

    const { amount } = await req.json();
    if (!amount || amount < 1000) return new Response(JSON.stringify({ error: "الحد الأدنى للسحب 1000 عملة" }), { status: 400 });
    // TODO: ربط ببوابة دفع (Stripe Connect / PayPal Payouts) قبل التفعيل في الإنتاج
    const { error } = await supabase
      .from("coin_transactions").insert({ user_id: user.id, amount: -amount, reason: "withdrawal", meta: { status: "pending" } });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    return new Response(JSON.stringify({ ok: true, status: "pending" }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
