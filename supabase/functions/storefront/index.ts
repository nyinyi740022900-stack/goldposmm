// Edge Function: public B2B2C storefront.
//
// Anonymous customers browse a shop's published catalog and place guest orders.
// The client only ever has the anon key; this function uses the service role
// internally so it can read products / write orders across shop-isolation RLS,
// while exposing ONLY safe fields (never secrets, never other shops' data).
//
// Actions:
//   catalog       { slug }  -> { storefront, products }
//   submit_order  { slug, customer_name, phone, address, note, lines[] }
//                          -> { ok, order_no }
//
// Deploy: supabase functions deploy storefront

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// deno-lint-ignore no-explicit-any
function json(body: any, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json({});
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, serviceKey);

  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const action = body.action as string;
  const slug = (body.slug ?? "").trim();
  if (!slug) return json({ error: "bad_request" }, 400);

  const { data: sf } = await admin
    .from("storefronts")
    .select("*")
    .eq("slug", slug)
    .eq("enabled", true)
    .maybeSingle();
  if (!sf) return json({ error: "not_found" }, 404);

  if (action === "catalog") {
    const { data: products, error } = await admin
      .from("products")
      .select("id, name, sale_price, unit, image_url")
      .eq("shop_id", sf.shop_id)
      .eq("is_active", true)
      .eq("is_deleted", false)
      .order("name");
    if (error) return json({ error: "server_error" }, 500);
    return json({
      storefront: {
        display_name: sf.display_name,
        phone: sf.phone,
        address: sf.address,
        pay_kpay: sf.pay_kpay,
        pay_wave: sf.pay_wave,
        logo_url: sf.logo_url,
      },
      products,
    });
  }

  if (action === "submit_order") {
    const name = (body.customer_name ?? "").trim();
    // deno-lint-ignore no-explicit-any
    const lines = (body.lines ?? []) as any[];
    if (!name || lines.length === 0) return json({ error: "bad_request" }, 400);

    const itemsTotal = lines.reduce(
      (s, l) => s + (Number(l.price) || 0) * (Number(l.qty) || 0),
      0,
    );
    const orderId = crypto.randomUUID();
    const now = new Date().toISOString();
    const orderNo = "WEB-" + Date.now().toString().slice(-8);

    const { error: oErr } = await admin.from("orders").insert({
      id: orderId,
      shop_id: sf.shop_id,
      order_no: orderNo,
      channel: "storefront",
      status: "new",
      customer_name: name,
      customer_phone: (body.phone ?? "").trim() || null,
      delivery_address: (body.address ?? "").trim() || null,
      township: (body.township ?? "").trim() || null,
      items_total: itemsTotal,
      payment_status: "unpaid",
      note: (body.note ?? "").trim() || null,
      payment_proof_path: (body.payment_proof_path ?? "").trim() || null,
      created_at: now,
      updated_at: now,
    });
    if (oErr) return json({ error: "server_error", detail: oErr.message }, 500);

    const items = lines.map((l) => ({
      id: crypto.randomUUID(),
      shop_id: sf.shop_id,
      order_id: orderId,
      product_id: l.product_id ?? null,
      name_snapshot: `${l.name ?? ""}`,
      price_snapshot: Number(l.price) || 0,
      qty: Number(l.qty) || 0,
      line_total: (Number(l.price) || 0) * (Number(l.qty) || 0),
      created_at: now,
      updated_at: now,
    }));
    const { error: iErr } = await admin.from("order_items").insert(items);
    if (iErr) return json({ error: "server_error", detail: iErr.message }, 500);

    return json({ ok: true, order_no: orderNo });
  }

  return json({ error: "bad_action" }, 400);
});
