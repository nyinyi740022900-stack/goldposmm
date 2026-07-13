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
    shop_name?: string;
    plan?: string;
    months?: number;
    key?: string;
    device_id?: string;
    payment_id?: string;
    request_id?: string;
    config?: Record<string, string>;
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
      // Enrich each payment with the license's device + shop name so the admin
      // can see who paid and which device before approving.
      const { data: lic } = await admin
        .from("licenses")
        .select("key, device_id, shop_name");
      const byKey = new Map(
        (lic ?? []).map((r: Record<string, unknown>) => [r.key, r]),
      );
      const rows = (data ?? []).map((p: Record<string, unknown>) => {
        const l = byKey.get(p.license_key) as Record<string, unknown> | undefined;
        // Prefer the shop name the payment carried (from the shop's own
        // profile); fall back to the name the admin set on the license.
        return {
          ...p,
          device_id: l?.device_id ?? null,
          shop_name: p.shop_name ?? l?.shop_name ?? null,
        };
      });
      return json({ rows });
    }

    case "extend_by_device": {
      // Extend whatever license is bound to this App Reference ID / device.
      const dev = (body.device_id ?? "").trim();
      const months = body.months ?? 1;
      if (!dev) return json({ error: "bad_request" }, 400);
      const { data: lic, error: findErr } = await admin
        .from("licenses")
        .select("key, shop_name")
        .eq("device_id", dev)
        .maybeSingle();
      if (findErr) return json({ error: "server_error" }, 500);
      if (!lic) return json({ error: "not_found" }, 404);
      const { data, error } = await admin.rpc("renew_license", {
        p_key: lic.key,
        p_months: months,
      });
      if (error) return json({ error: "server_error", detail: error.message }, 500);
      await logEvent(admin, {
        device_id: dev,
        shop_name: lic.shop_name,
        key: lic.key,
        action: "extend",
        months,
        expires_at: data,
      });
      return json({ expires_at: data, key: lic.key });
    }

    case "reset_device": {
      // Clear the device binding so a reinstalled user can re-activate.
      const dev = (body.device_id ?? "").trim();
      if (!dev) return json({ error: "bad_request" }, 400);
      const { data, error } = await admin
        .from("licenses")
        .update({ device_id: null, updated_at: new Date().toISOString() })
        .eq("device_id", dev)
        .select("key");
      if (error) return json({ error: "server_error" }, 500);
      return json({ ok: true, cleared: (data ?? []).length });
    }

    case "list_requests": {
      const { data, error } = await admin
        .from("license_requests")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) return json({ error: "server_error" }, 500);
      return json({ rows: data });
    }

    case "fulfill_request": {
      const reqId = (body.request_id ?? "").trim();
      if (!reqId) return json({ error: "bad_request" }, 400);
      const { data: reqRow, error: reqErr } = await admin
        .from("license_requests")
        .select("*")
        .eq("id", reqId)
        .maybeSingle();
      if (reqErr) return json({ error: "server_error" }, 500);
      if (!reqRow) return json({ error: "not_found" }, 404);

      const months = body.months ?? reqRow.months ?? 1;
      const dev = (reqRow.device_id ?? "").trim();

      // If this device already has a license, this is a RENEWAL → extend it.
      const { data: existing } = dev
        ? await admin
            .from("licenses")
            .select("key")
            .eq("device_id", dev)
            .maybeSingle()
        : { data: null };

      let key: string;
      let expiresAt: string | null = null;
      let action: string;
      if (existing?.key) {
        const { data, error } = await admin.rpc("renew_license", {
          p_key: existing.key,
          p_months: months,
        });
        if (error) return json({ error: "server_error", detail: error.message }, 500);
        key = existing.key;
        expiresAt = data as string;
        action = "extend";
      } else {
        const shopId = `shop-${reqId.replace(/-/g, "").slice(0, 10)}`;
        const { data: newKey, error: mkErr } = await admin.rpc("create_license", {
          p_shop_id: shopId,
          p_plan: reqRow.plan ?? "monthly",
          p_months: months,
          p_shop_name: reqRow.shop_name ?? null,
        });
        if (mkErr) return json({ error: "server_error", detail: mkErr.message }, 500);
        key = newKey as string;
        action = "issue";
      }

      await admin
        .from("license_requests")
        .update({
          status: "fulfilled",
          issued_key: key,
          updated_at: new Date().toISOString(),
        })
        .eq("id", reqId);
      await logEvent(admin, {
        device_id: dev || null,
        shop_name: reqRow.shop_name ?? null,
        key,
        action,
        months,
        expires_at: expiresAt,
      });
      return json({ key, action });
    }

    case "list_events": {
      const { data, error } = await admin
        .from("license_events")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) return json({ error: "server_error" }, 500);
      return json({ rows: data });
    }

    case "get_config": {
      const { data, error } = await admin.from("app_config").select("key, value");
      if (error) return json({ error: "server_error" }, 500);
      return json({ rows: data });
    }

    case "set_config": {
      const entries = Object.entries(body.config ?? {});
      if (entries.length === 0) return json({ error: "bad_request" }, 400);
      const rows = entries.map(([key, value]) => ({
        key,
        value: `${value}`,
        updated_at: new Date().toISOString(),
      }));
      const { error } = await admin.from("app_config").upsert(rows);
      if (error) return json({ error: "server_error", detail: error.message }, 500);
      return json({ ok: true });
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
        p_shop_name: (body.shop_name ?? "").trim() || null,
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

// deno-lint-ignore no-explicit-any
async function logEvent(admin: any, event: Record<string, unknown>) {
  try {
    await admin.from("license_events").insert(event);
  } catch (_) {
    // audit log is best-effort; never fail the main action over it
  }
}

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
