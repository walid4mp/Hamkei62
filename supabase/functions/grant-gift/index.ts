// Edge Function: secure gift purchase (server-side coin validation)
// Deploy: supabase functions deploy grant-gift
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const { data: userData } = await supabase.auth.getUser(auth.replace("Bearer ", ""));
    const user = userData?.user;
    if (!user) return new Response("unauthorized", { status: 401 });

    const { gift_id, receiver_id, stream_id, quantity = 1 } = await req.json();
    const { error } = await supabase.rpc("send_gift", {
      p_gift_id: gift_id, p_receiver: receiver_id, p_stream_id: stream_id, p_qty: quantity,
    });
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
