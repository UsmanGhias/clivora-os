"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AppWindow,
  BadgeCheck,
  Bell,
  Calendar,
  CreditCard,
  Globe,
  HelpCircle,
  Headphones,
  KeyRound,
  Link2,
  Shield,
  SlidersHorizontal,
  Store,
  Trash2,
  User,
  Users,
  Wallet,
} from "lucide-react";
import {
  FreelancerCard,
  FreelancerPageHeader,
  OutlineButton,
  PrimaryButton,
  StatusPill,
} from "@/components/freelancer/ui";
import { ManageBillingButton } from "@/components/app/ManageBillingButton";
import { ProfileEditForm } from "@/components/freelancer/ProfileEditForm";
import { DeleteAccountPanel } from "@/components/settings/DeleteAccountPanel";
import { createClient } from "@/lib/supabase/client";
import { PRO_PLUS_PRICE_USD } from "@/lib/pricing";
import { cn } from "@/lib/utils";
import type { Profile } from "@/lib/profile-types";

const NAV = [
  { key: "account", label: "Account", icon: User },
  { key: "profile", label: "Profile", icon: User },
  { key: "notifications", label: "Notifications", icon: Bell },
  { key: "security", label: "Security", icon: Shield },
  { key: "billing", label: "Billing", icon: Wallet },
  { key: "preferences", label: "Preferences", icon: SlidersHorizontal },
  { key: "apps", label: "Apps", icon: AppWindow },
] as const;

type TabKey = (typeof NAV)[number]["key"];

const NOTIF_KEYS = [
  { key: "messages", label: "New messages" },
  { key: "proposals", label: "Proposal updates" },
  { key: "payments", label: "Payment alerts" },
  { key: "tips", label: "Product tips" },
  { key: "marketing", label: "Marketing emails" },
] as const;

const LS_NOTIF = "clivora_freelancer_notif_prefs";

type Props = {
  profile: Profile;
  plan: string;
  plus: boolean;
  hasStripeBilling: boolean;
  initialTab?: string;
  googleConfigured?: boolean;
  googleCalendarConnected?: boolean;
};

function Toast({ message, onDone }: { message: string; onDone: () => void }) {
  useEffect(() => {
    const t = setTimeout(onDone, 2800);
    return () => clearTimeout(t);
  }, [onDone]);
  return (
    <div className="fixed bottom-6 right-6 z-50 rounded-xl bg-navy px-4 py-3 text-sm font-semibold text-white shadow-lg">
      {message}
    </div>
  );
}

export function FreelancerSettingsPanel({
  profile,
  plan,
  plus,
  hasStripeBilling,
  initialTab,
  googleConfigured = false,
  googleCalendarConnected = false,
}: Props) {
  const validTab = NAV.some((n) => n.key === initialTab) ? (initialTab as TabKey) : "account";
  const [tab, setTab] = useState<TabKey>(validTab);
  const [toast, setToast] = useState<string | null>(null);
  const showToast = useCallback((msg: string) => setToast(msg), []);

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Settings"
        subtitle="Manage your account, security, billing, and preferences."
      />

      <div className="grid gap-6 lg:grid-cols-[220px_1fr]">
        <nav className="h-fit space-y-0.5 rounded-2xl border border-border bg-surface p-2 shadow-sm">
          {NAV.map((item) => {
            const Icon = item.icon;
            const active = tab === item.key;
            return (
              <button
                key={item.key}
                type="button"
                onClick={() => setTab(item.key)}
                className={cn(
                  "flex w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-sm font-semibold transition",
                  active
                    ? "border-l-4 border-primary bg-primary/5 text-navy"
                    : "text-text-secondary hover:bg-primary/5",
                )}
              >
                <Icon className="h-4 w-4 shrink-0" />
                {item.label}
              </button>
            );
          })}
        </nav>

        <div className="space-y-4">
          {tab === "account" && (
            <AccountTab profile={profile} plan={plan} plus={plus} onGoto={(t) => setTab(t)} />
          )}
          {tab === "profile" && (
            <FreelancerCard title="Edit profile">
              <ProfileEditForm profile={profile} onSaved={() => showToast("Profile saved")} />
              <p className="mt-4 text-xs text-text-muted">
                Connect marketplace listing fields live in{" "}
                <Link href="/app/connect/manage" className="font-semibold text-primary">
                  Manage Connect
                </Link>
                .
              </p>
            </FreelancerCard>
          )}
          {tab === "notifications" && (
            <NotificationsTab
              profileId={profile.id}
              onSaved={() => showToast("Notification prefs saved")}
            />
          )}
          {tab === "security" && <SecurityTab plus={plus} onToast={showToast} />}
          {tab === "billing" && (
            <FreelancerCard title="Billing & plans">
              <p className="text-sm text-text-secondary">
                You are on <strong className="text-navy">{plan}</strong>
                {plus
                  ? " with Pro Plus benefits (Connect + MFA + 50GB vault)."
                  : "."}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                <ManageBillingButton />
                {!plus && <PrimaryButton href="/edition">Upgrade plan</PrimaryButton>}
              </div>
            </FreelancerCard>
          )}
          {tab === "preferences" && (
            <FreelancerCard title="Preferences">
              <div className="flex items-center gap-3 rounded-xl border border-border p-4">
                <Globe className="h-5 w-5 text-primary" />
                <div>
                  <p className="font-semibold text-navy">Language & region</p>
                  <p className="text-sm text-text-secondary">English · USD</p>
                </div>
              </div>
              <div className="mt-3 flex items-center gap-3 rounded-xl border border-border p-4">
                <Users className="h-5 w-5 text-primary" />
                <div className="flex-1">
                  <p className="font-semibold text-navy">Team workspace</p>
                  <p className="text-sm text-text-secondary">
                    Invite collaborators from Hub. Full seats roll out with Pro Plus.
                  </p>
                </div>
                <OutlineButton href="/app/hub">Open Hub</OutlineButton>
              </div>
            </FreelancerCard>
          )}
          {tab === "apps" && (
            <AppsTab
              hasStripeBilling={hasStripeBilling}
              plus={plus}
              googleConfigured={googleConfigured}
              googleCalendarConnected={googleCalendarConnected}
            />
          )}

          <div className="flex flex-col gap-3 rounded-2xl border border-teal-100 bg-teal-50/80 p-5 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/15 text-primary">
                <HelpCircle className="h-5 w-5" />
              </span>
              <div>
                <p className="font-semibold text-navy">Need help with your account?</p>
                <p className="text-sm text-text-secondary">
                  Our support team is here to help you get the most out of CLIVORA.
                </p>
              </div>
            </div>
            <div className="flex gap-2">
              <PrimaryButton href="/app/support">Visit Help Center</PrimaryButton>
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-primary text-white">
                <Headphones className="h-5 w-5" />
              </span>
            </div>
          </div>
        </div>
      </div>

      {toast && <Toast message={toast} onDone={() => setToast(null)} />}
    </div>
  );
}

function AccountTab({
  profile,
  plan,
  plus,
  onGoto,
}: {
  profile: Profile;
  plan: string;
  plus: boolean;
  onGoto: (t: TabKey) => void;
}) {
  return (
    <>
      <FreelancerCard
        title="Account information"
        action={
          <OutlineButton onClick={() => onGoto("profile")}>Edit photo & name</OutlineButton>
        }
      >
        <div className="space-y-5">
          <div className="flex min-w-0 items-start gap-4">
            {profile.avatar_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={profile.avatar_url}
                alt=""
                className="h-16 w-16 shrink-0 rounded-full object-cover"
              />
            ) : (
              <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-primary text-xl font-bold text-white">
                {(profile.name || profile.email || "?").charAt(0).toUpperCase()}
              </span>
            )}
            <div className="min-w-0 flex-1">
              <p className="font-display text-lg font-bold text-navy">
                {profile.name || "Freelancer"}
              </p>
              <p className="truncate text-sm text-text-secondary">{profile.email}</p>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                {plus && (
                  <StatusPill tone="green">
                    <span className="inline-flex items-center gap-1">
                      <BadgeCheck className="h-3 w-3" /> Verified
                    </span>
                  </StatusPill>
                )}
                <StatusPill tone="teal">{plan}</StatusPill>
              </div>
            </div>
          </div>

          <div className="rounded-xl border border-border bg-primary/5 p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <p className="text-xs font-semibold uppercase tracking-wide text-text-muted">
                  Plan
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-2">
                  <p className="font-bold text-navy">{plan}</p>
                  {plus && <StatusPill tone="green">Active</StatusPill>}
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <OutlineButton onClick={() => onGoto("billing")}>Manage billing</OutlineButton>
                <OutlineButton href="/edition">Plan status</OutlineButton>
              </div>
            </div>
            <p className="mt-3 text-xs text-text-secondary">
              CLIVORA charges <strong>${PRO_PLUS_PRICE_USD}/mo</strong> for Pro Plus. Invoice
              amounts go client → you directly - keep work on platform.
            </p>
          </div>
        </div>
      </FreelancerCard>

      <DeleteAccountPanel email={profile.email || ""} />

      <FreelancerCard title="Quick actions">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {[
            { label: "Change password", icon: KeyRound, action: () => onGoto("security") },
            { label: "Billing", icon: CreditCard, action: () => onGoto("billing") },
            { label: "Notifications", icon: Bell, action: () => onGoto("notifications") },
            { label: "Delete account", icon: Trash2, href: "/privacy", danger: true },
          ].map((a) => {
            const Icon = a.icon;
            const inner = (
              <>
                <span
                  className={cn(
                    "flex h-10 w-10 items-center justify-center rounded-xl",
                    "danger" in a && a.danger
                      ? "bg-red-50 text-error"
                      : "bg-primary/10 text-primary",
                  )}
                >
                  <Icon className="h-5 w-5" />
                </span>
                <span
                  className={cn(
                    "text-sm font-semibold",
                    "danger" in a && a.danger ? "text-error" : "text-navy",
                  )}
                >
                  {a.label}
                </span>
              </>
            );
            if ("href" in a && a.href) {
              return (
                <Link
                  key={a.label}
                  href={a.href}
                  className="flex items-center gap-3 rounded-xl border border-border p-4 transition hover:border-primary/40"
                >
                  {inner}
                </Link>
              );
            }
            return (
              <button
                key={a.label}
                type="button"
                onClick={"action" in a ? a.action : undefined}
                className="flex items-center gap-3 rounded-xl border border-border p-4 text-left transition hover:border-primary/40"
              >
                {inner}
              </button>
            );
          })}
        </div>
      </FreelancerCard>
    </>
  );
}

function NotificationsTab({
  profileId,
  onSaved,
}: {
  profileId: string;
  onSaved: () => void;
}) {
  const [prefs, setPrefs] = useState<Record<string, boolean>>(() => {
    const defaults: Record<string, boolean> = {};
    for (const n of NOTIF_KEYS) defaults[n.key] = true;
    return defaults;
  });

  useEffect(() => {
    try {
      const raw = localStorage.getItem(`${LS_NOTIF}_${profileId}`);
      if (raw) setPrefs((p) => ({ ...p, ...JSON.parse(raw) }));
    } catch {
      /* ignore */
    }
  }, [profileId]);

  function toggle(key: string) {
    setPrefs((p) => ({ ...p, [key]: !p[key] }));
  }

  function save() {
    try {
      localStorage.setItem(`${LS_NOTIF}_${profileId}`, JSON.stringify(prefs));
    } catch {
      /* ignore */
    }
    onSaved();
  }

  return (
    <FreelancerCard
      title="Notification settings"
      action={<PrimaryButton onClick={save}>Save</PrimaryButton>}
    >
      <ul className="space-y-3">
        {NOTIF_KEYS.map((n) => (
          <li
            key={n.key}
            className="flex items-center justify-between rounded-xl border border-border px-4 py-3"
          >
            <span className="flex items-center gap-2 text-sm font-semibold text-navy">
              <Bell className="h-4 w-4 text-primary" />
              {n.label}
            </span>
            <input
              type="checkbox"
              checked={!!prefs[n.key]}
              onChange={() => toggle(n.key)}
              className="h-4 w-4 accent-primary"
            />
          </li>
        ))}
      </ul>
    </FreelancerCard>
  );
}

function SecurityTab({ plus, onToast }: { plus: boolean; onToast: (m: string) => void }) {
  const supabase = useMemo(() => createClient(), []);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [hasPasswordProvider, setHasPasswordProvider] = useState<boolean | null>(null);
  const [accountEmail, setAccountEmail] = useState("");
  const [pwBusy, setPwBusy] = useState(false);
  const [pwError, setPwError] = useState("");

  const [factorId, setFactorId] = useState<string | null>(null);
  const [enrollment, setEnrollment] = useState<{
    factorId: string;
    qrCode: string;
    secret: string;
  } | null>(null);
  const [code, setCode] = useState("");
  const [mfaBusy, setMfaBusy] = useState(false);
  const [mfaError, setMfaError] = useState("");
  const [mfaReady, setMfaReady] = useState(false);

  const refreshMfa = useCallback(async () => {
    if (!plus) return;
    const factors = await supabase.auth.mfa.listFactors();
    if (factors.error) return;
    const verified = factors.data.totp.find((f) => f.status === "verified");
    setFactorId(verified?.id ?? null);
    setMfaReady(true);
  }, [plus, supabase]);

  useEffect(() => {
    void refreshMfa();
  }, [refreshMfa]);

  useEffect(() => {
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setAccountEmail(user.email ?? "");
      const providers = (user.app_metadata?.providers as string[] | undefined) ?? [];
      const identities = user.identities ?? [];
      const emailIdentity = identities.some((i) => i.provider === "email");
      const onlyOAuth =
        !emailIdentity &&
        (providers.includes("google") ||
          identities.some((i) => i.provider === "google" || i.provider === "apple"));
      setHasPasswordProvider(!onlyOAuth);
    })();
  }, [supabase]);

  async function changePassword() {
    setPwError("");
    if (password.length < 8) {
      setPwError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setPwError("Passwords do not match.");
      return;
    }
    setPwBusy(true);
    try {
      if (hasPasswordProvider) {
        if (!currentPassword) {
          setPwError("Enter your current password to continue.");
          setPwBusy(false);
          return;
        }
        const email = accountEmail;
        if (!email) {
          setPwError("No email on this account.");
          setPwBusy(false);
          return;
        }
        const { error: reauthErr } = await supabase.auth.signInWithPassword({
          email,
          password: currentPassword,
        });
        if (reauthErr) {
          setPwError("Current password is incorrect.");
          setPwBusy(false);
          return;
        }
      }
      const { error } = await supabase.auth.updateUser({ password });
      if (error) {
        setPwError(error.message);
        setPwBusy(false);
        return;
      }
      setPassword("");
      setConfirm("");
      setCurrentPassword("");
      setHasPasswordProvider(true);
      onToast(hasPasswordProvider ? "Password updated" : "Password set - you can sign in with email too");
    } finally {
      setPwBusy(false);
    }
  }

  async function startEnrollment() {
    setMfaBusy(true);
    setMfaError("");
    try {
      const listed = await supabase.auth.mfa.listFactors();
      if (listed.error) throw listed.error;
      for (const factor of listed.data.totp.filter(
        (c) => (c.status as string) === "unverified",
      )) {
        const removed = await supabase.auth.mfa.unenroll({ factorId: factor.id });
        if (removed.error) throw removed.error;
      }
      const result = await supabase.auth.mfa.enroll({
        factorType: "totp",
        friendlyName: "CLIVORA",
      });
      if (result.error) throw result.error;
      setEnrollment({
        factorId: result.data.id,
        qrCode: result.data.totp.qr_code,
        secret: result.data.totp.secret,
      });
    } catch (cause) {
      setMfaError(cause instanceof Error ? cause.message : "Could not start MFA setup.");
    } finally {
      setMfaBusy(false);
    }
  }

  async function verifyCode() {
    const activeFactorId = enrollment?.factorId ?? factorId;
    if (!activeFactorId || !/^\d{6}$/.test(code.trim())) {
      setMfaError("Enter the current 6-digit code from your authenticator app.");
      return;
    }
    setMfaBusy(true);
    setMfaError("");
    const result = await supabase.auth.mfa.challengeAndVerify({
      factorId: activeFactorId,
      code: code.trim(),
    });
    setMfaBusy(false);
    if (result.error) {
      setMfaError(result.error.message || "Verification failed.");
      return;
    }
    setEnrollment(null);
    setCode("");
    setFactorId(activeFactorId);
    onToast("Two-factor authentication enabled");
    void refreshMfa();
  }

  async function disableMfa() {
    if (!factorId) return;
    setMfaBusy(true);
    setMfaError("");
    const result = await supabase.auth.mfa.unenroll({ factorId });
    setMfaBusy(false);
    if (result.error) {
      setMfaError(result.error.message);
      return;
    }
    setFactorId(null);
    onToast("Two-factor authentication disabled");
  }

  return (
    <div className="space-y-4">
      <FreelancerCard
        title={hasPasswordProvider === false ? "Set a password" : "Change password"}
      >
        <p className="text-sm text-text-secondary">
          {hasPasswordProvider === false
            ? "You signed in with Google. Set a password first so you can also sign in with email, and to unlock password changes later."
            : "Enter your current password, then choose a new one (Supabase Auth)."}
        </p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {hasPasswordProvider !== false && (
            <label className="block text-sm font-semibold text-navy sm:col-span-2">
              Current password
              <input
                type="password"
                autoComplete="current-password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5"
              />
            </label>
          )}
          <label className="block text-sm font-semibold text-navy">
            {hasPasswordProvider === false ? "New password" : "New password"}
            <input
              type="password"
              autoComplete="new-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2.5"
            />
          </label>
          <label className="block text-sm font-semibold text-navy">
            Confirm password
            <input
              type="password"
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2.5"
            />
          </label>
        </div>
        {pwError && <p className="mt-2 text-sm text-error">{pwError}</p>}
        <div className="mt-4">
          <PrimaryButton onClick={changePassword} disabled={pwBusy || hasPasswordProvider === null}>
            {pwBusy
              ? "Updating…"
              : hasPasswordProvider === false
                ? "Set password"
                : "Update password"}
          </PrimaryButton>
        </div>
      </FreelancerCard>

      <FreelancerCard title="Two-factor authentication (Google Authenticator)">
        {!plus ? (
          <div className="rounded-xl border border-amber-200 bg-amber-50 p-4">
            <p className="font-semibold text-navy">Pro Plus required for MFA</p>
            <p className="mt-1 text-sm text-text-secondary">
              Authenticator-app (TOTP) two-factor authentication is included with Pro Plus, along
              with Connect and a 50GB vault.
            </p>
            <div className="mt-3">
              <PrimaryButton href="/edition">Upgrade to Pro Plus</PrimaryButton>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              Protect your account with a TOTP code from Google Authenticator or any compatible
              app.
            </p>
            {!mfaReady ? (
              <p className="text-sm text-text-muted">Checking MFA status…</p>
            ) : enrollment ? (
              <div className="space-y-3">
                <p className="text-sm text-navy">
                  Scan this QR code, then enter the 6-digit code to finish setup.
                </p>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={enrollment.qrCode}
                  alt="MFA QR code"
                  className="mx-auto h-48 w-48 rounded-lg border border-border bg-white p-2"
                />
                <details className="text-xs text-text-secondary">
                  <summary className="cursor-pointer font-medium">Cannot scan?</summary>
                  <code className="mt-2 block break-all rounded bg-background p-2">
                    {enrollment.secret}
                  </code>
                </details>
                <label className="block text-sm font-semibold text-navy">
                  6-digit code
                  <input
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={6}
                    value={code}
                    onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                    className="mt-1 w-full max-w-xs rounded-xl border border-border px-3 py-2.5"
                  />
                </label>
                <PrimaryButton onClick={verifyCode} disabled={mfaBusy || code.length !== 6}>
                  {mfaBusy ? "Verifying…" : "Verify and enable"}
                </PrimaryButton>
              </div>
            ) : factorId ? (
              <div className="flex flex-wrap items-center gap-2">
                <StatusPill tone="green">Enabled</StatusPill>
                <OutlineButton onClick={disableMfa} disabled={mfaBusy}>
                  {mfaBusy ? "Working…" : "Disable 2FA"}
                </OutlineButton>
              </div>
            ) : (
              <PrimaryButton onClick={startEnrollment} disabled={mfaBusy}>
                {mfaBusy ? "Preparing…" : "Set up authenticator app"}
              </PrimaryButton>
            )}
            {mfaError && <p className="text-sm text-error">{mfaError}</p>}
          </div>
        )}
      </FreelancerCard>
    </div>
  );
}

function AppsTab({
  hasStripeBilling,
  plus,
  googleConfigured,
  googleCalendarConnected,
}: {
  hasStripeBilling: boolean;
  plus: boolean;
  googleConfigured: boolean;
  googleCalendarConnected: boolean;
}) {
  const apps = [
    {
      name: "Google",
      desc: "Sign in with Google OAuth",
      icon: Globe,
      connected: false,
      href: "/login",
      manage: false,
      cta: "Connect",
    },
    {
      name: "CLIVORA Connect",
      desc: "Private hiring board and job posts",
      icon: Store,
      connected: true,
      href: "/app/connect/manage",
      manage: false,
      cta: "Manage",
    },
    {
      name: "Google Calendar",
      desc: googleConfigured
        ? googleCalendarConnected
          ? "Connected - manage meetings and sync"
          : "OAuth ready - connect your Google account"
        : "Configure GOOGLE_CLIENT_ID / SECRET on the server",
      icon: Calendar,
      connected: googleCalendarConnected,
      href: googleConfigured
        ? googleCalendarConnected
          ? "/app/meetings?calendar=google"
          : "/api/integrations/google/calendar/start"
        : "/app/meetings?calendar=google",
      manage: false,
      cta: googleConfigured
        ? googleCalendarConnected
          ? "Open Meetings"
          : "Connect Google"
        : "Configure Google OAuth",
      statusLabel: googleCalendarConnected
        ? "Connected"
        : googleConfigured
          ? "Not connected"
          : "Not configured",
    },
    {
      name: "Meetings (Jitsi)",
      desc: "Instant video rooms for client calls",
      icon: Calendar,
      connected: true,
      href: "/app/meetings",
      manage: false,
      cta: "Open",
      statusLabel: "Available",
    },
  ];

  return (
    <FreelancerCard title="Apps & Integrations">
      <div className="grid gap-3 sm:grid-cols-2">
        {apps.map((app) => {
          const Icon = app.icon;
          const status = "statusLabel" in app && app.statusLabel
            ? app.statusLabel
            : app.connected
              ? "Connected"
              : "Not connected";
          const tone =
            status === "Connected" || status === "Available"
              ? "green"
              : status === "Not configured"
                ? "gray"
                : "gray";
          return (
            <div
              key={app.name}
              className="flex flex-col gap-3 rounded-2xl border border-border bg-gradient-to-br from-white to-primary/5 p-4 shadow-sm"
            >
              <div className="flex items-start justify-between gap-2">
                <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <Icon className="h-5 w-5" />
                </span>
                <StatusPill tone={tone}>{status}</StatusPill>
              </div>
              <div>
                <p className="font-bold text-navy">{app.name}</p>
                <p className="mt-0.5 text-xs text-text-secondary">{app.desc}</p>
              </div>
              <div className="mt-auto">
                {app.manage ? (
                  <ManageBillingButton />
                ) : (
                  <OutlineButton href={app.href}>{app.cta}</OutlineButton>
                )}
              </div>
            </div>
          );
        })}
      </div>
      <p className="mt-4 flex items-center gap-2 text-xs text-text-muted">
        <Link2 className="h-3.5 w-3.5" />
        More integrations ship with the Android app and Pro Plus.
      </p>
    </FreelancerCard>
  );
}
