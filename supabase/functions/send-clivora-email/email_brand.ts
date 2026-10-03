/** CLIVORA branded transactional email HTML. Deployment details come from function secrets. */

const BRAND = {
  name: "CLIVORA",
  tagline: "Your Business Operating System",
  primary: "#6C3CE1",
  primaryDark: "#5B32C4",
  navy: "#0F172A",
  muted: "#64748B",
  surface: "#F8FAFC",
  border: "#E2E8F0",
  webUrl: (Deno.env.get("SITE_URL") ?? "http://localhost:3000").replace(/\/+$/, ""),
  playUrl: Deno.env.get("PLAY_STORE_URL") || (Deno.env.get("SITE_URL") ?? "http://localhost:3000"),
  supportEmail: Deno.env.get("SUPPORT_EMAIL") ?? "support@example.com",
  company: Deno.env.get("OPERATOR_NAME") ?? "CLIVORA",
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function featureList(items: string[]): string {
  const lis = items.map((item) => `<li style="margin-bottom:8px;">${item}</li>`).join("");
  return `<ul style="padding-left:18px;margin:16px 0;color:#334155;">${lis}</ul>`;
}

export function wrapBrandedEmail(opts: {
  preheader: string;
  title: string;
  bodyHtml: string;
  ctaLabel?: string;
  ctaUrl?: string;
  secondaryCtaLabel?: string;
  secondaryCtaUrl?: string;
  footerNote?: string;
  accent?: "purple" | "navy";
}): string {
  const preheader = escapeHtml(opts.preheader);
  const title = escapeHtml(opts.title);
  const accent = opts.accent ?? "purple";
  const headerBg =
    accent === "navy"
      ? `linear-gradient(135deg,${BRAND.navy} 0%,#1e293b 100%)`
      : `linear-gradient(135deg,${BRAND.navy} 0%,${BRAND.primary} 100%)`;

  const primaryCta =
    opts.ctaLabel && opts.ctaUrl
      ? `<p style="margin:28px 0 0;text-align:center;">
          <a href="${opts.ctaUrl}" style="display:inline-block;background:${BRAND.primary};color:#fff;text-decoration:none;font-weight:700;padding:14px 28px;border-radius:12px;font-size:15px;box-shadow:0 4px 14px rgba(108,60,225,0.35);">${escapeHtml(opts.ctaLabel)}</a>
        </p>`
      : "";

  const secondaryCta =
    opts.secondaryCtaLabel && opts.secondaryCtaUrl
      ? `<p style="margin:12px 0 0;text-align:center;">
          <a href="${opts.secondaryCtaUrl}" style="color:${BRAND.primary};text-decoration:none;font-weight:600;font-size:14px;">${escapeHtml(opts.secondaryCtaLabel)}</a>
        </p>`
      : "";

  const footer = opts.footerNote
    ? `<p style="margin:20px 0 0;padding:16px;background:${BRAND.surface};border-radius:10px;color:${BRAND.muted};font-size:13px;line-height:1.5;">${opts.footerNote}</p>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:${BRAND.surface};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <span style="display:none;max-height:0;overflow:hidden;">${preheader}</span>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:${BRAND.surface};padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fff;border-radius:20px;border:1px solid ${BRAND.border};overflow:hidden;box-shadow:0 8px 30px rgba(15,23,42,0.08);">
          <tr>
            <td style="background:${headerBg};padding:28px 32px;text-align:center;">
              <div style="display:inline-block;width:44px;height:44px;border-radius:12px;background:rgba(255,255,255,0.15);color:#fff;font-size:20px;font-weight:800;line-height:44px;margin-bottom:10px;">C</div>
              <div style="color:#fff;font-size:22px;font-weight:800;letter-spacing:3px;">${BRAND.name}</div>
              <div style="color:rgba(255,255,255,0.85);font-size:12px;margin-top:6px;letter-spacing:0.5px;">${BRAND.tagline}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;color:${BRAND.navy};">${title}</h1>
              <div style="color:#334155;font-size:15px;line-height:1.65;">${opts.bodyHtml}</div>
              ${primaryCta}
              ${secondaryCta}
              ${footer}
            </td>
          </tr>
          <tr>
            <td style="padding:20px 32px 28px;border-top:1px solid ${BRAND.border};text-align:center;">
              <p style="margin:0 0 8px;font-size:12px;color:${BRAND.muted};">
                <a href="${BRAND.webUrl}" style="color:${BRAND.primary};text-decoration:none;font-weight:600;">${BRAND.webUrl.replace(/^https?:\/\//, "")}</a>
                · Developed by ${BRAND.company}
              </p>
              <p style="margin:0;font-size:11px;color:#94A3B8;">
                Questions? <a href="mailto:${BRAND.supportEmail}" style="color:${BRAND.muted};">${BRAND.supportEmail}</a>
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

export function clientInviteTemplate(freelancerName: string, clientName: string): string {
  const fn = escapeHtml(freelancerName);
  const cn = escapeHtml(clientName);
  return wrapBrandedEmail({
    preheader: `${freelancerName} invited you to CLIVORA`,
    title: "You are invited to CLIVORA",
    bodyHtml: `
      <p>Hi ${cn},</p>
      <p><strong>${fn}</strong> added you as a client on CLIVORA. Track projects, invoices, messages, and updates in one honest workspace built for freelancers and their clients.</p>
      ${featureList([
        "Sign up as a <strong>Client</strong> with this email address",
        "See shared projects and progress in real time",
        "Chat, invoices, and tasks in one place",
      ])}`,
    ctaLabel: "Get CLIVORA on Google Play",
    ctaUrl: BRAND.playUrl,
    secondaryCtaLabel: "Learn more",
    secondaryCtaUrl: BRAND.webUrl,
    footerNote: "If you were not expecting this invite, you can safely ignore this email.",
  });
}

export function teamInviteTemplate(
  ownerName: string,
  inviteeName: string,
  projectName: string,
  role: string,
): string {
  const on = escapeHtml(ownerName);
  const in_ = escapeHtml(inviteeName);
  const pn = escapeHtml(projectName);
  const rl = escapeHtml(role);
  const projectLine = projectName
    ? `<p>You were invited to collaborate on <strong>${pn}</strong> as <strong>${rl}</strong>.</p>`
    : `<p>You were invited to join a CLIVORA team as <strong>${rl}</strong>.</p>`;

  return wrapBrandedEmail({
    preheader: `${ownerName} invited you to their CLIVORA team`,
    title: "Team collaboration invite",
    bodyHtml: `
      <p>Hi ${in_},</p>
      <p><strong>${on}</strong> wants you on their CLIVORA team.</p>
      ${projectLine}
      ${featureList([
        "Open the CLIVORA app and sign in with this email",
        "Accept the invite from Team Invites in the app",
        "Collaborate on shared projects with full sync",
      ])}`,
    ctaLabel: "Open CLIVORA",
    ctaUrl: BRAND.playUrl,
    secondaryCtaLabel: "View admin dashboard",
    secondaryCtaUrl: `${BRAND.webUrl}/admin`,
    footerNote: "This invite expires when declined or replaced. Did not expect this? Ignore this email.",
    accent: "navy",
  });
}

export function passwordResetNoticeTemplate(): string {
  return wrapBrandedEmail({
    preheader: "Password reset requested for your CLIVORA account",
    title: "Reset your CLIVORA password",
    bodyHtml: `
      <p>We received a request to reset your CLIVORA password.</p>
      <p>Use the secure link from your official reset email, or tap <strong>Forgot password</strong> in the app. The link should open this site, not localhost.</p>
      <p>If you did not request this, ignore this message. Your account stays secure.</p>`,
    ctaLabel: "Reset password on web",
    ctaUrl: `${BRAND.webUrl}/auth/reset-password`,
    secondaryCtaLabel: "Get the mobile app",
    secondaryCtaUrl: BRAND.playUrl,
  });
}

export function adminNoticeTemplate(subject: string, message: string): string {
  return wrapBrandedEmail({
    preheader: subject,
    title: escapeHtml(subject),
    bodyHtml: `<p>${escapeHtml(message).replace(/\n/g, "<br/>")}</p>`,
    ctaLabel: "Open admin dashboard",
    ctaUrl: `${BRAND.webUrl}/admin`,
    accent: "navy",
  });
}

export function taskCompletedTemplate(
  clientName: string,
  taskTitle: string,
  projectName: string,
): string {
  const cn = escapeHtml(clientName);
  const tt = escapeHtml(taskTitle);
  const pn = escapeHtml(projectName);
  return wrapBrandedEmail({
    preheader: `Task completed: ${taskTitle}`,
    title: "Task marked complete",
    bodyHtml: `
      <p>Hi ${cn},</p>
      <p>Your freelancer marked a task as complete on CLIVORA.</p>
      <p style="margin:16px 0;padding:16px;background:${BRAND.surface};border-radius:12px;border-left:4px solid ${BRAND.primary};">
        <strong>${tt}</strong><br/>
        <span style="color:${BRAND.muted};font-size:14px;">Project: ${pn}</span>
      </p>
      <p>Open the app to review progress and leave feedback.</p>`,
    ctaLabel: "Open CLIVORA",
    ctaUrl: BRAND.playUrl,
  });
}

export function welcomeTemplate(userName: string, accountType: string): string {
  const un = escapeHtml(userName);
  const type = accountType === "client" ? "client" : "freelancer";
  const tips =
    type === "client"
      ? featureList([
          "View projects shared with you",
          "Track invoices and messages",
          "Upgrade to Pro when you need more",
        ])
      : featureList([
          "Add clients and projects",
          "Send invoices and track revenue",
          "Invite your team on Pro",
        ]);

  return wrapBrandedEmail({
    preheader: "Welcome to CLIVORA",
    title: "Welcome to CLIVORA",
    bodyHtml: `
      <p>Hi ${un},</p>
      <p>Your ${type} account is ready. CLIVORA helps you run your business with integrity: clients, projects, invoices, and team collaboration in one place.</p>
      ${tips}`,
    ctaLabel: "Get started in the app",
    ctaUrl: BRAND.playUrl,
    secondaryCtaLabel: "Visit the site",
    secondaryCtaUrl: BRAND.webUrl,
  });
}

export function proposalReceivedTemplate(
  companyOrClientName: string,
  freelancerName: string,
  jobTitle: string,
  amount: number,
  timelineDays: number,
  pitchMessage: string,
  reviewUrl: string,
): string {
  const cn = escapeHtml(companyOrClientName || "Hiring Team");
  const fn = escapeHtml(freelancerName || "A Top Freelancer");
  const jt = escapeHtml(jobTitle || "Your Project");
  const msg = escapeHtml(pitchMessage || "Cover letter attached in review link.");

  return wrapBrandedEmail({
    preheader: `New proposal from ${fn} on CLIVORA ($0 Platform Fee)`,
    title: `New proposal received for ${jt}`,
    bodyHtml: `
      <p>Hi ${cn},</p>
      <p><strong>${fn}</strong> just submitted a tailored proposal for your open role <strong>${jt}</strong> on the CLIVORA Connect marketplace.</p>
      <div style="margin:20px 0;padding:20px;background:${BRAND.surface};border-radius:14px;border:1px solid ${BRAND.border};">
        <p style="margin:0 0 10px;font-size:16px;font-weight:700;color:${BRAND.navy};">Proposal Snapshot</p>
        <p style="margin:4px 0;font-size:14px;color:#334155;"><strong>Candidate:</strong> ${fn}</p>
        <p style="margin:4px 0;font-size:14px;color:#334155;"><strong>Proposed Bid:</strong> $${amount} USD</p>
        <p style="margin:4px 0;font-size:14px;color:#334155;"><strong>Estimated Timeline:</strong> ${timelineDays} days</p>
        <div style="margin-top:12px;padding-top:12px;border-top:1px solid ${BRAND.border};">
          <p style="margin:0 0 4px;font-size:12px;font-weight:700;text-transform:uppercase;color:${BRAND.muted};">Cover Note</p>
          <p style="margin:0;font-size:14px;color:#334155;font-style:italic;">"${msg.slice(0, 300)}${msg.length > 300 ? "..." : ""}"</p>
        </div>
      </div>
      <p>Click below to review the complete proposal, inspect portfolio items, and start a <strong>direct private chat with 0% platform fees</strong>:</p>`,
    ctaLabel: "Review Proposal & Connect ($0 Fee)",
    ctaUrl: reviewUrl,
    secondaryCtaLabel: "Browse the marketplace",
    secondaryCtaUrl: BRAND.webUrl,
    footerNote: "CLIVORA is 100% free with $0 platform fees on your negotiated deals. You and the freelancer keep 100% of your earnings.",
  });
}

export function jobClaimTemplate(
  companyName: string,
  jobTitle: string,
  claimUrl: string,
): string {
  const cn = escapeHtml(companyName);
  const jt = escapeHtml(jobTitle);
  return wrapBrandedEmail({
    preheader: `Your ${jobTitle} role is live on CLIVORA — 0% platform fee`,
    title: `Your open role is published on CLIVORA`,
    bodyHtml: `
      <p>Hi ${cn} team,</p>
      <p>Your <strong>${jt}</strong> role has been published on the CLIVORA Connect marketplace — the world's first <strong>$0 platform fee</strong> freelancer marketplace.</p>
      <p style="margin:16px 0;padding:16px;background:${BRAND.surface};border-radius:12px;border-left:4px solid ${BRAND.primary};">
        <strong>What does this mean?</strong><br/>
        <span style="color:${BRAND.muted};font-size:14px;">Talented freelancers can now discover and apply to your role. You receive 100% of the value — no commission, no hidden fees, ever.</span>
      </p>
      ${featureList([
        "Review freelancer proposals and portfolios",
        "Manage milestones and payments with built-in escrow",
        "Chat, share files, and track progress in real time",
        "All for <strong>$0</strong> — forever",
      ])}
      <p>Click below to claim your listing and start reviewing applicants:</p>`,
    ctaLabel: "Claim Your Job Listing",
    ctaUrl: claimUrl,
    secondaryCtaLabel: "Learn more",
    secondaryCtaUrl: BRAND.webUrl,
    footerNote: "This listing was automatically published from a public job board. If this is not your company, please ignore this email. The listing will remain public with no action required.",
  });
}

export function renderTemplate(
  purpose: string,
  payload: {
    subject?: string;
    html?: string;
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
  },
): string {
  if (purpose === "proposal_received" && payload.jobTitle && payload.reviewUrl) {
    return proposalReceivedTemplate(
      payload.companyName ?? payload.clientName ?? "Hiring Team",
      payload.freelancerName ?? "Candidate",
      payload.jobTitle,
      payload.amount ?? 0,
      payload.timelineDays ?? 7,
      payload.pitchMessage ?? "",
      payload.reviewUrl,
    );
  }
  if (purpose === "client_invite" && payload.freelancerName && payload.clientName) {
    return clientInviteTemplate(payload.freelancerName, payload.clientName);
  }
  if (purpose === "team_invite" && payload.ownerName && payload.inviteeName) {
    return teamInviteTemplate(
      payload.ownerName,
      payload.inviteeName,
      payload.projectName ?? "",
      payload.role ?? "member",
    );
  }
  if (purpose === "password_reset") {
    return passwordResetNoticeTemplate();
  }
  if (purpose === "admin_notice") {
    return adminNoticeTemplate(payload.subject ?? "CLIVORA notice", payload.adminMessage ?? payload.html ?? "");
  }
  if (purpose === "task_completed" && payload.clientName && payload.taskTitle) {
    return taskCompletedTemplate(payload.clientName, payload.taskTitle, payload.projectName ?? "Your project");
  }
  if (purpose === "welcome" && payload.userName) {
    return welcomeTemplate(payload.userName, payload.accountType ?? "freelancer");
  }
  if (purpose === "job_claim" && payload.companyName && payload.jobTitle && payload.claimUrl) {
    return jobClaimTemplate(payload.companyName, payload.jobTitle, payload.claimUrl);
  }
  return payload.html ?? "";
}
