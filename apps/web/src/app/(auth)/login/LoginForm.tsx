"use client";

import { FormEvent, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import {
  authErrorMessage,
  isEmailNotConfirmedError,
} from "@/lib/auth-errors";
import { ResendVerification } from "@/components/auth/ResendVerification";
import { GoogleAuthButton } from "@/components/auth/GoogleAuthButton";
import { useAuthAnim } from "@/components/auth/animated/AuthAnimContext";
import { safeNextPath } from "@/lib/safe-redirect";

export default function LoginForm() {
  const router = useRouter();
  const search = useSearchParams();
  const next = safeNextPath(search.get("next"));
  const anim = useAuthAnim();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [shake, setShake] = useState(false);
  const [needsVerify, setNeedsVerify] = useState(false);
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
    setNeedsVerify(false);
    setShake(false);
    const supabase = createClient();
    const { error: err } = await supabase.auth.signInWithPassword({
      email: email.trim().toLowerCase(),
      password,
    });
    setLoading(false);
    if (err) {
      setError(authErrorMessage(err.message));
      setNeedsVerify(isEmailNotConfirmedError(err.message));
      setShake(true);
      triggerError();
      return;
    }
    router.push(next);
    router.refresh();
  }

  return (
    <>
      <header className="aa-panel-head">
        <h1>Welcome back!</h1>
        <p>Sign in with the same email as your CLIVORA mobile app.</p>
      </header>

      <form className="aa-form" onSubmit={onSubmit} noValidate>
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
              autoComplete="current-password"
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
        {needsVerify && <ResendVerification email={email} />}

        <button type="submit" className="aa-btn-primary" disabled={loading}>
          {loading ? "Signing in…" : "Log in"}
        </button>
      </form>

      <div className="aa-divider">OR</div>
      <div className="aa-google-wrap">
        <GoogleAuthButton mode="signin" next={next} variant="animated" />
      </div>

      <div className="aa-auth-nav">
        <Link href="/auth/reset-password" className="aa-link">
          Forgot password?
        </Link>
        <Link href={`/signup?next=${encodeURIComponent(next)}`} className="aa-link strong">
          Create account
        </Link>
      </div>
    </>
  );
}
