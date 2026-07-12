// Edge Function: activate a license key and bind it to the calling device.
//
// Flow:
//  1. Authenticate the caller (anonymous or otherwise) from the JWT.
//  2. Look up the license by key using the service role (bypasses RLS).
//  3. Validate: exists, device not bound to a different device, not past grace.
//  4. Bind the device, stamp last_verified_at.
//  5. Set the caller's app_metadata.shop_id so RLS scopes them to this shop.
//  6. Return license details; the client refreshes its session to pick up the
//     new claim.
//
// Deploy: supabase functions deploy activate

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GRACE_DAYS = 7;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // Identify the caller from their JWT.
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ ok: false, error: "not_authenticated" }, 401);
  }
  const userId = userData.user.id;

  let body: { key?: string; device_id?: string };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "bad_request" }, 400);
  }
  const key = (body.key ?? "").trim();
  const deviceId = (body.device_id ?? "").trim();
  if (!key || !deviceId) {
    return json({ ok: false, error: "bad_request" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);

  const { data: license, error: licErr } = await admin
    .from("licenses")
    .select("*")
    .eq("key", key)
    .maybeSingle();

  if (licErr) return json({ ok: false, error: "server_error" }, 500);
  if (!license) return json({ ok: false, error: "invalid_key" }, 200);

  // Device binding: first activation claims the device; later activations must
  // match (prevents one key being shared across many devices).
  if (license.device_id && license.device_id !== deviceId) {
    return json({ ok: false, error: "device_mismatch" }, 200);
  }

  const now = new Date();
  const expiresAt = new Date(license.expires_at);
  const graceEnd = new Date(expiresAt.getTime() + GRACE_DAYS * 86400000);
  const status = now <= expiresAt
    ? "active"
    : now <= graceEnd
    ? "grace"
    : "expired";

  const { error: updErr } = await admin
    .from("licenses")
    .update({
      device_id: deviceId,
      last_verified_at: now.toISOString(),
      activated_at: license.activated_at ?? now.toISOString(),
      status,
      updated_at: now.toISOString(),
    })
    .eq("id", license.id);
  if (updErr) return json({ ok: false, error: "server_error" }, 500);

  // Scope the caller to this shop via app_metadata (lands in future JWTs).
  const { error: metaErr } = await admin.auth.admin.updateUserById(userId, {
    app_metadata: { shop_id: license.shop_id },
  });
  if (metaErr) return json({ ok: false, error: "server_error" }, 500);

  return json({
    ok: true,
    shop_id: license.shop_id,
    plan: license.plan,
    status,
    expires_at: license.expires_at,
    activated_at: license.activated_at ?? now.toISOString(),
  }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
