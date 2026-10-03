"use client";

import { FormEvent, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { site } from "@/lib/site";
import { authErrorMessage, isRateLimitError } from "@/lib/auth-errors";

export function ResendVerification({ email: initialEmail }: { email?: string }) {
  const [email, setEmail] = useState(initialEmail ?? "");
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  async function onResend(e: FormEvent) {
    e.preventDefault();
    const trimmed = email.trim().toLowerCase();
    if (!trimmed) {
      setErr("Enter your email first.");
      return;
    }
    setBusy(true);
    setErr(null);
    setMsg(null);
    const supabase = createClient();
    const { error } = await supabase.auth.resend({
      type: "signup",
      email: trimmed,
      options: { emailRedirectTo: `${site.url}/auth/callback` },
    });
    setBusy(false);
    if (error) {
      setErr(authErrorMessage(error.message));
      return;
    }
    setMsg(
      isRateLimitError(null)
        ? "If you already requested a link, check inbox/spam first."
        : "Verification email sent. Open the link, then sign in."
    );
  }

  return (
    <form onSubmit={onResend} className="mt-3 space-y-2 rounded-xl border border-border bg-background p-3">
      <p className="text-xs font-semibold uppercase tracking-wide text-text-secondary">
        Resend verification
      </p>
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="you@email.com"
        className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm outline-none ring-primary focus:ring-2"
      />
      <button
        type="submit"
        disabled={busy}
        className="w-full rounded-full bg-navy py-2 text-sm font-semibold text-white disabled:opacity-60"
      >
        {busy ? "Sending…" : "Resend verification email"}
      </button>
      {err && <p className="text-xs text-error">{err}</p>}
      {msg && <p className="text-xs text-primary-dark">{msg}</p>}
    </form>
  );
}
