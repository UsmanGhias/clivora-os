import Link from "next/link";
import {
  Briefcase,
  DollarSign,
  FileText,
  MessageSquare,
  Plus,
  Sparkles,
  UserPlus,
  Users,
  Check,
  AlertCircle,
  ArrowRight,
} from "lucide-react";
import { EarningsLineChart, type EarningsPoint } from "@/components/dashboard/EarningsLineChart";
import { ProjectListCard, type DashboardProject } from "@/components/dashboard/ProjectListCard";
import { PeopleListCard, type PersonRow } from "@/components/dashboard/PeopleListCard";
import { DonutChart } from "@/components/dashboard/DonutChart";
import { ConnectCreditsWidget } from "@/components/connect/ConnectCreditsWidget";
import { portalGreeting } from "@/lib/portal-nav";
import type { ConnectCreditSummary } from "@/lib/connect-credits";
import { formatConnectCredits } from "@/lib/connect-credits";
import type { Profile } from "@/lib/profile-types";
import { isProPlus } from "@/lib/plan";
import { cn } from "@/lib/utils";
import { money } from "@/components/client/ui";

type HomeSummary = {
  open_jobs?: number;
  pending_proposals?: number;
  milestones_needing_action?: number;
  unread_messages?: number;
};

type Props = {
  profile: Profile;
  home: HomeSummary;
  projectCount: number;
  totalSpent: number;
  spendSeries?: EarningsPoint[];
  paidTotal: number;
  openBalances: number;
  refunds: number;
  outstanding?: number;
  credits: ConnectCreditSummary | null;
  activities: Array<{ id: string; title: string; detail: string; time: string; kind: string }>;
  projects: DashboardProject[];
  freelancers: PersonRow[];
  spendSlices: Array<{ name: string; value: number; color: string }>;
};

function ClientKpi({
  label,
  value,
  sub,
  linkLabel,
  href,
  icon: Icon,
  iconTone,
  trend,
}: {
  label: string;
  value: string | number;
  sub?: string;
  linkLabel?: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  iconTone: string;
  trend?: string;
}) {
  return (
    <Link
      href={href}
      className="rounded-2xl border border-border bg-surface p-4 shadow-sm transition hover:border-client-accent/40"
    >
      <div className="flex items-start justify-between gap-2">
        <span className={cn("flex h-10 w-10 items-center justify-center rounded-xl", iconTone)}>
          <Icon className="h-5 w-5" />
        </span>
        {trend && (
          <span className="rounded-lg bg-success/10 px-2 py-0.5 text-[10px] font-bold text-success">
            {trend}
          </span>
        )}
      </div>
      <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-text-muted">{label}</p>
      <p className="mt-1 font-display text-2xl font-extrabold text-navy">{value}</p>
      {sub && <p className="mt-1 text-xs text-text-secondary">{sub}</p>}
      {linkLabel && (
        <p className="mt-2 text-xs font-semibold text-client-accent">{linkLabel}</p>
      )}
    </Link>
  );
}

export function ClientDashboard({
  profile,
  home,
  projectCount,
  totalSpent,
  spendSeries,
  paidTotal,
  openBalances,
  refunds,
  outstanding = 0,
  credits,
  activities: _activities,
  projects,
  freelancers,
  spendSlices,
}: Props) {
  const plus = isProPlus(profile);
  const firstName = (profile.name || "there").split(" ")[0];
  const proposals = home.pending_proposals ?? 0;
  const unread = home.unread_messages ?? 0;
  const openJobs = home.open_jobs ?? 0;
  const inProgress = projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return s.includes("progress") || s === "active";
  }).length;
  const owed = outstanding || Math.max(0, totalSpent - paidTotal);

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">
            {portalGreeting()}, {firstName}! 👋
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            Hire talent, manage projects, and track everything in one place.
          </p>
          {credits && (
            <p className="mt-2 flex items-center gap-2 text-xs font-semibold text-text-secondary">
              <span className="inline-block h-2 w-2 rounded-full bg-success" />
              Connect Plan · {formatConnectCredits(credits)}
            </p>
          )}
        </div>
        <div className="flex flex-wrap gap-2">
          <Link
            href="/app/connect/manage"
            className="inline-flex min-h-11 items-center gap-1.5 rounded-xl bg-navy px-4 py-2.5 text-sm font-bold text-white hover:bg-navy-light"
          >
            <Plus className="h-4 w-4" />
            Post a job
          </Link>
          <Link
            href="/app/hub"
            className="inline-flex min-h-11 items-center gap-1.5 rounded-xl border-2 border-border bg-white px-4 py-2.5 text-sm font-bold text-navy hover:bg-client-surface"
          >
            <UserPlus className="h-4 w-4" />
            Invite team
          </Link>
        </div>
      </div>

      {/* Needs Your Attention Action Deck */}
      {proposals > 0 || unread > 0 || (home.milestones_needing_action ?? 0) > 0 || owed > 0 ? (
        <div className="rounded-2xl border border-amber-200/80 bg-gradient-to-r from-amber-50/70 via-orange-50/40 to-amber-50/50 p-4 sm:p-5 shadow-xs">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="flex h-7 w-7 items-center justify-center rounded-xl bg-amber-500 text-white shadow-xs">
                <AlertCircle className="h-4 w-4" />
              </span>
              <h2 className="font-display text-sm sm:text-base font-bold text-navy">
                Needs Your Attention
              </h2>
            </div>
            <span className="rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-bold text-amber-900">
              {[proposals > 0, unread > 0, (home.milestones_needing_action ?? 0) > 0, owed > 0].filter(Boolean).length} pending
            </span>
          </div>

          <div className="mt-3.5 grid gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
            {proposals > 0 && (
              <Link
                href="/app/proposals"
                className="group flex items-center justify-between rounded-xl border border-amber-200/90 bg-white p-3 shadow-2xs hover:border-amber-400 hover:shadow-xs transition"
              >
                <div>
                  <p className="text-xs font-bold text-navy group-hover:text-client-accent">
                    {proposals} New Proposal{proposals === 1 ? "" : "s"}
                  </p>
                  <p className="text-[11px] text-text-muted">Awaiting your review</p>
                </div>
                <ArrowRight className="h-4 w-4 text-text-muted group-hover:text-client-accent group-hover:translate-x-0.5 transition-transform" />
              </Link>
            )}

            {unread > 0 && (
              <Link
                href="/app/messages"
                className="group flex items-center justify-between rounded-xl border border-amber-200/90 bg-white p-3 shadow-2xs hover:border-amber-400 hover:shadow-xs transition"
              >
                <div>
                  <p className="text-xs font-bold text-navy group-hover:text-client-accent">
                    {unread} Unread Message{unread === 1 ? "" : "s"}
                  </p>
                  <p className="text-[11px] text-text-muted">Direct freelancer chat</p>
                </div>
                <ArrowRight className="h-4 w-4 text-text-muted group-hover:text-client-accent group-hover:translate-x-0.5 transition-transform" />
              </Link>
            )}

            {(home.milestones_needing_action ?? 0) > 0 && (
              <Link
                href="/app/projects"
                className="group flex items-center justify-between rounded-xl border border-amber-200/90 bg-white p-3 shadow-2xs hover:border-amber-400 hover:shadow-xs transition"
              >
                <div>
                  <p className="text-xs font-bold text-navy group-hover:text-client-accent">
                    {home.milestones_needing_action} Milestone Review{home.milestones_needing_action === 1 ? "" : "s"}
                  </p>
                  <p className="text-[11px] text-text-muted">Deliverables ready</p>
                </div>
                <ArrowRight className="h-4 w-4 text-text-muted group-hover:text-client-accent group-hover:translate-x-0.5 transition-transform" />
              </Link>
            )}

            {owed > 0 && (
              <Link
                href="/app/invoices"
                className="group flex items-center justify-between rounded-xl border border-amber-200/90 bg-white p-3 shadow-2xs hover:border-amber-400 hover:shadow-xs transition"
              >
                <div>
                  <p className="text-xs font-bold text-navy group-hover:text-client-accent">
                    {money(owed)} Due
                  </p>
                  <p className="text-[11px] text-text-muted">Pending settlement</p>
                </div>
                <ArrowRight className="h-4 w-4 text-text-muted group-hover:text-client-accent group-hover:translate-x-0.5 transition-transform" />
              </Link>
            )}
          </div>
        </div>
      ) : (
        <div className="flex items-center justify-between rounded-2xl border border-emerald-200/70 bg-emerald-50/40 px-4 py-3 text-xs">
          <div className="flex items-center gap-2">
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-emerald-100 text-emerald-700 font-bold">
              ✓
            </span>
            <span className="font-semibold text-emerald-950">
              All clear! No urgent actions needed on your contracts or proposals.
            </span>
          </div>
          <Link
            href="/app/connect"
            className="font-bold text-emerald-800 hover:underline"
          >
            Find Talent →
          </Link>
        </div>
      )}

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <ClientKpi
          label="Open Jobs"
          value={openJobs}
          sub="New applicants waiting"
          linkLabel="View all jobs →"
          href="/app/connect/manage"
          icon={Briefcase}
          iconTone="bg-sky-100 text-sky-800"
        />
        <ClientKpi
          label="Active Projects"
          value={projectCount}
          sub={`${inProgress || home.milestones_needing_action || 0} in progress`}
          linkLabel="View all projects →"
          href="/app/projects"
          icon={Users}
          iconTone="bg-violet-100 text-violet-700"
        />
        <ClientKpi
          label="Pending Proposals"
          value={proposals}
          sub="Awaiting your review"
          linkLabel="Review proposals →"
          href="/app/proposals"
          icon={FileText}
          iconTone="bg-amber-100 text-amber-800"
        />
        <ClientKpi
          label="Unread Messages"
          value={unread}
          sub="From freelancers"
          linkLabel="Go to inbox →"
          href="/app/messages"
          icon={MessageSquare}
          iconTone="bg-rose-100 text-rose-700"
        />
        <ClientKpi
          label="Total Spent"
          value={money(totalSpent)}
          sub="This month"
          trend={totalSpent > 0 ? "↑ 18.2% vs last month" : undefined}
          href="/app/invoices"
          icon={DollarSign}
          iconTone="bg-emerald-100 text-emerald-800"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_300px]">
        <div className="space-y-4">
          <EarningsLineChart
            total={totalSpent}
            accent="slate"
            title="Spending overview"
            trendLabel={totalSpent > 0 ? "Live invoice total" : undefined}
            showPreviousLegend
            series={spendSeries}
            summaryBoxes={[
              {
                label: "Open balances",
                value: money(openBalances),
                tone: "bg-sky-50 text-sky-800",
              },
              {
                label: "Paid to Freelancers",
                value: money(paidTotal),
                tone: "bg-violet-50 text-violet-800",
              },
              {
                label: "Refunds",
                value: money(refunds),
                tone: "bg-slate-50 text-slate-700",
              },
              {
                label: "Outstanding invoices",
                value: money(owed),
                tone: "bg-amber-50 text-amber-900",
              },
            ]}
          />

          <div className="grid gap-4 lg:grid-cols-3">
            <ProjectListCard projects={projects} isClient />
            <PeopleListCard
              title="Top freelancers"
              people={freelancers}
              href="/app/connect"
              isClient
              amountHeader="Rate"
            />
            <DonutChart
              title="Spending by category"
              slices={spendSlices}
              centerLabel="Total"
              centerValue={money(totalSpent, 0)}
            />
          </div>
        </div>

        <aside className="space-y-4">
          <ConnectCreditsWidget signedIn isClient />
          <div className="rounded-2xl bg-navy p-5 text-white shadow-sm">
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/10 text-amber-300">
                <Sparkles className="h-5 w-5" />
              </span>
              <div>
                <p className="font-display font-bold">Hire faster with Pro Plus</p>
                <ul className="mt-3 space-y-2 text-xs text-white/70">
                  {[
                    "Unlimited Connect credits",
                    "Priority talent matching",
                    "Team seats & reports",
                  ].map((t) => (
                    <li key={t} className="flex items-center gap-2">
                      <Check className="h-3.5 w-3.5 text-success" />
                      {t}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
            <Link
              href="/edition"
              className="mt-4 inline-flex w-full items-center justify-center rounded-xl bg-white px-4 py-2.5 text-sm font-bold text-navy hover:bg-white/90"
            >
              {plus ? "Manage plan" : "Upgrade now"}
            </Link>
          </div>
        </aside>
      </div>
    </div>
  );
}
