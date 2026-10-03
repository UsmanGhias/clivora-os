"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  BadgeCheck,
  Bell,
  CreditCard,
  KeyRound,
  Trash2,
  HelpCircle,
  Headphones,
  User,
  Shield,
  Wallet,
  Users,
  SlidersHorizontal,
  AppWindow,
} from "lucide-react";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientStatCard,
  ClientStatusPill,
  money,
} from "@/components/client/ui";
import { ManageBillingButton } from "@/components/app/ManageBillingButton";
import { DeleteAccountPanel } from "@/components/settings/DeleteAccountPanel";
import { ProfileEditForm } from "@/components/freelancer/ProfileEditForm";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import type { Profile } from "@/lib/profile-types";
import { useRouter } from "next/navigation";

const NAV = [
  { key: "account", label: "Account & profile", icon: User },
  { key: "notifications", label: "Notifications", icon: Bell },
  { key: "security", label: "Security", icon: Shield },
  { key: "payment", label: "Payment methods", icon: CreditCard },
  { key: "billing", label: "Billing & plans", icon: Wallet },
  { key: "team", label: "Team", icon: Users },
  { key: "preferences", label: "Preferences", icon: SlidersHorizontal },
  { key: "apps", label: "Connected apps", icon: AppWindow },
] as const;

type Props = {
  profile: Profile;
  plan: string;
  plus: boolean;
  stats: {
    jobsPosted: number;
    activeProjects: number;
    invoices: number;
    totalSpent: number;
  };
};

export function ClientSettingsPanel({ profile, plan, plus, stats }: Props) {
  const router = useRouter();
  const [tab, setTab] = useState<(typeof NAV)[number]["key"]>("account");
  const [name, setName] = useState(profile.name ?? "");
  const [savingProfile, setSavingProfile] = useState(false);
  const [profileMsg, setProfileMsg] = useState<string | null>(null);
  const [profileErr, setProfileErr] = useState<string | null>(null);
  const [editingProfile, setEditingProfile] = useState(false);

  const memberSince = useMemo(() => {
    const raw = profile.updated_at || profile.created_at;
    if (!raw) return null;
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) return null;
    return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
  }, [profile.updated_at, profile.created_at]);

  async function saveProfile() {
    setSavingProfile(true);
    setProfileMsg(null);
    setProfileErr(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const trimmed = name.trim();
      if (!trimmed) throw new Error("Name is required");
      const { error } = await supabase
        .from("profiles")
        .update({ name: trimmed, updated_at: new Date().toISOString() })
        .eq("id", user.id);
      if (error) throw error;
      setProfileMsg("Profile saved. Changes sync to web and Android.");
      router.refresh();
    } catch (err) {
      setProfileErr(err instanceof Error ? err.message : "Could not save profile");
    } finally {
      setSavingProfile(false);
    }
  }

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader title="Settings" subtitle="Manage your account, billing, and preferences." />

      <div className="grid gap-6 lg:grid-cols-[220px_1fr]">
        <nav className="space-y-0.5 rounded-2xl border border-border bg-surface p-2 shadow-sm">
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
                    ? "border-l-4 border-client-accent bg-client-surface text-navy"
                    : "text-text-secondary hover:bg-client-surface/60",
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
            <>
              <ClientCard title="Account & profile">
                {editingProfile ? (
                  <ProfileEditForm
                    profile={profile}
                    onSaved={() => {
                      setEditingProfile(false);
                      setProfileMsg("Profile photo and name saved.");
                      router.refresh();
                    }}
                    onCancel={() => setEditingProfile(false)}
                  />
                ) : (
                <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
                  <div className="flex min-w-0 flex-1 items-start gap-4">
                    <span className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-full bg-navy text-xl font-bold text-white">
                      {profile.avatar_url ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={profile.avatar_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        (profile.name || profile.email || "?").charAt(0).toUpperCase()
                      )}
                    </span>
                    <div className="min-w-0 flex-1 space-y-3">
                      <div>
                        <label htmlFor="client-display-name" className="text-xs font-semibold uppercase text-text-muted">
                          Display name
                        </label>
                        <input
                          id="client-display-name"
                          value={name}
                          onChange={(e) => setName(e.target.value)}
                          className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm font-semibold text-navy outline-none focus:ring-2 focus:ring-client-accent"
                        />
                      </div>
                      <div>
                        <p className="text-xs font-semibold uppercase text-text-muted">Email</p>
                        <p className="mt-1 text-sm text-text-secondary">{profile.email}</p>
                      </div>
                      <div className="flex flex-wrap items-center gap-2">
                        {plus ? (
                          <ClientStatusPill tone="green">
                            <span className="inline-flex items-center gap-1">
                              <BadgeCheck className="h-3 w-3" /> Verified
                            </span>
                          </ClientStatusPill>
                        ) : (
                          <ClientStatusPill tone="blue">{plan}</ClientStatusPill>
                        )}
                        <span className="text-xs text-text-muted">Client account</span>
                      </div>
                      {memberSince && (
                        <p className="text-xs text-text-muted">Member since {memberSince}</p>
                      )}
                      {profileErr && <p className="text-sm text-error">{profileErr}</p>}
                      {profileMsg && <p className="text-sm text-success">{profileMsg}</p>}
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          disabled={savingProfile || !name.trim()}
                          onClick={() => void saveProfile()}
                          className="rounded-xl bg-client-accent px-4 py-2 text-sm font-bold text-white disabled:opacity-50"
                        >
                          {savingProfile ? "Saving…" : "Save name"}
                        </button>
                        <button
                          type="button"
                          onClick={() => setEditingProfile(true)}
                          className="rounded-xl border border-border px-4 py-2 text-sm font-bold text-navy hover:bg-client-surface"
                        >
                          Change photo
                        </button>
                      </div>
                    </div>
                  </div>
                  <div className="rounded-xl border border-border bg-client-surface/50 p-4">
                    <p className="text-xs font-semibold uppercase text-text-muted">Plan</p>
                    <div className="mt-1 flex items-center gap-2">
                      <p className="font-bold text-navy">{plan}</p>
                      {plus && <ClientStatusPill tone="green">Active</ClientStatusPill>}
                    </div>
                    <p className="mt-1 text-xs text-text-secondary">
                      {plus
                        ? "Manual, JazzCash, bank, or Google Play approvals."
                        : "Upgrade anytime from checkout."}
                    </p>
                    <div className="mt-3">
                      <ManageBillingButton />
                    </div>
                  </div>
                </div>
                )}
              </ClientCard>

              <DeleteAccountPanel email={profile.email || ""} />

              <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                <ClientStatCard
                  label="Jobs posted"
                  value={stats.jobsPosted}
                  sub="View all jobs →"
                  href="/app/connect/manage"
                  icon={User}
                  iconTone="bg-violet-100 text-violet-700"
                />
                <ClientStatCard
                  label="Active projects"
                  value={stats.activeProjects}
                  sub="View all projects →"
                  href="/app/projects"
                  icon={Users}
                  iconTone="bg-emerald-100 text-emerald-700"
                />
                <ClientStatCard
                  label="Invoices"
                  value={stats.invoices}
                  sub="View all invoices →"
                  href="/app/invoices"
                  icon={CreditCard}
                  iconTone="bg-sky-100 text-sky-800"
                />
                <ClientStatCard
                  label="Total spent"
                  value={money(stats.totalSpent, 0)}
                  sub="View payments →"
                  href="/app/payments"
                  icon={Wallet}
                  iconTone="bg-amber-100 text-amber-800"
                />
              </div>

              <ClientCard title="Quick actions">
                <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
                  {[
                    { label: "Change password", icon: KeyRound, href: "#", danger: false },
                    { label: "Payment methods", icon: CreditCard, href: "/app/payments/payment-methods", danger: false },
                    { label: "Notification settings", icon: Bell, href: "#", danger: false },
                    { label: "Delete account", icon: Trash2, href: "#", danger: true },
                  ].map((a) => {
                    const Icon = a.icon;
                    return (
                      <Link
                        key={a.label}
                        href={a.href}
                        onClick={(e) => {
                          if (a.href === "#") {
                            e.preventDefault();
                            if (a.label === "Change password") setTab("security");
                            if (a.label === "Notification settings") setTab("notifications");
                            if (a.label === "Delete account") {
                              document.getElementById("delete-account")?.scrollIntoView({ behavior: "smooth" });
                            }
                          }
                        }}
                        className={cn(
                          "flex items-center gap-3 rounded-xl border border-border p-4 transition hover:bg-client-surface",
                          a.danger && "hover:border-error/40",
                        )}
                      >
                        <span
                          className={cn(
                            "flex h-10 w-10 items-center justify-center rounded-xl",
                            a.danger ? "bg-red-50 text-error" : "bg-client-surface text-client-accent",
                          )}
                        >
                          <Icon className="h-5 w-5" />
                        </span>
                        <span
                          className={cn(
                            "text-sm font-semibold",
                            a.danger ? "text-error" : "text-navy",
                          )}
                        >
                          {a.label}
                        </span>
                      </Link>
                    );
                  })}
                </div>
              </ClientCard>
            </>
          )}

          {tab === "notifications" && (
            <ClientCard title="Notification settings">
              <ul className="space-y-3">
                {[
                  "New proposals",
                  "Invoice updates",
                  "Project milestones",
                  "Messages from freelancers",
                  "Marketing emails",
                ].map((label) => (
                  <li
                    key={label}
                    className="flex items-center justify-between rounded-xl border border-border px-4 py-3"
                  >
                    <span className="text-sm font-semibold text-navy">{label}</span>
                    <input type="checkbox" defaultChecked className="h-4 w-4 accent-client-accent" />
                  </li>
                ))}
              </ul>
            </ClientCard>
          )}

          {tab === "security" && (
            <ClientSecurityTab />
          )}

          {(tab === "payment" || tab === "billing") && (
            <ClientCard title={tab === "payment" ? "Payment methods" : "Billing & plans"}>
              <p className="text-sm text-text-secondary">
                {tab === "payment"
                  ? "JazzCash, Easypaisa, bank transfer, and Google Play are used for Pro upgrades. Hiring invoices go direct between you and freelancers."
                  : `You are on ${plan}. Renewals: SafePay or JazzCash/bank on the website, or Google Play inside the Android app - not Stripe.`}
              </p>
              <div className="mt-4">
                <ManageBillingButton />
              </div>
            </ClientCard>
          )}

          {(tab === "team" || tab === "preferences" || tab === "apps") && (
            <ClientCard title={NAV.find((n) => n.key === tab)?.label}>
              <p className="text-sm text-text-secondary">
                Configure {NAV.find((n) => n.key === tab)?.label.toLowerCase()} for your client
                workspace. More controls are rolling out with Pro Plus.
              </p>
              <Link href="/edition" className="mt-4 inline-block text-sm font-semibold text-client-accent">
                Learn more about Pro Plus →
              </Link>
            </ClientCard>
          )}

          <div className="flex flex-col gap-3 rounded-2xl border border-sky-100 bg-sky-50 p-5 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-sky-100 text-sky-700">
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
              <ClientPrimaryButton href="/app/support">Visit Help Center</ClientPrimaryButton>
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-client-accent text-white">
                <Headphones className="h-5 w-5" />
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function ClientSecurityTab() {
  const supabase = useMemo(() => createClient(), []);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [hasPasswordProvider, setHasPasswordProvider] = useState<boolean | null>(null);
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [ok, setOk] = useState("");

  useEffect(() => {
    (async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setEmail(user.email ?? "");
      const identities = user.identities ?? [];
      const emailIdentity = identities.some((i) => i.provider === "email");
      const onlyOAuth =
        !emailIdentity && identities.some((i) => i.provider === "google" || i.provider === "apple");
      setHasPasswordProvider(!onlyOAuth);
    })();
  }, [supabase]);

  async function save() {
    setError("");
    setOk("");
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Passwords do not match.");
      return;
    }
    setBusy(true);
    try {
      if (hasPasswordProvider) {
        if (!currentPassword) {
          setError("Enter your current password.");
          return;
        }
        if (!email) {
          setError("No email on this account.");
          return;
        }
        const { error: reauthErr } = await supabase.auth.signInWithPassword({
          email,
          password: currentPassword,
        });
        if (reauthErr) {
          setError("Current password is incorrect.");
          return;
        }
      }
      const { error: updErr } = await supabase.auth.updateUser({ password });
      if (updErr) {
        setError(updErr.message);
        return;
      }
      setPassword("");
      setConfirm("");
      setCurrentPassword("");
      setHasPasswordProvider(true);
      setOk(hasPasswordProvider ? "Password updated." : "Password set successfully.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ClientCard title={hasPasswordProvider === false ? "Set a password" : "Change password"}>
      <p className="text-sm text-text-secondary">
        {hasPasswordProvider === false
          ? "You signed in with Google. Set a password so you can also use email login."
          : "Confirm your current password before setting a new one."}
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
          New password
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
      {error && <p className="mt-2 text-sm text-error">{error}</p>}
      {ok && <p className="mt-2 text-sm font-semibold text-primary-dark">{ok}</p>}
      <div className="mt-4">
        <button
          type="button"
          onClick={() => void save()}
          disabled={busy || hasPasswordProvider === null}
          className="inline-flex min-h-10 items-center justify-center gap-1.5 rounded-xl bg-client-accent px-4 py-2.5 text-sm font-bold text-white hover:bg-client-header disabled:opacity-60"
        >
          {busy ? "Saving…" : hasPasswordProvider === false ? "Set password" : "Update password"}
        </button>
      </div>
    </ClientCard>
  );
}
