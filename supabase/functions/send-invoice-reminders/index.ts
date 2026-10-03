// CLIVORA — overdue invoice payment reminders (cron / service-role).
// Secrets: SMTP_HOST, SMTP_USER, SMTP_PASS, SMTP_FROM, SUPABASE_SERVICE_ROLE_KEY, CRON_SECRET
// Invoke: POST with header Authorization: Bearer <CRON_SECRET>
// Idempotent: only rows where next_reminder_at <= now(); sets reminder_sent_at + next +3d.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { sendSmtpEmail, smtpConfigured } from "./smtp_send.ts";

const BATCH = 40;

function secureEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!serviceKey || !supabaseUrl) {
    return new Response(JSON.stringify({ error: "Reminder service is not configured" }), { status: 503 });
  }

  const admin = createClient(supabaseUrl, serviceKey);

  let cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  if (!cronSecret) {
    const { data: secRow } = await admin
      .from("_internal_secrets")
      .select("value")
      .eq("key", "cron_secret")
      .maybeSingle();
    if (secRow?.value) cronSecret = secRow.value as string;
  }

  if (!cronSecret) {
    return new Response(JSON.stringify({ error: "Reminder secret is not configured" }), { status: 503 });
  }

  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const ok = token.length > 0 && secureEqual(token, cronSecret);
  if (!ok) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  if (!smtpConfigured()) {
    return new Response(JSON.stringify({ error: "Email not configured (SMTP)" }), { status: 503 });
  }

  const nowIso = new Date().toISOString();

  const { data: invoices, error } = await admin
    .from("crm_invoices")
    .select(
      "id, owner_uid, invoice_number, total, currency, status, due_date, customer_id, reminder_sent_at, next_reminder_at",
    )
    .lte("next_reminder_at", nowIso)
    .in("status", ["sent", "overdue", "partial", "unpaid"])
    .order("next_reminder_at", { ascending: true })
    .limit(BATCH);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const rows = invoices ?? [];
  let sent = 0;
  let skipped = 0;
  const errors: string[] = [];

  for (const inv of rows) {
    try {
      let clientEmail = "";
      let clientName = "there";
      if (inv.customer_id) {
        const { data: cust } = await admin
          .from("crm_customers")
          .select("name, email, emails")
          .eq("id", inv.customer_id)
          .maybeSingle();
        clientName = (cust?.name as string) || "there";
        clientEmail = (cust?.email as string) || "";
        if (!clientEmail && Array.isArray(cust?.emails) && cust.emails.length) {
          clientEmail = String(cust.emails[0]);
        }
      }
      if (!clientEmail.includes("@")) {
        skipped += 1;
        // Push next attempt out so we don't spin forever
        await admin
          .from("crm_invoices")
          .update({
            next_reminder_at: new Date(Date.now() + 7 * 86400000).toISOString(),
          })
          .eq("id", inv.id);
        continue;
      }

      const { data: owner } = await admin
        .from("profiles")
        .select("name, email")
        .eq("id", inv.owner_uid)
        .maybeSingle();
      const ownerName = (owner?.name as string) || "CLIVORA freelancer";

      const number = inv.invoice_number || String(inv.id).slice(0, 8);
      const amount = `${inv.currency || "USD"} ${Number(inv.total ?? 0).toFixed(2)}`;
      const due = inv.due_date
        ? new Date(inv.due_date).toLocaleDateString()
        : "soon";
      const subject = `Payment reminder: Invoice ${number}`;
      const html = `
        <div style="font-family:system-ui,sans-serif;max-width:560px;margin:0 auto;color:#0f172a">
          <h2 style="color:#0d9488">CLIVORA payment reminder</h2>
          <p>Hi ${clientName},</p>
          <p>This is a friendly reminder that invoice <strong>${number}</strong>
          (${amount}) from <strong>${ownerName}</strong> was due on <strong>${due}</strong>.</p>
          <p>Please arrange payment at your earliest convenience. If you already paid, you can ignore this email.</p>
          <p style="color:#64748b;font-size:12px">Sent via CLIVORA</p>
        </div>
      `;

      try {
        await sendSmtpEmail({ to: clientEmail, subject, html });
      } catch (mailErr) {
        errors.push(`${inv.id}: ${String(mailErr).slice(0, 120)}`);
        continue;
      }

      const next = new Date(Date.now() + 3 * 86400000).toISOString();
      await admin
        .from("crm_invoices")
        .update({
          reminder_sent_at: nowIso,
          next_reminder_at: next,
          status: inv.status === "sent" ? "overdue" : inv.status,
        })
        .eq("id", inv.id);

      await admin.from("automation_run_log").insert({
        user_uid: inv.owner_uid,
        automation_key: "invoice_payment_reminder",
        detail: `Reminded ${clientEmail} for invoice ${number}`,
      });

      sent += 1;
    } catch (e) {
      errors.push(`${inv.id}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  return new Response(
    JSON.stringify({
      ok: true,
      scanned: rows.length,
      sent,
      skipped,
      errors: errors.slice(0, 10),
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
