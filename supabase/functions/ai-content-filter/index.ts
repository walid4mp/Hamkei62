// Edge Function: AI content filter — flags abusive comments.
// Deploy: supabase functions deploy ai-content-filter
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BLOCKLIST = [" idiot", "stupid", "غبي", "كلب", "حمار", "قذر", "خرا"];
const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  try {
    const { comment_id, content } = await req.json();
    const toxic = BLOCKLIST.some((w) => content?.toLowerCase().includes(w.trim()));
    // TODO: استبدل القائمة بنموذج LLM (OpenAI moderation / Gemini) عبر مفتاح secret
    if (toxic && comment_id) {
      await supabase.from("comments").update({ is_toxic: true }).eq("id", comment_id);
    }
    return new Response(JSON.stringify({ toxic }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
