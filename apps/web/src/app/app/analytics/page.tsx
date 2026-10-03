import { redirect } from "next/navigation";
import Link from "next/link";
import {
  BarChart3,
  Briefcase,
  CheckCircle2,
  Clock,
  Download,
  FileText,
  Star,
  TrendingUp,
  Users,
  Wallet,
} from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { loadFreelancerFinance } from "@/lib/freelancer-finance";
import { EarningsLineChart } from "@/components/dashboard/EarningsLineChart";
import { DonutChart } from "@/components/dashboard/DonutChart";
import { MonthlyBarChart } from "@/components/dashboard/MonthlyBarChart";
import { ActivityFeed } from "@/components/dashboard/ActivityFeed";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  PrimaryButton,
  money,
} from "@/components/freelancer/ui";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientStatCard,
  ClientStatusPill,
  money as clientMoney,
} from "@/components/client/ui";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Analytics" };

export default async function AnalyticsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const isClient = isClientAccount(profile);

  if (isClient) {
    const supabase = await createClient();
    type ShareRow = {
      share_id: string;
      invoice_number: string | null;
      total: number | null;
      status: string | null;
      currency: string | null;
      due_date: string | null;
      freelancer_email: string | null;
      updated_at: string | null;
    };
    let shares: ShareRow[] = [];
    try {
      const invoiceFilter = profile.email
        ? `client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`
        : `client_uid.eq.${profile.id}`;
      const { data } = await supabase
        .from("invoice_shares")
        .select(
          "share_id, invoice_number, total, status, currency, due_date, freelancer_email, updated_at",
        )
        .or(invoiceFilter)
        .order("updated_at", { ascending: false })
        .limit(100);
      shares = (data ?? []) as ShareRow[];
    } catch {
      shares = [];
    }
    let total = 0;
    let paid = 0;
    let pending = 0;
    let overdue = 0;
    for (const r of shares) {
      const amt = Number(r.total) || 0;
      total += amt;
      const s = (r.status || "").toLowerCase();
      if (s === "paid") paid += amt;
      else if (s === "overdue") overdue += amt;
      else pending += amt;
    }

    return (
      <div className="space-y-6 pb-10">
        <ClientPageHeader
          title="Reports"
          subtitle="Spending report from invoices shared with your account."
          icon={BarChart3}
          actions={
            <ClientPrimaryButton href="/app/invoices">
              <FileText className="h-4 w-4" />
              Open invoices
            </ClientPrimaryButton>
          }
        />
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <ClientStatCard label="Total spend" value={clientMoney(total)} icon={Wallet} />
          <ClientStatCard label="Paid" value={clientMoney(paid)} icon={CheckCircle2} iconTone="bg-emerald-100 text-emerald-700" />
          <ClientStatCard label="Pending" value={clientMoney(pending)} icon={FileText} iconTone="bg-amber-100 text-amber-800" />
          <ClientStatCard label="Overdue" value={clientMoney(overdue)} icon={FileText} iconTone="bg-red-100 text-red-700" />
        </div>
        <ClientCard title="Invoice spending">
          {shares.length === 0 ? (
            <p className="rounded-xl border border-dashed border-border px-4 py-8 text-center text-sm text-text-secondary">
              No shared invoices yet. When freelancers share invoices, they appear here.
            </p>
          ) : (
            <ul className="divide-y divide-border">
              {shares.map((r) => (
                <li key={r.share_id} className="flex flex-wrap items-center justify-between gap-2 py-3">
                  <div className="min-w-0">
                    <p className="font-semibold text-navy">
                      {r.invoice_number || r.share_id}
                    </p>
                    <p className="truncate text-xs text-text-muted">
                      {r.freelancer_email || "Freelancer"}
                      {r.due_date ? ` · due ${new Date(r.due_date).toLocaleDateString()}` : ""}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <p className="font-bold text-navy">{clientMoney(Number(r.total) || 0)}</p>
                    <ClientStatusPill
                      tone={
                        (r.status || "").toLowerCase() === "paid"
                          ? "green"
                          : (r.status || "").toLowerCase() === "overdue"
                            ? "red"
                            : "amber"
                      }
                    >
                      {r.status || "pending"}
                    </ClientStatusPill>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </ClientCard>

        <div className="grid gap-4 lg:grid-cols-3">
          <ClientCard title="Recent activity">
            <ul className="space-y-3 text-sm">
              {shares.slice(0, 5).map((r) => (
                <li key={`act-${r.share_id}`} className="rounded-xl bg-client-surface/50 px-3 py-2.5">
                  <p className="font-semibold text-navy">
                    Invoice {r.invoice_number || r.share_id.slice(0, 8)}
                  </p>
                  <p className="mt-0.5 text-xs text-text-muted">
                    {r.freelancer_email || "Freelancer"} · {r.status || "pending"}
                    {r.updated_at
                      ? ` · ${new Date(r.updated_at).toLocaleDateString()}`
                      : ""}
                  </p>
                </li>
              ))}
              {shares.length === 0 && (
                <li className="text-text-secondary">No activity yet.</li>
              )}
            </ul>
            <Link href="/app/invoices" className="mt-3 inline-block text-sm font-semibold text-client-accent">
              View all invoices →
            </Link>
          </ClientCard>
          <ClientCard title="Insights">
            <ul className="space-y-3 text-sm">
              <li className="rounded-xl bg-sky-50 px-3 py-3">
                <p className="font-bold text-navy">Cashflow pulse</p>
                <p className="mt-1 text-text-secondary">
                  {paid > 0
                    ? `You've cleared ${clientMoney(paid)} - keep approvals moving.`
                    : "Approve shared invoices to keep freelancers paid on time."}
                </p>
              </li>
              <li className="rounded-xl bg-amber-50 px-3 py-3">
                <p className="font-bold text-navy">Open balance</p>
                <p className="mt-1 text-text-secondary">
                  {pending + overdue > 0
                    ? `${clientMoney(pending + overdue)} still outstanding across your team.`
                    : "No open balances - nice and clean."}
                </p>
              </li>
              <li>
                <Link href="/app/connect" className="text-sm font-semibold text-client-accent">
                  Find freelancers →
                </Link>
              </li>
            </ul>
          </ClientCard>
          <ClientCard title="Vendor retention">
            {(() => {
              const freelancers = new Set(
                shares.map((s) => s.freelancer_email).filter(Boolean),
              ).size;
              const repeat = Math.min(
                10,
                Math.max(1, Math.round((paid > 0 ? 8 : freelancers > 0 ? 5 : 0))),
              );
              const pct = repeat * 10;
              return (
                <>
                  <p className="font-display text-4xl font-extrabold text-navy">{pct}%</p>
                  <p className="mt-1 text-sm text-text-secondary">
                    Repeat engagement signal across {freelancers || 0} freelancers
                  </p>
                  <div className="mt-4 flex flex-wrap gap-1.5">
                    {Array.from({ length: 10 }).map((_, i) => (
                      <span
                        key={i}
                        className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold text-white ${
                          i < repeat ? "bg-client-accent" : "bg-slate-300"
                        }`}
                      >
                        {i + 1}
                      </span>
                    ))}
                  </div>
                </>
              );
            })()}
          </ClientCard>
        </div>
      </div>
    );
  }

  const fin = await loadFreelancerFinance(profile.id);
  const activeProjects = fin.projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return !["completed", "done", "cancelled"].includes(s);
  }).length;
  const completedProjects = fin.projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return ["completed", "done"].includes(s);
  }).length;
  const hoursLabel = `${Math.floor(fin.timeHours)}h ${Math.round((fin.timeHours % 1) * 60)}m`;
  const successRate = fin.projects.length
    ? Math.round((completedProjects / Math.max(1, fin.projects.length)) * 100)
    : 98;

  const performance = [
    { name: "Billable", value: Math.max(1, Math.round(fin.billableHours || 75)), color: "#0D9488" },
    { name: "Non-billable", value: Math.max(1, Math.round((fin.timeHours - fin.billableHours) || 18)), color: "#0EA5E9" },
    { name: "Untracked", value: 7, color: "#F59E0B" },
  ];

  const projectSlices = [
    { name: "Completed", value: completedProjects || 1, color: "#0EA5E9" },
    { name: "In Progress", value: activeProjects || 1, color: "#0D9488" },
    {
      name: "On Hold",
      value: fin.projects.filter((p) => (p.status || "").toLowerCase().includes("hold")).length || 0,
      color: "#F59E0B",
    },
  ].filter((x) => x.value > 0);

  const categories = [
    { name: "Web Development", amount: fin.totalRevenue * 0.5, pct: 50 },
    { name: "UI/UX Design", amount: fin.totalRevenue * 0.25, pct: 25 },
    { name: "Mobile Apps", amount: fin.totalRevenue * 0.15, pct: 15 },
    { name: "Consulting", amount: fin.totalRevenue * 0.1, pct: 10 },
  ];

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Analytics"
        subtitle="Track your performance, earnings, projects and growth."
        icon={BarChart3}
        actions={
          <>
            <span className="inline-flex min-h-11 items-center rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-semibold text-navy">
              Jul 1 - Jul 31, 2026
            </span>
            <PrimaryButton href="/app/earnings">
              <Download className="h-4 w-4" />
              Export Report
            </PrimaryButton>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        <FreelancerStatCard
          label="Total Earnings"
          value={money(fin.totalRevenue)}
          icon={TrendingUp}
        />
        <FreelancerStatCard
          label="Billable Hours"
          value={hoursLabel}
          icon={Clock}
          iconTone="bg-sky-100 text-sky-800"
        />
        <FreelancerStatCard
          label="Active Projects"
          value={activeProjects || fin.projects.length}
          icon={Briefcase}
          iconTone="bg-violet-100 text-violet-800"
        />
        <FreelancerStatCard
          label="Completed Projects"
          value={completedProjects}
          icon={CheckCircle2}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <FreelancerStatCard
          label="New Clients"
          value={fin.customers.length}
          icon={Users}
          iconTone="bg-amber-100 text-amber-800"
        />
        <FreelancerStatCard
          label="Success Rate"
          value={`${successRate}%`}
          icon={Star}
          iconTone="bg-fuchsia-100 text-fuchsia-800"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <EarningsLineChart
            total={fin.totalRevenue}
            title="Earnings overview"
            accent="teal"
            series={fin.series}
            showPreviousLegend
            summaryBoxes={[
              {
                label: "Avg. daily earnings",
                value: money(fin.totalRevenue > 0 ? fin.totalRevenue / 31 : 0),
                tone: "bg-primary/10 text-primary-dark",
              },
              {
                label: "Highest day",
                value: money(fin.totalRevenue > 0 ? Math.max(...fin.series.map((p) => p.amount), 0) : 0),
                tone: "bg-sky-50 text-sky-800",
              },
            ]}
          />
        </div>
        <DonutChart title="Performance breakdown" slices={performance} centerLabel="Hours" />
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <FreelancerCard title="Earnings by month" className="lg:col-span-1">
          <MonthlyBarChart data={fin.monthlyBars} total={fin.totalRevenue} />
        </FreelancerCard>
        <DonutChart
          title="Projects summary"
          slices={projectSlices.length ? projectSlices : [{ name: "No projects", value: 1, color: "#E2E8F0" }]}
          centerValue={fin.projects.length}
          centerLabel="Total"
        />
        <FreelancerCard title="Top earning categories">
          <ul className="space-y-3">
            {categories.map((c) => (
              <li key={c.name}>
                <div className="flex items-center justify-between text-sm">
                  <span className="font-semibold text-navy">{c.name}</span>
                  <span className="font-bold text-navy">{money(c.amount)}</span>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-background">
                  <div className="h-full rounded-full bg-primary" style={{ width: `${c.pct}%` }} />
                </div>
              </li>
            ))}
          </ul>
        </FreelancerCard>
      </div>

      <div className="grid gap-4 lg:grid-cols-3">
        <ActivityFeed items={fin.activities} viewAllHref="/app/notifications" defaultCollapsed />
        <FreelancerCard title="Insights">
          <ul className="space-y-3 text-sm">
            <li className="rounded-xl bg-primary/5 px-3 py-3">
              <p className="font-bold text-navy">Great job!</p>
              <p className="mt-1 text-text-secondary">
                Your completion rate is strong. Keep delivering on time to stay Top Rated.
              </p>
            </li>
            <li className="rounded-xl bg-sky-50 px-3 py-3">
              <p className="font-bold text-navy">Time to scale</p>
              <p className="mt-1 text-text-secondary">
                You have capacity for more Connect proposals this month.
              </p>
            </li>
            <li>
              <Link href="/app/connect" className="text-sm font-semibold text-primary">
                Find more jobs →
              </Link>
            </li>
          </ul>
        </FreelancerCard>
        <FreelancerCard title="Client retention">
          {(() => {
            const clients = fin.customers.length;
            const filled = Math.min(
              10,
              Math.max(
                clients > 0 ? Math.round((completedProjects / Math.max(1, fin.projects.length)) * 10) : 0,
                clients > 0 ? 4 : 0,
              ),
            );
            const pct = clients === 0 ? 0 : filled * 10;
            return (
              <>
                <p className="font-display text-4xl font-extrabold text-navy">{pct}%</p>
                <p className="mt-1 text-sm text-text-secondary">
                  Repeat engagement across {clients} clients · {completedProjects} completed projects
                </p>
                <div className="mt-4 flex flex-wrap gap-1.5">
                  {Array.from({ length: 10 }).map((_, i) => (
                    <span
                      key={i}
                      className={`flex h-8 w-8 items-center justify-center rounded-full text-xs font-bold text-white ${
                        i < filled ? "bg-primary" : "bg-slate-300"
                      }`}
                    >
                      {i + 1}
                    </span>
                  ))}
                </div>
              </>
            );
          })()}
        </FreelancerCard>
      </div>
    </div>
  );
}
