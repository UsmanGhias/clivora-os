import Link from "next/link";
import { redirect } from "next/navigation";
import type { LucideIcon } from "lucide-react";
import {
  Briefcase,
  Calendar,
  CreditCard,
  FileText,
  FolderKanban,
  Gift,
  Headphones,
  LayoutDashboard,
  MessageSquare,
  Network,
  Sparkles,
  Users,
} from "lucide-react";
import { getProfile, isClientAccount, isPro, planLabel } from "@/lib/profile";
import { site } from "@/lib/site";
import { SmartAppCta } from "@/components/app/SmartAppCta";
import { getHubKpis } from "@/lib/hub-kpis";

/** Freelancer hub, mirrors Flutter /more with app-preferred tools called out. */
export default async function HubPage() {
  const profile = await getProfile();
  if (isClientAccount(profile)) redirect("/app/team");
  const plan = planLabel(profile);
  const pro = isPro(profile);
  const kpis = profile?.id
    ? await getHubKpis(profile.id)
    : { overdueInvoices: 0, pendingConnect: 0, profileCompleteness: null };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-extrabold">Hub</h1>
        <p className="text-sm text-text-secondary">
          Command center · plan {plan}. Alerts first, then quick create and tools.
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <div className="rounded-2xl border border-border bg-surface p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-text-muted">Overdue invoices</p>
          <p className="mt-1 text-2xl font-extrabold text-primary">{kpis.overdueInvoices}</p>
        </div>
        <div className="rounded-2xl border border-border bg-surface p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-text-muted">Connect pending</p>
          <p className="mt-1 text-2xl font-extrabold text-primary">{kpis.pendingConnect}</p>
        </div>
        <div className="rounded-2xl border border-border bg-surface p-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-text-muted">Profile readiness</p>
          <p className="mt-1 text-2xl font-extrabold text-primary">
            {kpis.profileCompleteness == null ? "-" : `${kpis.profileCompleteness}%`}
          </p>
        </div>
      </div>

      <div className="rounded-2xl bg-navy p-5 text-white">
        <p className="text-sm text-white/70">{profile?.email}</p>
        <p className="mt-1 text-xl font-extrabold">{profile?.name || "Freelancer"}</p>
        <p className="mt-2 text-sm">Plan: {plan}</p>
        <p className="mt-3 text-xs text-white/65">
          Today: {kpis.overdueInvoices} overdue invoice{kpis.overdueInvoices === 1 ? "" : "s"},{" "}
          {kpis.pendingConnect} Connect request{kpis.pendingConnect === 1 ? "" : "s"} waiting,{" "}
          {kpis.profileCompleteness != null
            ? `${kpis.profileCompleteness}% Connect profile complete`
            : "publish a Connect listing to rank higher"}
          .
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-3">
        <HubLink
          href="/app/invoices"
          title="What's overdue?"
          body={`${kpis.overdueInvoices} invoice${kpis.overdueInvoices === 1 ? "" : "s"} past due`}
          icon={FileText}
          tone="amber"
        />
        <HubLink
          href="/connect"
          title="Needs action"
          body={`${kpis.pendingConnect} pending Connect request${kpis.pendingConnect === 1 ? "" : "s"}`}
          icon={Network}
          tone="teal"
        />
        <HubLink
          href="/app/connect/manage"
          title="Trust profile"
          body={
            kpis.profileCompleteness != null
              ? `${kpis.profileCompleteness}% complete · ratings & listing`
              : "Create listing · ratings · completeness"
          }
          icon={Sparkles}
          tone="sky"
        />
      </div>

      <div>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-text-secondary">
          Available on web
        </h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <HubLink href="/app/clients" title="Clients" body="Cloud CRM" icon={Users} />
          <HubLink href="/app/projects" title="Work" body="Projects" icon={FolderKanban} />
          <HubLink href="/app/invoices" title="Billing" body="Invoices" icon={FileText} />
          <HubLink href="/app/messages" title="Messages" body="Cloud inbox" icon={MessageSquare} />
          <HubLink href="/app/timesheets" title="Timesheets" body="Log & approve time" icon={Calendar} />
          <HubLink href="/app/meetings" title="Meetings" body="Jitsi video rooms" icon={Briefcase} />
          <HubLink href="/app/support" title="Support" body="Submit a ticket" icon={Headphones} />
          <HubLink href="/connect" title="CLIVORA Connect" body="Private hiring board" icon={Network} />
          <HubLink
            href="/app/settings"
            title="Community edition"
            body="All features included, no paid tiers"
            icon={CreditCard}
            tone="teal"
          />
        </div>
      </div>

      <div>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-text-secondary">
          Best in the mobile app
        </h2>
        <div className="grid gap-3 sm:grid-cols-2">
          <AppPreferred title="Offline SQLite Outbox" body="Local Drift sync & biometrics" icon={Sparkles} />
          <AppPreferred title="Calendar & time" body="Scheduling and timers" icon={Calendar} />
          <AppPreferred title="Reports & analytics" body="Revenue charts" icon={LayoutDashboard} />
          <AppPreferred title="Contracts & vault" body="PDFs and secure files" icon={FileText} />
          <AppPreferred title="Automations" body="Workflows & reminders" icon={Briefcase} />
          <AppPreferred title="Team & biometrics" body="Seats and lock screen" icon={Users} />
        </div>
      </div>


      <SmartAppCta
        title="Open the full freelancer toolkit"
        body="Expenses, notes, quotes, products, recurring invoices, backup, and offline CRM sync on Android."
        deepPath="open/more"
      />
    </div>
  );
}

const toneClass: Record<string, string> = {
  teal: "bg-teal-100 text-teal-800",
  amber: "bg-amber-100 text-amber-900",
  sky: "bg-sky-100 text-sky-800",
  navy: "bg-navy/10 text-navy",
};

function HubLink({
  href,
  title,
  body,
  icon: Icon,
  tone = "navy",
}: {
  href: string;
  title: string;
  body: string;
  icon: LucideIcon;
  tone?: keyof typeof toneClass;
}) {
  return (
    <Link
      href={href}
      className="flex items-start gap-3 rounded-2xl border border-border bg-surface p-4 transition hover:border-primary/40"
    >
      <span
        className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl ${toneClass[tone] ?? toneClass.navy}`}
      >
        <Icon className="h-5 w-5" />
      </span>
      <span className="min-w-0">
        <p className="font-bold text-navy">{title}</p>
        <p className="text-sm text-text-secondary">{body}</p>
      </span>
    </Link>
  );
}

function AppPreferred({
  title,
  body,
  icon: Icon,
}: {
  title: string;
  body: string;
  icon: LucideIcon;
}) {
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-dashed border-primary/30 bg-primary/5 p-4">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary/15 text-primary-dark">
        <Icon className="h-5 w-5" />
      </span>
      <div>
        <p className="font-bold text-navy">{title}</p>
        <p className="text-sm text-text-secondary">{body}</p>
        <p className="mt-1 text-[11px] font-semibold uppercase tracking-wide text-primary-dark">
          App preferred
        </p>
      </div>
    </div>
  );
}
