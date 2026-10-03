/** Friendly auth error messages for signup/login (Resend / Supabase rate limits). */
export function authErrorMessage(raw: string | null | undefined): string {
  const msg = (raw ?? "").trim();
  const lower = msg.toLowerCase();

  if (!msg) return "Something went wrong. Please try again.";

  if (
    lower.includes("rate limit") ||
    lower.includes("email rate limit exceeded") ||
    lower.includes("over_email_send_rate_limit")
  ) {
    return "Too many verification emails were sent. Wait a few minutes, then tap Resend, or open the link already in your inbox/spam.";
  }

  if (lower.includes("email not confirmed") || lower.includes("email_not_confirmed")) {
    return "Email not confirmed. Check your inbox (and spam) for the CLIVORA verification link, or resend below.";
  }

  if (lower.includes("user already registered") || lower.includes("already been registered")) {
    return "This email already has an account. Sign in instead, or reset your password.";
  }

  if (lower.includes("invalid login credentials")) {
    return "Wrong email or password. Try again, or reset your password.";
  }

  if (lower.includes("signup is disabled")) {
    return "Signups are temporarily disabled. Please try again later or contact support.";
  }

  return msg;
}

export function isEmailNotConfirmedError(raw: string | null | undefined): boolean {
  const lower = (raw ?? "").toLowerCase();
  return lower.includes("email not confirmed") || lower.includes("email_not_confirmed");
}

export function isRateLimitError(raw: string | null | undefined): boolean {
  const lower = (raw ?? "").toLowerCase();
  return (
    lower.includes("rate limit") ||
    lower.includes("over_email_send_rate_limit") ||
    lower.includes("email rate limit exceeded")
  );
}
