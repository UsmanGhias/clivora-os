// CLIVORA transactional email (Resend or SMTP, configured through function secrets).
// Secrets: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
// Resend is removed — do not set RESEND_*.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { renderTemplate } from "./email_brand.ts";
import {
  sendSmtpEmail,
  smtpConfigured,
  smtpFromAddress,
} from "./smtp_send.ts";

const ALLOWED = new Set([
  "password_reset",
  "admin_notice",
  "client_invite",
  "team_invite",
  "task_completed",
  "welcome",
  "job_claim",
  "proposal_received",
]);
const MONTHLY_LIMIT = 3000;

type EmailBody = {
  to?: string;
  subject?: string;
  html?: string;
  purpose?: string;
  freelancerName?: string;
  clientName?: string;
  ownerName?: string;
  inviteeName?: string;
  projectName?: string;
  role?: string;
  taskTitle?: string;
  userName?: string;
  accountType?: string;
  adminMessage?: string;
  companyName?: string;
  jobTitle?: string;
  claimUrl?: string;
  amount?: number;
  timelineDays?: number;
  pitchMessage?: string;
  reviewUrl?: string;
  wrapBrand?: boolean;
};

function secureEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (!smtpConfigured()) {
    return new Response(
      JSON.stringify({
        error:
          "Email not configured. Set RESEND_API_KEY or SMTP_HOST, SMTP_USER, SMTP_PASS on Edge Function secrets.",
      }),
      { status: 503 },
    );
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!bearer) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  let cronSecret = Deno.env.get("CRON_SECRET") ?? "";
  if (!cronSecret && serviceKey && supabaseUrl) {
    const adminDb = createClient(supabaseUrl, serviceKey);
    const { data: secRow } = await adminDb
      .from("_internal_secrets")
      .select("value")
      .eq("key", "cron_secret")
      .maybeSingle();
    if (secRow?.value) cronSecret = secRow.value as string;
  }

  let senderUid: string | null = null;
  const isServiceRole = Boolean(
    (serviceKey && secureEqual(bearer, serviceKey)) ||
    (cronSecret && secureEqual(bearer, cronSecret))
  );

  if (!isServiceRole) {
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
    }
    senderUid = userData.user.id;
  }

  let body: EmailBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });
  }

  const to = (body.to ?? "").trim().toLowerCase();
  const subject = (body.subject ?? "").trim();
  const purpose = (body.purpose ?? "").trim();

  if (!to.includes("@") || !subject) {
    return new Response(JSON.stringify({ error: "Missing to or subject" }), { status: 400 });
  }
  if (!ALLOWED.has(purpose)) {
    return new Response(JSON.stringify({ error: "Purpose not allowed" }), { status: 403 });
  }

  if (purpose === "admin_notice" && !isServiceRole) {
    if (!serviceKey || !senderUid) {
      return new Response(JSON.stringify({ error: "Admin email not configured" }), { status: 503 });
    }
    const adminCheck = createClient(supabaseUrl, serviceKey);
    const { data: profile } = await adminCheck
      .from("profiles")
      .select("role, account_type")
      .eq("id", senderUid)
      .maybeSingle();
    const isAdmin = profile?.role === "admin" || profile?.account_type === "admin";
    if (!isAdmin) {
      return new Response(JSON.stringify({ error: "Admin only" }), { status: 403 });
    }
  }

  const html = renderTemplate(purpose, body);
  if (!html) {
    return new Response(JSON.stringify({ error: "Missing template fields or html" }), { status: 400 });
  }

  const adminClient = serviceKey ? createClient(supabaseUrl, serviceKey) : null;
  if (adminClient) {
    const monthStart = new Date();
    monthStart.setUTCDate(1);
    monthStart.setUTCHours(0, 0, 0, 0);
    const { count } = await adminClient
      .from("email_send_log")
      .select("id", { count: "exact", head: true })
      .gte("sent_at", monthStart.toISOString());
    if ((count ?? 0) >= MONTHLY_LIMIT) {
      return new Response(JSON.stringify({ error: "Monthly email limit reached" }), { status: 429 });
    }
  }

  try {
    await sendSmtpEmail({ to, subject, html });
    if (adminClient) {
      await adminClient.from("email_send_log").insert({
        purpose,
        recipient: to,
        sender_uid: senderUid || "00000000-0000-0000-0000-000000000000",
      });
    }
    return new Response(
      JSON.stringify({ ok: true, from: smtpFromAddress() }),
      { status: 200 },
    );
  } catch (e) {
    console.error("[send-clivora-email] SMTP failure:", e);
    return new Response(
      JSON.stringify({ error: "email_send_failed", message: "Failed to dispatch email notification" }),
      { status: 500 },
    );
  }
});
