/** CLIVORA branded transactional email HTML. Deployment details come from function secrets. */

const BRAND = {
  name: "CLIVORA",
  tagline: "Your Business Operating System",
  primary: "#6C3CE1",
  navy: "#0F172A",
  muted: "#64748B",
  surface: "#F8FAFC",
  webUrl: (Deno.env.get("SITE_URL") ?? "http://localhost:3000").replace(/\/+$/, ""),
  playUrl: Deno.env.get("PLAY_STORE_URL") || (Deno.env.get("SITE_URL") ?? "http://localhost:3000"),
  supportEmail: Deno.env.get("SUPPORT_EMAIL") ?? "support@example.com",
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function wrapBrandedEmail(opts: {
  preheader: string;
  title: string;
  bodyHtml: string;
  ctaLabel?: string;
  ctaUrl?: string;
  footerNote?: string;
}): string {
  const preheader = escapeHtml(opts.preheader);
  const title = escapeHtml(opts.title);
  const cta =
    opts.ctaLabel && opts.ctaUrl
      ? `<p style="margin:28px 0 0;text-align:center;">
          <a href="${opts.ctaUrl}" style="display:inline-block;background:${BRAND.primary};color:#fff;text-decoration:none;font-weight:700;padding:14px 28px;border-radius:12px;font-size:15px;">${escapeHtml(opts.ctaLabel)}</a>
        </p>`
      : "";
  const footer = opts.footerNote
    ? `<p style="margin:16px 0 0;color:${BRAND.muted};font-size:13px;line-height:1.5;">${opts.footerNote}</p>`
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
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#fff;border-radius:20px;border:1px solid #E2E8F0;overflow:hidden;">
          <tr>
            <td style="background:linear-gradient(135deg,${BRAND.navy} 0%,${BRAND.primary} 100%);padding:28px 32px;text-align:center;">
              <div style="color:#fff;font-size:22px;font-weight:800;letter-spacing:3px;">${BRAND.name}</div>
              <div style="color:rgba(255,255,255,0.8);font-size:12px;margin-top:6px;">${BRAND.tagline}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 16px;font-size:22px;line-height:1.3;color:${BRAND.navy};">${title}</h1>
              <div style="color:#334155;font-size:15px;line-height:1.65;">${opts.bodyHtml}</div>
              ${cta}
              ${footer}
            </td>
          </tr>
          <tr>
            <td style="padding:20px 32px 28px;border-top:1px solid #E2E8F0;text-align:center;">
              <p style="margin:0 0 8px;font-size:12px;color:${BRAND.muted};">
                <a href="${BRAND.webUrl}" style="color:${BRAND.primary};text-decoration:none;">${BRAND.webUrl.replace(/^https?:\/\//, "")}</a>
                · Powered by CLIVORA Community
              </p>
              <p style="margin:0;font-size:11px;color:#94A3B8;">
                You received this because you use ${BRAND.name}. Questions? ${BRAND.supportEmail}
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
      <p><strong>${fn}</strong> added you as a client on CLIVORA. Track projects, invoices, messages, and updates in one honest workspace.</p>
      <ul style="padding-left:18px;margin:16px 0;">
        <li>Sign up as a <strong>Client</strong> with this email address</li>
        <li>See shared projects and progress in real time</li>
        <li>Work with integrity at Rs 2,000/mo Pro when you need more</li>
      </ul>`,
    ctaLabel: "Get CLIVORA on Google Play",
    ctaUrl: BRAND.playUrl,
    footerNote: "If you were not expecting this invite, you can safely ignore this email.",
  });
}

export function passwordResetNoticeTemplate(): string {
  return wrapBrandedEmail({
    preheader: "Password reset requested for your CLIVORA account",
    title: "Password reset requested",
    bodyHtml: `
      <p>We received a request to reset your CLIVORA password.</p>
      <p>Open the reset link from the official Supabase email, or use Forgot password in the app. The link should open this site, not localhost.</p>
      <p>If you did not request this, ignore this message. Your account stays secure.</p>`,
    ctaLabel: "Open CLIVORA",
    ctaUrl: BRAND.webUrl,
  });
}

export function adminNoticeTemplate(subject: string, message: string): string {
  return wrapBrandedEmail({
    preheader: subject,
    title: escapeHtml(subject),
    bodyHtml: `<p>${escapeHtml(message).replace(/\n/g, "<br/>")}</p>`,
    ctaLabel: "Admin dashboard",
    ctaUrl: `${BRAND.webUrl}/admin`,
  });
}

export function renderTemplate(
  purpose: string,
  payload: { subject?: string; html?: string; freelancerName?: string; clientName?: string },
): string {
  if (purpose === "client_invite" && payload.freelancerName && payload.clientName) {
    return clientInviteTemplate(payload.freelancerName, payload.clientName);
  }
  if (purpose === "password_reset") {
    return passwordResetNoticeTemplate();
  }
  if (purpose === "admin_notice" && payload.subject && payload.html) {
    return adminNoticeTemplate(payload.subject, payload.html);
  }
  return payload.html ?? "";
}
