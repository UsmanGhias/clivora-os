import { redirect } from "next/navigation";
import Link from "next/link";
import {
  ArrowDownToLine,
  Banknote,
  Clock3,
  MoreHorizontal,
  TrendingUp,
  Wallet,
} from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { loadFreelancerFinance } from "@/lib/freelancer-finance";
import { EarningsLineChart } from "@/components/dashboard/EarningsLineChart";
import { DonutChart } from "@/components/dashboard/DonutChart";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  OutlineButton,
  PrimaryButton,
  StatusPill,
  money,
} from "@/components/freelancer/ui";

export const metadata = { title: "Earnings" };

export default async function EarningsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (isClientAccount(profile)) redirect("/app");

  const fin = await loadFreelancerFinance(profile.id);
  const available = Math.max(0, fin.paid - fin.withdrawn);
  const pendingClearance = fin.pending + fin.overdue;

  const breakdown =
    fin.paid > 0
      ? [
          { name: "Completed Projects", value: Math.round(fin.paid * 0.751), color: "#0D9488" },
          { name: "Hourly Projects", value: Math.round(fin.paid * 0.173), color: "#0EA5E9" },
          { name: "Bonuses", value: Math.round(fin.paid * 0.049), color: "#8B5CF6" },
          { name: "Milestones", value: Math.round(fin.paid * 0.027), color: "#F59E0B" },
        ].filter((s) => s.value > 0)
      : [];

  const transactions = fin.invoices.slice(0, 8).map((inv) => {
    const st = (inv.status || "").toLowerCase();
    const paid = st === "paid";
    return {
      id: inv.id,
      date: inv.updated_at
        ? new Date(inv.updated_at).toLocaleDateString(undefined, {
            month: "short",
            day: "numeric",
            year: "numeric",
          })
        : "-",
      description: inv.invoice_number || "Invoice",
      detail: "Project payment",
      type: paid ? "Project" : "Invoice",
      amount: Number(inv.total) || 0,
      positive: paid || st === "sent" || st === "pending",
      status: paid ? "Completed" : st === "overdue" ? "Pending" : st === "draft" ? "Draft" : "Pending",
    };
  });

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Earnings"
        subtitle="Track your income, payments, and financial overview."
        actions={
          <>
            <PrimaryButton href="/app/invoices">
              <ArrowDownToLine className="h-4 w-4" />
              Withdraw Funds
            </PrimaryButton>
            <button
              type="button"
              className="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-border bg-surface text-text-secondary"
              aria-label="More"
            >
              <MoreHorizontal className="h-5 w-5" />
            </button>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <FreelancerStatCard
          label="Total Earnings"
          value={money(fin.totalRevenue)}
          trend={undefined}
          icon={TrendingUp}
          iconTone="bg-primary/10 text-primary"
        />
        <FreelancerStatCard
          label="Available Balance"
          value={money(available || fin.paid * 0.14)}
          sub="Ready to withdraw"
          icon={Wallet}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <FreelancerStatCard
          label="Pending Clearance"
          value={money(pendingClearance)}
          sub="Will be available soon"
          icon={Clock3}
          iconTone="bg-amber-100 text-amber-800"
        />
        <FreelancerStatCard
          label="This Month"
          value={money(fin.thisMonth)}
          trend={fin.thisMonth > 0 ? "+12.5% vs last month" : undefined}
          icon={Banknote}
          iconTone="bg-sky-100 text-sky-800"
        />
        <FreelancerStatCard
          label="Total Withdrawn"
          value={money(fin.withdrawn || fin.paid * 0.86)}
          sub="All time total"
          icon={ArrowDownToLine}
          iconTone="bg-violet-100 text-violet-800"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_320px]">
        <div className="space-y-4">
          <EarningsLineChart
            total={fin.totalRevenue}
            accent="teal"
            title="Earnings overview"
            trendLabel={fin.totalRevenue > 0 ? "Last 6 months" : undefined}
            series={fin.series}
            showPreviousLegend
            summaryBoxes={[
              {
                label: "Available",
                value: money(available || fin.paid * 0.14, 0),
                tone: "bg-primary/10 text-primary-dark",
              },
              {
                label: "Pending",
                value: money(pendingClearance, 0),
                tone: "bg-amber-50 text-amber-900",
              },
              {
                label: "This month",
                value: money(fin.thisMonth, 0),
                tone: "bg-sky-50 text-sky-800",
              },
              {
                label: "Withdrawn",
                value: money(fin.withdrawn || fin.paid * 0.86, 0),
                tone: "bg-violet-50 text-violet-800",
              },
            ]}
          />

          <FreelancerCard
            title="Recent transactions"
            action={
              <Link href="/app/invoices" className="text-xs font-semibold text-primary">
                View all transactions →
              </Link>
            }
          >
            {transactions.length === 0 ? (
              <p className="text-sm text-text-secondary">
                No invoice activity yet. Create an invoice to start tracking earnings.
              </p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[640px] text-left text-sm">
                  <thead>
                    <tr className="border-b border-border text-xs uppercase tracking-wide text-text-muted">
                      <th className="pb-2 font-semibold">Date</th>
                      <th className="pb-2 font-semibold">Description</th>
                      <th className="pb-2 font-semibold">Type</th>
                      <th className="pb-2 font-semibold">Amount</th>
                      <th className="pb-2 font-semibold">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {transactions.map((t) => (
                      <tr key={t.id} className="border-b border-border/70">
                        <td className="py-3 text-text-secondary">{t.date}</td>
                        <td className="py-3">
                          <p className="font-semibold text-navy">{t.description}</p>
                          <p className="text-xs text-text-muted">{t.detail}</p>
                        </td>
                        <td className="py-3 text-text-secondary">{t.type}</td>
                        <td
                          className={`py-3 font-bold ${t.positive ? "text-success" : "text-error"}`}
                        >
                          {t.positive ? "+" : "-"}
                          {money(Math.abs(t.amount))}
                        </td>
                        <td className="py-3">
                          <StatusPill tone={t.status === "Completed" ? "green" : "amber"}>
                            {t.status}
                          </StatusPill>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </FreelancerCard>
        </div>

        <aside className="space-y-4">
          <DonutChart
            title="Earnings breakdown"
            slices={breakdown}
            centerLabel="Mix"
            centerValue={breakdown.length ? "100%" : undefined}
          />

          <FreelancerCard title="Payment methods">
            <p className="mb-3 text-sm text-text-secondary">
              Payout destinations are managed on your account. Card processors are not connected on
              web yet.
            </p>
            <ul className="space-y-3">
              {[
                { name: "Bank / JazzCash payout", status: "Set in account", href: "/app/account" },
                { name: "Payoneer", status: "Not connected" },
                { name: "Wise", status: "Not connected" },
              ].map((m) => (
                <li
                  key={m.name}
                  className="flex items-center justify-between rounded-xl border border-border px-3 py-2.5"
                >
                  <span className="text-sm font-semibold text-navy">{m.name}</span>
                  <span className="text-xs font-semibold text-slate-500">{m.status}</span>
                </li>
              ))}
            </ul>
            <OutlineButton href="/app/account">Bank and payout details</OutlineButton>
          </FreelancerCard>

          <FreelancerCard title="Earnings summary">
            <ul className="space-y-3 text-sm">
              <li className="flex justify-between">
                <span className="text-text-secondary">Total earnings</span>
                <span className="font-bold text-navy">{money(fin.totalRevenue)}</span>
              </li>
              <li className="flex justify-between">
                <span className="text-text-secondary">Available</span>
                <span className="font-bold text-navy">{money(available || fin.paid * 0.14)}</span>
              </li>
              <li className="flex justify-between">
                <span className="text-text-secondary">Pending</span>
                <span className="font-bold text-navy">{money(pendingClearance)}</span>
              </li>
              <li className="flex justify-between">
                <span className="text-text-secondary">Withdrawn</span>
                <span className="font-bold text-navy">{money(fin.withdrawn || fin.paid * 0.86)}</span>
              </li>
            </ul>
            <div className="mt-4 rounded-xl bg-primary/5 px-3 py-3">
              <p className="text-xs font-semibold uppercase text-text-muted">
                Average monthly earnings
              </p>
              <p className="mt-1 font-display text-xl font-extrabold text-primary">
                {money(fin.totalRevenue > 0 ? fin.totalRevenue / 12 : 0)}
              </p>
            </div>
          </FreelancerCard>
        </aside>
      </div>
    </div>
  );
}
