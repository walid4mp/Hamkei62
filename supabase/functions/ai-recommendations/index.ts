// Edge Function: content + friend recommendations (heuristic v1).
// Deploy: supabase functions deploy ai-recommendations
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  try {
    const { user_id } = await req.json();
    // TODO v2: ترتيب بناءً على تفاعلات المستخدم (embedding similarity)
    const [posts, people] = await Promise.all([
      supabase.from("posts").select("*, profiles(username)").order("like_count", { ascending: false }).limit(10),
      supabase.from("profiles").select("id, username, avatar_url, is_verified").limit(10),
    ]);
    return new Response(JSON.stringify({ posts: posts.data, people: people.data }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
