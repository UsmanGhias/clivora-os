"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { site } from "@/lib/site";
import { authErrorMessage, isRateLimitError } from "@/lib/auth-errors";
import { ResendVerification } from "@/components/auth/ResendVerification";
import { GoogleAuthButton } from "@/components/auth/GoogleAuthButton";
import { earlyAccessPlanForSignup } from "@/lib/early-access";
import { useAuthAnim } from "@/components/auth/animated/AuthAnimContext";
import { safeNextPath } from "@/lib/safe-redirect";

export default function SignupForm() {
  const router = useRouter();
  const search = useSearchParams();
  const next = safeNextPath(search.get("next"));
  const roleParam = search.get("role");
  const initialRole =
    roleParam === "client" || roleParam === "freelancer" ? roleParam : "freelancer";
  const anim = useAuthAnim();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [accountType, setAccountType] = useState<"freelancer" | "client">(initialRole);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [shake, setShake] = useState(false);
  const [awaitingVerify, setAwaitingVerify] = useState(false);
  const [loading, setLoading] = useState(false);

  const { setPasswordLen, setShowPassword: setAnimShowPassword, setTyping, triggerError } = anim;

  useEffect(() => {
    setPasswordLen(password.length);
  }, [password, setPasswordLen]);

  useEffect(() => {
    setAnimShowPassword(showPassword);
  }, [showPassword, setAnimShowPassword]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setInfo(null);
    setAwaitingVerify(false);
    setShake(false);
    const supabase = createClient();
    const trimmedEmail = email.trim().toLowerCase();
    const { data, error: err } = await supabase.auth.signUp({
      email: trimmedEmail,
      password,
      options: {
        data: {
          name: name.trim(),
          account_type: accountType,
        },
        emailRedirectTo: `${site.url}/auth/callback`,
      },
    });
    if (err) {
      setLoading(false);
      setError(authErrorMessage(err.message));
      setShake(true);
      triggerError();
      if (isRateLimitError(err.message)) {
        setAwaitingVerify(true);
      }
      return;
    }

    if (data.user) {
      await supabase.from("profiles").upsert({
        id: data.user.id,
        email: trimmedEmail,
        name: name.trim(),
        account_type: accountType,
        subscription_plan: earlyAccessPlanForSignup(),
        updated_at: new Date().toISOString(),
      });
    }

    setLoading(false);
    if (!data.session) {
      setAwaitingVerify(true);
      setInfo(
        "Account created. Check your inbox (and spam) to verify your email, then sign in. You can browse Connect meanwhile; creating work needs verification.",
      );
      return;
    }
    router.push(next);
    router.refresh();
  }

  return (
    <>
      <header className="aa-panel-head">
        <h1>Create account</h1>
        <p>Use the same email as your CLIVORA mobile app.</p>
      </header>

      <form className="aa-form" onSubmit={onSubmit} noValidate>
        <div className="aa-role-grid" role="group" aria-label="Account type">
          {(["freelancer", "client"] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setAccountType(t)}
              className={`aa-role-btn${
                accountType === t
                  ? t === "freelancer"
                    ? " active-freelancer"
                    : " active-client"
                  : ""
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        <label className="aa-field">
          <span>Full name</span>
          <input
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Your name"
          />
        </label>

        <label className="aa-field">
          <span>Email</span>
          <input
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onFocus={() => setTyping(true)}
            onBlur={() => setTyping(false)}
            placeholder="you@company.com"
          />
        </label>

        <label className="aa-field">
          <span>Password</span>
          <div className="aa-password-wrap">
            <input
              type={showPassword ? "text" : "password"}
              required
              minLength={6}
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
            />
            <button
              type="button"
              className="aa-toggle-pass"
              aria-label={showPassword ? "Hide password" : "Show password"}
              onClick={() => setShowPassword((v) => !v)}
            >
              {showPassword ? (
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <path d="M17.94 17.94A10.94 10.94 0 0 1 12 19c-7 0-10-7-10-7a17.81 17.81 0 0 1 4.06-5.06" />
                  <path d="M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 10 7 10 7a17.81 17.81 0 0 1-3.17 4.19" />
                  <path d="M14.12 14.12A3 3 0 1 1 9.88 9.88" />
                  <line x1="2" y1="2" x2="22" y2="22" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
                  <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
              )}
            </button>
          </div>
        </label>

        {error && (
          <div className={`aa-error-box${shake ? " shake" : ""}`} role="alert">
            {error}
          </div>
        )}
        {info && (
          <div className="aa-error-box info" role="status">
            {info}
          </div>
        )}
        {awaitingVerify && <ResendVerification email={email} />}

        <button type="submit" className="aa-btn-primary" disabled={loading}>
          {loading ? "Creating…" : "Create account"}
        </button>
      </form>

      <div className="aa-divider">OR</div>
      <GoogleAuthButton mode="signup" accountType={accountType} next={next} variant="animated" />

      {awaitingVerify && (
        <div className="aa-auth-nav" style={{ marginTop: 16 }}>
          <Link href={`/login?next=${encodeURIComponent(next)}`} className="aa-link strong">
            Go to sign in
          </Link>
          <Link href="/connect" className="aa-link">
            Browse Connect
          </Link>
        </div>
      )}

      <div className="aa-auth-nav">
        <span className="aa-auth-nav-hint">Already have an account?</span>
        <Link href={`/login?next=${encodeURIComponent(next)}`} className="aa-link strong">
          Sign in
        </Link>
      </div>
    </>
  );
}
