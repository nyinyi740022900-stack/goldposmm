// Edge Function: admin console backend.
//
// One authenticated endpoint for the vendor admin dashboard. Verifies the
// caller is an admin (JWT app_metadata.role === 'admin'), then performs the
// requested action with the service role. Keeps the service key server-side —
// the web dashboard only ever holds the anon key + an admin session.
//
// Actions (POST body { action, ... }):
//   list_licenses                         -> licenses (newest first)
//   list_payments                         -> license_payments (newest first)
//   create_license { shop_id, plan, months } -> { key }
//   renew_license  { key, months, payment_id? } -> { expires_at }
//
// Deploy: supabase functions deploy admin

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  // Identify + authorize the caller.
  const asUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "not_authenticated" }, 401);
  }
  const role = (userData.user.app_metadata as Record<string, unknown> | null)
    ?.role;
  if (role !== "admin") return json({ error: "forbidden" }, 403);

  let body: {
    action?: string;
    shop_id?: string;
    plan?: string;
    months?: number;
    key?: string;
    payment_id?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);

  switch (body.action) {
    case "list_licenses": {
      const { data, error } = await admin
        .from("licenses")
        .select("*")
        .order("updated_at", { ascending: false })
        .limit(500);
      if (error) return json({ error: "server_error" }, 500);
      return json({ rows: data });
    }

    case "list_payments": {
      const { data, error } = await admin
        .from("license_payments")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) return json({ error: "server_error" }, 500);
      return json({ rows: data });
    }

    case "create_license": {
      const shopId = (body.shop_id ?? "").trim();
      const plan = (body.plan ?? "monthly").trim();
      const months = body.months ?? 1;
      if (!shopId) return json({ error: "bad_request" }, 400);
      const { data, error } = await admin.rpc("create_license", {
        p_shop_id: shopId,
        p_plan: plan,
        p_months: months,
      });
      if (error) return json({ error: "server_error", detail: error.message }, 500);
      return json({ key: data });
    }

    case "renew_license": {
      const key = (body.key ?? "").trim();
      const months = body.months ?? 1;
      if (!key) return json({ error: "bad_request" }, 400);
      const { data, error } = await admin.rpc("renew_license", {
        p_key: key,
        p_months: months,
      });
      if (error) return json({ error: "server_error", detail: error.message }, 500);
      // Optionally mark the originating payment reconciled.
      if (body.payment_id) {
        await admin
          .from("license_payments")
          .update({ reconciled: true, updated_at: new Date().toISOString() })
          .eq("id", body.payment_id);
      }
      return json({ expires_at: data });
    }

    default:
      return json({ error: "unknown_action" }, 400);
  }
});

function cors(res: Response): Response {
  res.headers.set("Access-Control-Allow-Origin", "*");
  res.headers.set(
    "Access-Control-Allow-Headers",
    "authorization, x-client-info, apikey, content-type",
  );
  res.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  return res;
}

function json(body: unknown, status = 200): Response {
  return cors(
    new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json" },
    }),
  );
}
