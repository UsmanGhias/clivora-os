"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import { site } from "@/lib/site";
import { useAuthAnim } from "@/components/auth/animated/AuthAnimContext";

type Phase = "loading" | "request" | "update";

/**
 * Password reset is two gated steps:
 * 1) request - enter email, Supabase sends recovery link (no password form)
 * 2) update - only after a valid recovery link (PKCE code or PASSWORD_RECOVERY session)
 * Users cannot open the password form by clicking a tab.
 */
export default function ResetPasswordPage() {
  const anim = useAuthAnim();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [phase, setPhase] = useState<Phase>("loading");
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    let cancelled = false;

    async function enterUpdateMode(note?: string) {
      if (cancelled) return;
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) {
        setPhase("request");
        setError(
          "That reset link is invalid or expired. Request a new password reset email below.",
        );
        return;
      }
      setPhase("update");
      setError(null);
      setMessage(note ?? "Choose a new password for your CLIVORA account.");
    }

    async function hydrateRecovery() {
      try {
        const params = new URLSearchParams(window.location.search);
        const code = params.get("code");
        const errParam = params.get("error_description") || params.get("error");

        if (errParam) {
          if (!cancelled) {
            setPhase("request");
            setError(decodeURIComponent(errParam.replace(/\+/g, " ")));
          }
          return;
        }

        if (code) {
          const { error: exchangeErr } = await supabase.auth.exchangeCodeForSession(code);
          if (cancelled) return;
          if (exchangeErr) {
            setPhase("request");
            setError(exchangeErr.message || "Reset link could not be verified. Request a new one.");
            return;
          }
          // Drop code from URL so refresh does not re-exchange.
          window.history.replaceState({}, "", "/auth/reset-password");
          await enterUpdateMode();
          return;
        }

        const hash = window.location.hash.replace(/^#/, "");
        if (hash) {
          const hashParams = new URLSearchParams(hash);
          const type = (hashParams.get("type") || "").toLowerCase();
          const accessToken = hashParams.get("access_token");
          const refreshToken = hashParams.get("refresh_token");
          if (type === "recovery" && accessToken && refreshToken) {
            const { error: setErr } = await supabase.auth.setSession({
              access_token: accessToken,
              refresh_token: refreshToken,
            });
            if (cancelled) return;
            if (setErr) {
              setPhase("request");
              setError(setErr.message || "Reset link could not be verified. Request a new one.");
              return;
            }
            window.history.replaceState({}, "", "/auth/reset-password");
            await enterUpdateMode();
            return;
          }
        }

        // No recovery link → only the email request form.
        if (!cancelled) {
          setPhase("request");
        }
      } catch {
        if (!cancelled) {
          setPhase("request");
          setError("Could not verify reset link. Request a new password reset email.");
        }
      }
    }

    let authSubscription: { unsubscribe: () => void } | null = null;
    try {
      const { data } = supabase.auth.onAuthStateChange((event) => {
        if (event === "PASSWORD_RECOVERY") {
          void enterUpdateMode();
        }
      });
      authSubscription = data?.subscription ?? null;
    } catch {
      /* ignore */
    }

    void hydrateRecovery();
    return () => {
      cancelled = true;
      try {
        authSubscription?.unsubscribe?.();
      } catch {
        /* ignore */
      }
    };
  }, []);

  async function onRequest(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setMessage(null);
    const supabase = createClient();
    const redirectTo = `${site.url.replace(/\/$/, "")}/auth/reset-password`;
    const { error: err } = await supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      { redirectTo },
    );
    setLoading(false);
    if (err) {
      setError(err.message);
      anim.triggerError();
      return;
    }
    setMessage(
      "If that email has a CLIVORA account, we sent a reset link. Open the link from your inbox to set a new password.",
    );
  }

  async function onUpdate(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setMessage(null);

    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      anim.triggerError();
      return;
    }
    if (password !== confirm) {
      setError("Passwords do not match.");
      anim.triggerError();
      return;
    }

    setLoading(true);
    const supabase = createClient();
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) {
      setLoading(false);
      setPhase("request");
      setError("Your reset session expired. Request a new password reset email.");
      anim.triggerError();
      return;
    }

    const { error: err } = await supabase.auth.updateUser({ password });
    if (err) {
      setLoading(false);
      setError(err.message);
      anim.triggerError();
      return;
    }

    await supabase.auth.signOut();
    setLoading(false);
    setMessage("Password updated. Sign in with your new password.");
    window.setTimeout(() => {
      window.location.href = "/login";
    }, 1200);
  }

  if (phase === "loading") {
    return (
      <>
        <header className="aa-panel-head">
          <h1>Reset password</h1>
          <p>Checking your reset link…</p>
        </header>
        <p className="aa-signup" style={{ marginTop: 8 }}>
          Please wait a moment.
        </p>
      </>
    );
  }

  return (
    <>
      <header className="aa-panel-head">
        <h1>{phase === "update" ? "Set new password" : "Reset password"}</h1>
        <p>
          {phase === "update"
            ? "Your email link was verified. Choose a new password for your CLIVORA account."
            : "Enter your email and we will send a secure reset link. You can set a new password only after opening that link."}
        </p>
      </header>

      {phase === "request" ? (
        <form onSubmit={onRequest} className="aa-form">
          <label className="aa-field">
            <span>Email</span>
            <input
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              onFocus={() => anim.setTyping(true)}
              onBlur={() => anim.setTyping(false)}
              placeholder="you@company.com"
            />
          </label>
          <button type="submit" disabled={loading} className="aa-btn-primary">
            {loading ? "Sending…" : "Send reset email"}
          </button>
        </form>
      ) : (
        <form onSubmit={onUpdate} className="aa-form">
          <label className="aa-field">
            <span>New password</span>
            <input
              type="password"
              required
              minLength={6}
              autoComplete="new-password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                anim.setPasswordLen(e.target.value.length);
              }}
              placeholder="••••••••"
            />
          </label>
          <label className="aa-field">
            <span>Confirm password</span>
            <input
              type="password"
              required
              minLength={6}
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              placeholder="••••••••"
            />
          </label>
          <button type="submit" disabled={loading} className="aa-btn-primary">
            {loading ? "Updating…" : "Update password"}
          </button>
        </form>
      )}

      {error && (
        <div className="aa-error-box" style={{ marginTop: 16 }} role="alert">
          {error}
        </div>
      )}
      {message && (
        <div className="aa-error-box info" style={{ marginTop: 16 }} role="status">
          {message}
        </div>
      )}

      <p className="aa-signup">
        <Link href="/login" className="aa-link strong">
          Back to sign in
        </Link>
      </p>
    </>
  );
}
