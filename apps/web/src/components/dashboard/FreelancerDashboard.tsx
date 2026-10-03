import Link from "next/link";
import {
  Award,
  Briefcase,
  FileText,
  MessageSquare,
  Sparkles,
  TrendingUp,
  Bot,
  MapPin,
  Zap,
  Clock3,
  Users,
} from "lucide-react";
import { EarningsLineChart, type EarningsPoint } from "@/components/dashboard/EarningsLineChart";
import { ProfileCompleteness } from "@/components/dashboard/ProfileCompleteness";
import { ProjectListCard, type DashboardProject } from "@/components/dashboard/ProjectListCard";
import { PeopleListCard, type PersonRow } from "@/components/dashboard/PeopleListCard";
import { WeekOverview } from "@/components/dashboard/WeekOverview";
import { DonutChart } from "@/components/dashboard/DonutChart";
import { portalGreeting } from "@/lib/portal-nav";
import type { ConnectCreditSummary } from "@/lib/connect-credits";
import { formatConnectCredits } from "@/lib/connect-credits";
import type { Profile } from "@/lib/profile-types";
import { isProPlus } from "@/lib/plan";
import { cn } from "@/lib/utils";

type HomeSummary = {
  pending_proposals?: number;
  active_milestones?: number;
  unread_messages?: number;
  accepted_proposals?: number;
};

type Opportunity = {
  id: string;
  title: string;
  budget: string;
  type: string;
};

type Props = {
  profile: Profile;
  home: HomeSummary;
  projectCount: number;
  invoiceTotal: number;
  invoiceSeries?: EarningsPoint[];
  credits: ConnectCreditSummary | null;
  profileCompleteness: number;
  successScore: number;
  activities: Array<{ id: string; title: string; detail: string; time: string; kind: string }>;
  projects: DashboardProject[];
  clients: PersonRow[];
  proposalSlices: Array<{ name: string; value: number; color: string }>;
  opportunities: Opportunity[];
  week: { timeTracked: string; earned: string; tasksDone: number; productivity: number };
};

function KpiCard({
  label,
  value,
  sub,
  trend,
  icon: Icon,
  href,
  iconTone,
}: {
  label: string;
  value: string | number;
  sub?: string;
  trend?: string;
  icon: React.ComponentType<{ className?: string }>;
  href: string;
  iconTone: string;
}) {
  return (
    <Link
      href={href}
      className="group rounded-2xl border border-border bg-surface p-4 shadow-sm transition hover:border-primary/40"
    >
      <div className="flex items-start justify-between gap-2">
        <span className={cn("flex h-10 w-10 items-center justify-center rounded-xl", iconTone)}>
          <Icon className="h-5 w-5" />
        </span>
        {trend && (
          <span className="inline-flex items-center gap-0.5 rounded-lg bg-success/10 px-2 py-0.5 text-[10px] font-bold text-success">
            <TrendingUp className="h-3 w-3" />
            {trend}
          </span>
        )}
      </div>
      <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-text-muted">{label}</p>
      <p className="mt-1 font-display text-2xl font-extrabold text-navy">{value}</p>
      {sub && <p className="mt-1 text-xs text-text-secondary">{sub}</p>}
      <div className="mt-3 h-1 overflow-hidden rounded-full bg-slate-100">
        <div className="h-full w-2/3 rounded-full bg-primary/40 transition group-hover:bg-primary/70" />
      </div>
    </Link>
  );
}

function WorkQueueCard({
  pending,
  accepted,
  unread,
  milestones,
  profileCompleteness,
}: {
  pending: number;
  accepted: number;
  unread: number;
  milestones: number;
  profileCompleteness?: number;
}) {
  const needsReply = unread > 0;
  const metrics = [
    { label: "Active Proposals", value: pending, href: "/app/proposals" },
    { label: "Accepted & Won", value: accepted, href: "/app/proposals" },
    { label: "Unread Messages", value: unread, href: "/app/messages" },
    { label: "Milestones Active", value: milestones, href: "/app/projects" },
  ];

  return (
    <div className="overflow-hidden rounded-2xl bg-navy p-5 text-white shadow-sm sm:p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="inline-flex items-center gap-2 text-sm font-bold text-primary-light">
            <Zap className="h-4 w-4" />
            Needs Your Attention & Work Queue
          </p>
          <p className="mt-2 text-sm text-white/70">
            {needsReply
              ? `${unread} client message${unread === 1 ? "" : "s"} need${unread === 1 ? "s" : ""} a response.`
              : accepted > 0
                ? `${accepted} proposal${accepted === 1 ? "" : "s"} accepted by clients. Review deliverables & start.`
                : pending > 0
                  ? `${pending} proposal${pending === 1 ? "" : "s"} awaiting review.`
                  : "You're caught up - keep building pipeline on Connect."}
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {needsReply && (
            <Link
              href="/app/messages"
              className="inline-flex min-h-10 items-center justify-center rounded-xl bg-amber-400 px-4 py-2 text-sm font-bold text-navy hover:bg-amber-300 transition"
            >
              Reply ({unread})
            </Link>
          )}
          <Link
            href="/app/connect"
            className="inline-flex min-h-10 items-center justify-center rounded-xl bg-white px-4 py-2 text-sm font-bold text-navy hover:bg-primary/10 transition"
          >
            Find jobs
          </Link>
        </div>
      </div>

      {/* High-priority attention alert banners */}
      {accepted > 0 && (
        <div className="mt-4 flex items-center justify-between gap-3 rounded-xl bg-emerald-500/20 border border-emerald-400/30 px-3.5 py-2.5 text-xs text-emerald-200">
          <div className="flex items-center gap-2">
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-emerald-400 text-navy font-bold text-[10px]">✓</span>
            <span><strong>{accepted} Proposal{accepted === 1 ? "" : "s"} Accepted!</strong> Client accepted your pitch.</span>
          </div>
          <Link href="/app/proposals" className="font-bold text-white hover:underline shrink-0">
            View & Kickoff →
          </Link>
        </div>
      )}

      {needsReply && (
        <div className="mt-3 flex items-center justify-between gap-3 rounded-xl bg-amber-500/20 border border-amber-400/30 px-3.5 py-2.5 text-xs text-amber-200">
          <div className="flex items-center gap-2">
            <MessageSquare className="h-4 w-4 text-amber-300" />
            <span><strong>{unread} Unread Message{unread === 1 ? "" : "s"}</strong> awaiting your reply.</span>
          </div>
          <Link href="/app/messages" className="font-bold text-white hover:underline shrink-0">
            Open Inbox →
          </Link>
        </div>
      )}

      {profileCompleteness != null && profileCompleteness < 80 && (
        <div className="mt-3 flex items-center justify-between gap-3 rounded-xl bg-cyan-500/20 border border-cyan-400/30 px-3.5 py-2.5 text-xs text-cyan-200">
          <div className="flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-cyan-300" />
            <span>Your profile is {profileCompleteness}% complete. Add your portfolio projects to boost search ranking.</span>
          </div>
          <Link href="/app/connect/manage" className="font-bold text-white hover:underline shrink-0">
            Complete Profile →
          </Link>
        </div>
      )}

      <div className="mt-5 grid grid-cols-2 gap-2 sm:grid-cols-4">
        {metrics.map((m) => (
          <Link
            key={m.label}
            href={m.href}
            className="rounded-xl bg-white/10 px-3 py-3 transition hover:bg-white/15"
          >
            <p className="font-display text-xl font-extrabold">{m.value}</p>
            <p className="mt-0.5 text-[11px] font-semibold text-white/65">{m.label}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}

export function FreelancerDashboard({
  profile,
  home,
  projectCount,
  invoiceTotal,
  invoiceSeries,
  credits,
  profileCompleteness,
  successScore,
  activities: _activities,
  projects,
  clients,
  proposalSlices,
  opportunities,
  week,
}: Props) {
  const plus = isProPlus(profile);
  const firstName = (profile.name || "there").split(" ")[0];
  const pending = home.pending_proposals ?? 0;
  const accepted = home.accepted_proposals ?? 0;
  const unread = home.unread_messages ?? 0;
  const milestones = home.active_milestones ?? 0;
  const inProgress = projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return s.includes("progress") || s === "active" || s === "ongoing";
  }).length;
  const proposalTotal = proposalSlices.reduce((s, x) => s + x.value, 0);

  return (
    <div className="space-y-5 pb-10">
      {/* Hero greeting + profile completeness */}
      <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">
            {portalGreeting()}, {firstName}!
          </h1>
          <p className="mt-1 text-sm text-text-secondary">Let&apos;s crush your goals today.</p>
          {credits && (
            <p className="mt-2 flex items-center gap-2 text-xs font-semibold text-text-secondary">
              <span className="inline-block h-2 w-2 rounded-full bg-success" />
              Connect · {formatConnectCredits(credits)}
            </p>
          )}
        </div>
        <div className="w-full max-w-sm shrink-0">
          <ProfileCompleteness percent={profileCompleteness} successScore={successScore} />
        </div>
      </div>

      {/* Work queue fills the former empty center */}
      <WorkQueueCard
        pending={pending}
        accepted={accepted}
        unread={unread}
        milestones={milestones}
        profileCompleteness={profileCompleteness}
      />

      {/* KPI strip */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5">
        <KpiCard
          label="Total Earnings"
          value={`$${invoiceTotal.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`}
          sub="Invoiced total"
          icon={TrendingUp}
          href="/app/earnings"
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <KpiCard
          label="Active Projects"
          value={projectCount}
          sub={`${inProgress || milestones} in progress`}
          icon={Briefcase}
          href="/app/projects"
          iconTone="bg-sky-100 text-sky-800"
        />
        <KpiCard
          label="Pending Proposals"
          value={pending}
          sub={pending > 0 ? "Awaiting review" : "Submit on Connect"}
          icon={FileText}
          href="/app/proposals"
          iconTone="bg-amber-100 text-amber-800"
        />
        <KpiCard
          label="Unread Messages"
          value={unread}
          sub="From clients"
          icon={MessageSquare}
          href="/app/messages"
          iconTone="bg-violet-100 text-violet-700"
        />
        <KpiCard
          label="Success Score"
          value={`${successScore}%`}
          sub="Top Rated"
          icon={Award}
          href="/app/reviews"
          iconTone="bg-primary/10 text-primary"
        />
      </div>

      <WeekOverview {...week} />

      {/* Earnings chart full width */}
      <div className="grid gap-4 lg:grid-cols-1">
        <EarningsLineChart
          total={invoiceTotal}
          accent="teal"
          title="Earnings overview"
          trendLabel={invoiceTotal > 0 ? "Live invoice total" : "No paid/invoiced amount yet"}
          showPreviousLegend
          series={invoiceSeries}
          summaryBoxes={[
            {
              label: "Clients",
              value: String(clients.length),
              tone: "bg-sky-50 text-sky-800",
            },
            {
              label: "Projects",
              value: String(projectCount),
              tone: "bg-primary/10 text-primary-dark",
            },
            {
              label: "Time",
              value: week.timeTracked,
              tone: "bg-violet-50 text-violet-800",
            },
          ]}
        />
      </div>

      {/* Active projects | Top clients | Proposals donut */}
      <div className="grid gap-4 lg:grid-cols-3">
        <ProjectListCard projects={projects} />
        <PeopleListCard title="Top clients" people={clients} href="/app/clients" />
        <DonutChart
          title="Proposals status"
          slices={proposalSlices}
          centerValue={proposalTotal || pending}
          centerLabel="Total"
        />
      </div>

      {/* Quick actions */}
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Link
          href="/app/connect"
          className="inline-flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-bold text-white"
        >
          <Briefcase className="h-4 w-4" />
          Find jobs
        </Link>
        <Link
          href="/app/connect/manage"
          className="inline-flex items-center justify-center gap-2 rounded-xl border border-primary/30 bg-primary/10 px-4 py-3 text-sm font-bold text-primary-dark"
        >
          <Sparkles className="h-4 w-4" />
          Post a need
        </Link>
        <Link
          href="/app/timesheets"
          className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-surface px-4 py-3 text-sm font-semibold text-navy"
        >
          <Clock3 className="h-4 w-4" />
          Track time
        </Link>
        <Link
          href="/app/clients"
          className="inline-flex items-center justify-center gap-2 rounded-xl border border-border bg-surface px-4 py-3 text-sm font-semibold text-navy"
        >
          <Users className="h-4 w-4" />
          Clients
        </Link>
      </div>


      {/* Recommended opportunities */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-display text-lg font-bold text-navy">Recommended opportunities</h2>
          <Link href="/app/connect" className="text-xs font-semibold text-primary hover:underline">
            Browse Connect →
          </Link>
        </div>
        {opportunities.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center text-sm text-text-secondary">
            Open Connect to discover jobs matching your skills.
          </div>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {opportunities.map((o) => (
              <Link
                key={o.id}
                href="/app/connect"
                className="rounded-2xl border border-border bg-surface p-4 shadow-sm transition hover:border-primary/40 hover:shadow-md"
              >
                <div className="flex items-start gap-3">
                  <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-navy text-sm font-bold text-white">
                    {(o.title || "?").charAt(0).toUpperCase()}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold text-navy">{o.title}</p>
                    <p className="mt-1 text-sm font-bold text-primary">{o.budget}</p>
                    <p className="mt-2 flex items-center gap-1 text-xs text-text-muted">
                      <MapPin className="h-3 w-3" />
                      {o.type || "Remote"}
                    </p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>

      {!plus && (
        <div className="flex flex-col gap-4 rounded-2xl border border-primary/25 bg-gradient-to-r from-primary/5 to-white p-5 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-start gap-3">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary text-white">
              <Sparkles className="h-5 w-5" />
            </span>
            <div>
              <p className="font-display font-bold text-navy">Unlock more with Pro Plus</p>
              <p className="mt-1 text-sm text-text-secondary">
                Get featured, more Connect credits, advanced analytics and more.
              </p>
            </div>
          </div>
          <Link
            href="/edition"
            className="inline-flex min-h-11 shrink-0 items-center justify-center rounded-xl bg-primary px-5 py-2.5 text-sm font-bold text-white"
          >
            Upgrade now
          </Link>
        </div>
      )}
    </div>
  );
}
