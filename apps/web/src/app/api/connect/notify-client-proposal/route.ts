import { getPublicSiteUrl } from "@/lib/site-url";
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Helper to extract contact email from description text
 */
function extractEmailFromText(text: string): string | null {
  if (!text) return null;
  const matches = text.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g);
  if (!matches) return null;
  const filtered = matches.filter((e) => {
    const lower = e.toLowerCase();
    return (
      !lower.includes("ycombinator") &&
      !lower.includes("example.com") &&
      !lower.includes("w3.org") &&
      !lower.includes("remotive") &&
      !lower.includes("arbeitnow") &&
      !lower.includes("sentry") &&
      !lower.includes(".png") &&
      !lower.includes(".jpg")
    );
  });
  return filtered.length > 0 ? filtered[0].toLowerCase().trim() : null;
}

/**
 * POST /api/connect/notify-client-proposal
 * Automatically notifies hiring clients of newly submitted proposals on CLIVORA.
 * Dispatches an email through the configured mail function with 1-click magic review token.
 */
export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: authErr } = await supabase.auth.getUser();
    if (authErr || !user) {
      return NextResponse.json({ error: "unauthorized" }, { status: 401 });
    }

    const body = (await request.json().catch(() => ({}))) as {
      proposalId?: string;
      jobId?: string;
      toUserId?: string;
      companyEmail?: string;
      companyName?: string;
      amount?: number;
      timelineDays?: number;
      pitchMessage?: string;
      jobTitle?: string;
      testRecipientEmail?: string;
    };

    const proposalId = body.proposalId;
    if (!proposalId) {
      return NextResponse.json({ error: "missing_proposal_id" }, { status: 400 });
    }

    // Generate unique review token
    const reviewToken = crypto.randomUUID();
    const reviewUrl = `${getPublicSiteUrl()}/connect/review?token=${reviewToken}`;

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    // Use service client if available for cross-table client profile and job lookups
    const adminDb =
      supabaseUrl && serviceRoleKey
        ? createServiceClient(supabaseUrl, serviceRoleKey)
        : supabase;

    let targetEmail: string | null = body.companyEmail?.trim().toLowerCase() || null;
    let targetName: string = body.companyName?.trim() || "";
    let resolvedTitle: string = body.jobTitle?.trim() || "";
    let externalSourceUrl: string | null = null;

    // 1. Resolve from toUserId if client is an authenticated CLIVORA member (connect_need_posts)
    if (
      (!targetEmail || !targetEmail.includes("@")) &&
      body.toUserId &&
      body.toUserId !== "00000000-0000-0000-0000-000000000000"
    ) {
      const { data: clientProfile } = await adminDb
        .from("profiles")
        .select("email, name")
        .eq("id", body.toUserId)
        .maybeSingle();

      if (clientProfile?.email) {
        targetEmail = clientProfile.email.trim().toLowerCase();
        if (!targetName) targetName = clientProfile.name || "Client";
      }
    }

    // 2. Resolve from connect_jobs if applying to a curated / crawled job or direct client job
    if ((!targetEmail || !targetEmail.includes("@")) && body.jobId) {
      const { data: jobRow } = await adminDb
        .from("connect_jobs")
        .select("title, company_name, company_email, company_domain, description, source_url, posted_by")
        .eq("id", body.jobId)
        .maybeSingle();

      if (jobRow) {
        if (!resolvedTitle) resolvedTitle = jobRow.title;
        if (!targetName && jobRow.company_name) targetName = jobRow.company_name;
        externalSourceUrl = jobRow.source_url || null;

        // Check if posted directly by a registered Clivora client
        if (jobRow.posted_by) {
          const { data: directClientProfile } = await adminDb
            .from("profiles")
            .select("email, name")
            .eq("id", jobRow.posted_by)
            .maybeSingle();
          if (directClientProfile?.email) {
            targetEmail = directClientProfile.email.trim().toLowerCase();
            if (!targetName) targetName = directClientProfile.name || "Client";
          }
        }

        if (!targetEmail || !targetEmail.includes("@")) {
          if (jobRow.company_email && jobRow.company_email.includes("@")) {
            targetEmail = jobRow.company_email.trim().toLowerCase();
          } else if (jobRow.description) {
            const extracted = extractEmailFromText(jobRow.description);
            if (extracted) {
              targetEmail = extracted;
              // Also backfill connect_jobs for future proposals
              void adminDb
                .from("connect_jobs")
                .update({ company_email: extracted })
                .eq("id", body.jobId);
            }
          }
        }
      }
    }

    // 3. QA Testing Hook: If testRecipientEmail is provided, route email to it for verification
    if (body.testRecipientEmail && body.testRecipientEmail.includes("@")) {
      targetEmail = body.testRecipientEmail.trim().toLowerCase();
    }

    // Update proposal with review token and client metadata
    await adminDb
      .from("connect_proposals")
      .update({
        review_token: reviewToken,
        job_id: body.jobId || null,
        client_email: targetEmail,
        client_name: targetName || null,
      })
      .eq("id", proposalId);

    // Get freelancer's display name
    const { data: freelancerProfile } = await adminDb
      .from("profiles")
      .select("name, email")
      .eq("id", user.id)
      .single();

    const freelancerName = freelancerProfile?.name || "CLIVORA Freelancer";
    let emailDispatched = false;
    let emailStatus = "no_email_available";

    // If client email exists, dispatch transactional notification email via send-clivora-email edge function
    if (targetEmail && targetEmail.includes("@") && supabaseUrl && serviceRoleKey) {
      try {
        const emailRes = await fetch(`${supabaseUrl}/functions/v1/send-clivora-email`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({
            to: targetEmail,
            subject: `New $0-Fee Proposal for "${resolvedTitle || "Your Project"}" from ${freelancerName}`,
            purpose: "proposal_received",
            freelancerName,
            companyName: targetName || "Hiring Team",
            jobTitle: resolvedTitle || "Open Role",
            amount: body.amount || 0,
            timelineDays: body.timelineDays || 7,
            pitchMessage: body.pitchMessage || "",
            reviewUrl,
          }),
        });

        const resData = await emailRes.json().catch(() => ({}));
        if (emailRes.ok) {
          emailDispatched = true;
          emailStatus = "sent";
        } else {
          console.error("[notify-client-proposal] Edge email error:", resData);
          emailStatus = `failed: ${resData.error || emailRes.status}`;
        }
      } catch (err) {
        console.error("[notify-client-proposal] Network email error:", err);
        emailStatus = "network_error";
      }
    }

    return NextResponse.json({
      ok: true,
      reviewToken,
      reviewUrl,
      targetEmail,
      emailDispatched,
      emailStatus,
      externalSourceUrl,
    });
  } catch (error) {
    console.error("[notify-client-proposal]", error);
    return NextResponse.json({ error: "notification_failed" }, { status: 500 });
  }
}
