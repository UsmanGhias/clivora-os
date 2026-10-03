/**
 * Connect credits in the Community edition.
 *
 * The database still records Connect actions in a ledger, but every account is
 * unlimited (see supabase/migrations/20261003_community_unlimited_connect.sql),
 * so no action is refused for lack of credits. Eligibility checks such as a
 * confirmed email and a sufficiently complete profile still apply.
 */
export const CONNECT_CREDIT_COSTS = {
  proposal: 1,
  contact: 1,
  publish_need: 3,
  publish_profile: 3,
} as const;

export type ConnectCreditAction = keyof typeof CONNECT_CREDIT_COSTS;

export type ConnectCreditSummary = {
  plan: string;
  allowance: number;
  balance: number;
  period_start: string;
  period_end: string;
  legacy_unlimited: boolean;
  grandfather_until: string | null;
};

export type ConnectCreditErrorCode =
  | "INSUFFICIENT_CREDITS"
  | "PROFILE_INCOMPLETE"
  | "ACTION_NOT_ALLOWED"
  | "DUPLICATE_ACTION"
  | "AUTH_REQUIRED"
  | "PRO_PLUS_REQUIRED";

const CODES: ConnectCreditErrorCode[] = [
  "INSUFFICIENT_CREDITS",
  "PROFILE_INCOMPLETE",
  "ACTION_NOT_ALLOWED",
  "DUPLICATE_ACTION",
  "AUTH_REQUIRED",
  "PRO_PLUS_REQUIRED",
];

export function parseConnectCreditError(error: unknown): {
  code: ConnectCreditErrorCode | "UNKNOWN";
  message: string;
} {
  const raw =
    typeof error === "string"
      ? error
      : error && typeof error === "object" && "message" in error
        ? String((error as { message?: string }).message ?? "")
        : String(error ?? "");
  const upper = raw.toUpperCase();
  for (const code of CODES) {
    if (upper.includes(code)) return { code, message: humanizeConnectCreditError(code) };
  }
  return { code: "UNKNOWN", message: raw || "Connect action failed" };
}

export function humanizeConnectCreditError(code: ConnectCreditErrorCode): string {
  switch (code) {
    case "INSUFFICIENT_CREDITS":
    case "PRO_PLUS_REQUIRED":
      return "Connect credits are unlimited on this deployment. If you see this, the community migration has not been applied to the database.";
    case "PROFILE_INCOMPLETE":
      return "Confirm your email and complete your profile before using Connect.";
    case "ACTION_NOT_ALLOWED":
      return "This Connect action is not allowed for your account.";
    case "DUPLICATE_ACTION":
      return "That Connect action was already processed.";
    case "AUTH_REQUIRED":
      return "Sign in to use Connect.";
  }
}

export function formatConnectCredits(summary: ConnectCreditSummary | null | undefined): string {
  if (!summary || summary.legacy_unlimited) return "Unlimited";
  return `${summary.balance} / ${summary.allowance} credits`;
}
