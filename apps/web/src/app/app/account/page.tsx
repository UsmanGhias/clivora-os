import { redirect } from "next/navigation";
import Link from "next/link";
import {
  BadgeCheck,
  Bell,
  CreditCard,
  Gift,
  MapPin,
  ShieldCheck,
  Star,
  TrendingUp,
  Briefcase,
  Clock,
} from "lucide-react";
import { getProfile, isClientAccount, planLabel } from "@/lib/profile";
import { isPro, isProPlus } from "@/lib/plan";
import { createClient } from "@/lib/supabase/server";
import { loadFreelancerFinance } from "@/lib/freelancer-finance";
import { ManageBillingButton } from "@/components/app/ManageBillingButton";
import { SmartAppCta } from "@/components/app/SmartAppCta";
import { AccountProfileEditor } from "@/components/freelancer/AccountProfileEditor";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  OutlineButton,
  PrimaryButton,
  StatusPill,
  money,
} from "@/components/freelancer/ui";
import { skillsList } from "@/lib/connect-types";

export const metadata = { title: "My Profile" };

export default async function AccountPage({
  searchParams,
}: {
  searchParams?: Promise<{ edit?: string }>;
}) {
  const profile = await getProfile();
  if (!profile) redirect("/login");

  const client = isClientAccount(profile);
  const params = searchParams ? await searchParams : {};
  const editing = params.edit === "1" || params.edit === "true";

  if (client) {
    return (
      <div className="space-y-6 pb-10 theme-client">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy">My Account</h1>
          <p className="mt-1 text-sm text-text-secondary">
            Profile, notifications, and client workspace shortcuts.
          </p>
        </div>

        {editing && (
          <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
            <h2 className="font-semibold text-navy">Edit profile</h2>
            <div className="mt-3">
              <AccountProfileEditor profile={profile} />
            </div>
          </div>
        )}

        <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
            <div className="relative">
              {profile.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={profile.avatar_url}
                  alt=""
                  className="h-24 w-24 rounded-full object-cover"
                />
              ) : (
                <span className="flex h-24 w-24 items-center justify-center rounded-full bg-navy text-3xl font-bold text-white">
                  {(profile.name || "?").charAt(0).toUpperCase()}
                </span>
              )}
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="font-display text-xl font-extrabold text-navy">
                {profile.name || "Client"}
              </h2>
              <p className="mt-1 text-xs text-text-muted">{profile.email}</p>
              <div className="mt-4 flex flex-wrap gap-2">
                <PrimaryButton href="/app/account?edit=1">Edit Profile</PrimaryButton>
                <OutlineButton href="/app/settings">Settings</OutlineButton>
                <OutlineButton href="/app/hub">Client Hub</OutlineButton>
              </div>
            </div>
          </div>
        </div>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {[
            { href: "/app/messages", label: "Messages", icon: Bell },
            { href: "/app/notifications", label: "Notifications", icon: Bell },
            { href: "/app/contracts", label: "Contracts", icon: ShieldCheck },
            { href: "/app/invoices", label: "Invoices", icon: CreditCard },
            { href: "/app/projects", label: "Projects", icon: Briefcase },
            { href: "/app/connect", label: "Connect", icon: Star },
          ].map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-3 rounded-2xl border border-border bg-surface px-4 py-3 shadow-sm transition hover:border-client-accent/40"
            >
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-client-surface text-client-accent">
                <item.icon className="h-5 w-5" />
              </span>
              <span className="font-semibold text-navy">{item.label}</span>
            </Link>
          ))}
        </div>
      </div>
    );
  }

  const plus = isProPlus(profile);
  const pro = isPro(profile);
  const plan = planLabel(profile);
  const fin = await loadFreelancerFinance(profile.id);
  const supabase = await createClient();

  let location: string | null = null;
  let avgRating: number | null = null;
  let reviewCount = 0;
  let completeness = 0;
  let headline = profile.name ? `${profile.name}` : "Freelancer profile";
  let hasConnectProfile = false;
  let skillsCount = 0;
  let hasConnectHeadline = false;
  let isListed = false;

  try {
    const { data: cp } = await supabase
      .from("connect_profiles")
      .select(
        "location_label, avg_rating, review_count, profile_completeness, headline, display_title, skills, is_listed",
      )
      .eq("user_id", profile.id)
      .maybeSingle();
    if (cp) {
      hasConnectProfile = true;
      location = cp.location_label || null;
      avgRating = cp.avg_rating != null ? Number(cp.avg_rating) : null;
      reviewCount = Number(cp.review_count || 0);
      completeness = Math.round(Number(cp.profile_completeness ?? 0));
      headline = cp.headline || cp.display_title || headline;
      skillsCount = skillsList(cp.skills).length;
      hasConnectHeadline = Boolean(String(cp.headline || cp.display_title || "").trim());
      isListed = Boolean(cp.is_listed);
    }
  } catch {
    /* ignore */
  }

  const checklist = [
    { label: "Photo", done: Boolean(profile.avatar_url), href: "/app/account?edit=1" },
    { label: "Skills", done: skillsCount > 0, href: "/app/connect/manage" },
    { label: "Headline", done: hasConnectHeadline, href: "/app/connect/manage" },
    { label: "Connect listing", done: isListed, href: "/app/connect/manage" },
    { label: "Verified email", done: Boolean(profile.email), href: "/app/settings" },
  ] as const;
  const derivedCompleteness = Math.round(
    (checklist.filter((i) => i.done).length / checklist.length) * 100,
  );
  if (!completeness) completeness = derivedCompleteness;

  const r = 40;
  const c = 2 * Math.PI * r;
  const offset = c - (Math.min(100, completeness) / 100) * c;

  const publicProfileHref = hasConnectProfile
    ? isListed
      ? `/app/connect?tab=talent&q=${encodeURIComponent(profile.name || "")}`
      : "/app/connect/manage"
    : "/app/connect/manage";

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader title="My Profile" subtitle={headline} />

      {editing && (
        <FreelancerCard title="Edit profile">
          <AccountProfileEditor profile={profile} />
          <p className="mt-4 text-xs text-text-muted">
            For Connect listing fields (skills, rate, bio), use{" "}
            <Link href="/app/connect/manage" className="font-semibold text-primary">
              Manage Connect
            </Link>
            .
          </p>
        </FreelancerCard>
      )}

      <div className="grid gap-4 lg:grid-cols-[1fr_280px]">
        <FreelancerCard>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
            <div className="relative">
              {profile.avatar_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={profile.avatar_url}
                  alt=""
                  className="h-20 w-20 rounded-full object-cover"
                />
              ) : (
                <span className="flex h-20 w-20 items-center justify-center rounded-full bg-navy text-2xl font-bold text-white">
                  {(profile.name || "?").charAt(0).toUpperCase()}
                </span>
              )}
              <span className="absolute bottom-1 right-1 h-3.5 w-3.5 rounded-full border-2 border-white bg-success" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="font-display text-lg font-extrabold text-navy sm:text-xl">
                  {profile.name || "Freelancer"}
                </h2>
                {pro && (
                  <span
                    className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-bold text-emerald-700"
                    title={plus ? "Pro Plus" : "Pro"}
                  >
                    <BadgeCheck className="h-4 w-4" />
                    {plan}
                  </span>
                )}
              </div>
              <p className="mt-1 inline-flex items-center gap-1 text-sm text-text-secondary">
                <MapPin className="h-3.5 w-3.5" />
                {location || (hasConnectProfile ? "Location not set" : "Add location in Connect")}
              </p>
              <p className="mt-1 text-xs text-text-muted">{profile.email}</p>
              <div className="mt-4 flex flex-wrap gap-2">
                <PrimaryButton href="/app/account?edit=1">Edit Profile</PrimaryButton>
                <OutlineButton href="/app/connect/manage">Connect listing</OutlineButton>
                <OutlineButton href={publicProfileHref}>
                  {isListed ? "View in Connect" : "Set up public listing"}
                </OutlineButton>
              </div>
            </div>
          </div>
        </FreelancerCard>

        <FreelancerCard title={`${plan} Plan`}>
          <StatusPill tone={plus ? "green" : pro ? "teal" : "amber"}>{plan}</StatusPill>
          <ul className="mt-3 space-y-1 text-sm text-text-secondary">
            {plus ? (
              <>
                <li>• Unlimited proposals</li>
                <li>• Connect credits monthly</li>
                <li>• MFA + 50GB vault</li>
              </>
            ) : pro ? (
              <>
                <li>• Full CRM tools unlocked</li>
                <li>• Connect and MFA included</li>
              </>
            ) : (
              <>
                <li>• CRM tools on your plan</li>
                <li>• Connect and MFA included</li>
              </>
            )}
          </ul>
          <div className="mt-4">
            <ManageBillingButton />
          </div>
        </FreelancerCard>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <FreelancerStatCard
          label="Total Earnings"
          value={money(fin.totalRevenue)}
          icon={TrendingUp}
        />
        <FreelancerStatCard
          label="Total Projects"
          value={fin.projects.length}
          sub={`${fin.projects.filter((p) => !(p.status || "").includes("complet")).length} Active`}
          icon={Briefcase}
          iconTone="bg-sky-100 text-sky-800"
        />
        <FreelancerStatCard
          label="Average Rating"
          value={avgRating != null ? avgRating.toFixed(1) : "-"}
          sub={avgRating != null ? "★".repeat(Math.max(1, Math.round(avgRating))) : "No ratings yet"}
          icon={Star}
          iconTone="bg-amber-100 text-amber-700"
        />
        <FreelancerStatCard
          label="Total Reviews"
          value={reviewCount}
          sub={hasConnectProfile ? "From Connect" : "Complete Connect listing"}
          icon={Star}
          iconTone="bg-violet-100 text-violet-800"
          href="/app/reviews"
        />
        <FreelancerStatCard
          label="Response Time"
          value=" - "
          sub="Shown when message activity is available"
          icon={Clock}
          iconTone="bg-orange-100 text-orange-700"
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <FreelancerCard title="Account information" className="lg:col-span-1">
          <ul className="space-y-3 text-sm">
            {[
              ["Name", profile.name || "-", "/app/account?edit=1"],
              ["Email", profile.email || "-", "/app/settings"],
              ["Role", "Freelancer", "/app/settings"],
              ["Plan", plan, pro ? "/app/settings?tab=billing" : "/edition"],
            ].map(([k, v, href]) => (
              <li key={k} className="flex items-center justify-between gap-2 border-b border-border/70 pb-2">
                <div>
                  <p className="text-xs text-text-muted">{k}</p>
                  <p className="font-semibold text-navy">{v}</p>
                </div>
                <Link href={href} className="text-xs font-semibold text-primary">
                  {k === "Plan" && !pro ? "Upgrade" : "Edit"}
                </Link>
              </li>
            ))}
          </ul>
        </FreelancerCard>

        <FreelancerCard title="Quick actions">
          <ul className="space-y-2">
            {[
              { icon: CreditCard, label: "Edition", href: "/edition" },
              { icon: Gift, label: "Refer & Earn", href: "/app/referrals" },
              { icon: ShieldCheck, label: "Security Settings", href: "/app/settings?tab=security" },
              { icon: Bell, label: "Notification Preferences", href: "/app/settings?tab=notifications" },
            ].map((a) => (
              <li key={a.label}>
                <Link
                  href={a.href}
                  className="flex items-center gap-3 rounded-xl border border-border px-3 py-3 text-sm font-semibold text-navy hover:border-primary/40"
                >
                  <a.icon className="h-4 w-4 text-primary" />
                  {a.label}
                </Link>
              </li>
            ))}
          </ul>
        </FreelancerCard>

        <FreelancerCard title="Profile completion">
          <div className="flex flex-col items-center">
            <div className="relative h-28 w-28">
              <svg className="h-28 w-28 -rotate-90" viewBox="0 0 100 100">
                <circle cx="50" cy="50" r={r} fill="none" stroke="#E2E8F0" strokeWidth="10" />
                <circle
                  cx="50"
                  cy="50"
                  r={r}
                  fill="none"
                  stroke="#0D9488"
                  strokeWidth="10"
                  strokeLinecap="round"
                  strokeDasharray={c}
                  strokeDashoffset={offset}
                />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <p className="font-display text-xl font-extrabold text-navy">{completeness}%</p>
                <p className="text-[10px] font-semibold text-text-muted">Complete</p>
              </div>
            </div>
            <ul className="mt-4 w-full space-y-2 text-sm">
              {checklist.map((item) => (
                <li key={item.label} className="flex items-center justify-between gap-2 text-navy">
                  <span className="inline-flex items-center gap-2">
                    <span className={item.done ? "text-success" : "text-text-muted"}>
                      {item.done ? "✓" : "○"}
                    </span>
                    {item.label}
                  </span>
                  {!item.done && (
                    <Link href={item.href} className="text-xs font-semibold text-primary">
                      Fix
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </FreelancerCard>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <FreelancerCard title="Two-factor authentication (MFA)">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              {plus ? (
                <StatusPill tone="teal">Pro Plus</StatusPill>
              ) : (
                <StatusPill tone="amber">Upgrade for MFA</StatusPill>
              )}
              <p className="mt-2 text-sm text-text-secondary">
                MFA uses Supabase Auth TOTP. Available on Pro Plus.
              </p>
            </div>
            <PrimaryButton href="/app/settings?tab=security">Manage 2FA Settings</PrimaryButton>
          </div>
        </FreelancerCard>
        <SmartAppCta
          tone="freelancer"
          title="Manage your profile on the go"
          body="Use the Android app for offline CRM, vault, and richer profile tools."
          deepPath="open/dashboard"
        />
      </div>
    </div>
  );
}
