// LiveKit token minting — deploy: supabase functions deploy livekit-token
// يتطلب Secrets: LIVEKIT_API_KEY, LIVEKIT_API_SECRET, LIVEKIT_URL (Project Settings → Edge Functions → Secrets)
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2";

Deno.serve(async (req) => {
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const { room, identity, isHost } = await req.json();
    if (!room || !identity) return new Response(JSON.stringify({ error: "room & identity required" }), { status: 400 });

    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!apiKey || !apiSecret) {
      return new Response(JSON.stringify({ error: "LIVEKIT keys not configured", needs_key: true }), { status: 501 });
    }

    const at = new AccessToken(apiKey, apiSecret, { identity, ttl: "6h" });
    at.addGrant({
      room,
      roomJoin: true,
      canPublish: !!isHost,
      canSubscribe: true,
      roomAdmin: !!isHost,
    });
    return new Response(JSON.stringify({ token: await at.toJwt(), url: Deno.env.get("LIVEKIT_URL") }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
