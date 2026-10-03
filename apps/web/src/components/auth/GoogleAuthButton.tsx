"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { site } from "@/lib/site";

export function GoogleAuthButton({
  mode,
  accountType,
  next = "/app",
  variant = "default",
}: {
  mode: "signin" | "signup";
  accountType?: "freelancer" | "client";
  next?: string;
  variant?: "default" | "animated";
}) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onGoogle() {
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const redirectTo = `${site.url}/auth/callback?next=${encodeURIComponent(next)}${
      accountType ? `&account_type=${accountType}` : ""
    }`;
    if (accountType) {
      try {
        sessionStorage.setItem("clivora_pending_account_type", accountType);
      } catch {
        /* ignore */
      }
    }
    const { error: err } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo,
        queryParams: { access_type: "offline", prompt: "consent" },
      },
    });
    setLoading(false);
    if (err) setError(err.message);
  }

  if (variant === "animated") {
    return (
      <div>
        <button
          type="button"
          onClick={onGoogle}
          disabled={loading}
          className="aa-btn-outline"
        >
          <GoogleIcon />
          {loading
            ? "Connecting Google…"
            : mode === "signup"
              ? "Continue with Google"
              : "Log in with Google"}
        </button>
        {error && (
          <div className="aa-error-box" style={{ marginTop: 12 }} role="alert">
            {error}
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <p className="text-center text-xs text-text-secondary">
        Continue securely to <strong className="text-navy">CLIVORA</strong>
      </p>
      <button
        type="button"
        onClick={onGoogle}
        disabled={loading}
        className="flex w-full items-center justify-center gap-2 rounded-full border-2 border-navy/15 bg-white py-3 text-sm font-semibold text-navy hover:bg-background disabled:opacity-60"
      >
        <GoogleIcon />
        {loading
          ? "Connecting Google…"
          : mode === "signup"
            ? "Continue with Google"
            : "Sign in with Google"}
      </button>
      {error && <p className="text-xs text-error">{error}</p>}
    </div>
  );
}

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden>
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 8 3.1l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.3-.4-3.5z" />
      <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 16.1 19 12 24 12c3.1 0 5.8 1.2 8 3.1l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.3 35.3 26.8 36 24 36c-5.3 0-9.7-3.3-11.3-8l-6.5 5C9.6 39.6 16.2 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-1.1 3.2-3.5 5.7-6.1 7.1l.1.1 6.2 5.2C37.1 39.1 44 34 44 24c0-1.3-.1-2.3-.4-3.5z" />
    </svg>
  );
}
