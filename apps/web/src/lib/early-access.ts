export const EARLY_ACCESS_PRO_END_ISO = "2026-07-22T23:59:59.000Z";
export const BUG_REPORT_EMAIL = process.env.NEXT_PUBLIC_CONTACT_EMAIL || "support@example.com";

export function isEarlyAccessProWindow(now = new Date()) {
  return now.getTime() <= new Date(EARLY_ACCESS_PRO_END_ISO).getTime();
}

/** New signups always start on free. Early-access Pro claims are retired. */
export function earlyAccessPlanForSignup(_now = new Date()) {
  return "free" as const;
}
