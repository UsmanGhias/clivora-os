"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import {
  Calendar,
  CheckCircle2,
  Download,
  Eye,
  FileText,
  Filter,
  Search,
  Wallet,
  AlertTriangle,
  CreditCard,
  ArrowRight,
} from "lucide-react";
import {
  ClientCard,
  ClientPageHeader,
  ClientStatCard,
  ClientStatusPill,
  money,
} from "@/components/client/ui";
import { cn } from "@/lib/utils";

export type ClientInvoiceRow = {
  share_id: string;
  invoice_number?: string | null;
  total?: number | null;
  currency?: string | null;
  status?: string | null;
  freelancer_email?: string | null;
  freelancer_name?: string | null;
  project_name?: string | null;
  project_category?: string | null;
  public_token?: string | null;
  issue_date?: string | null;
  due_date?: string | null;
  updated_at?: string | null;
};

const TABS = [
  { key: "all", label: "All invoices" },
  { key: "paid", label: "Paid" },
  { key: "pending", label: "Pending" },
  { key: "overdue", label: "Overdue" },
  { key: "draft", label: "Draft" },
] as const;

function bucket(status?: string | null) {
  const s = (status || "").toLowerCase();
  if (s === "paid" || s === "completed") return "paid";
  if (s === "overdue") return "overdue";
  if (s === "draft") return "draft";
  return "pending";
}

function formatDate(value?: string | null) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

function daysOverdue(due?: string | null) {
  if (!due) return 0;
  const d = new Date(due);
  if (Number.isNaN(d.getTime())) return 0;
  const diff = Math.floor((Date.now() - d.getTime()) / 86400000);
  return diff > 0 ? diff : 0;
}

export function ClientInvoicesPanel({ rows }: { rows: ClientInvoiceRow[] }) {
  const [tab, setTab] = useState<(typeof TABS)[number]["key"]>("all");
  const [query, setQuery] = useState("");

  const counts = useMemo(() => {
    const c = { all: rows.length, paid: 0, pending: 0, overdue: 0, draft: 0 };
    for (const r of rows) c[bucket(r.status) as keyof typeof c] += 1;
    return c;
  }, [rows]);

  const totals = useMemo(() => {
    let paid = 0;
    let pending = 0;
    let overdue = 0;
    let all = 0;
    for (const r of rows) {
      const amt = Number(r.total) || 0;
      all += amt;
      const b = bucket(r.status);
      if (b === "paid") paid += amt;
      else if (b === "overdue") overdue += amt;
      else if (b === "pending") pending += amt;
    }
    return { paid, pending, overdue, all };
  }, [rows]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return rows.filter((r) => {
      if (tab !== "all" && bucket(r.status) !== tab) return false;
      if (!q) return true;
      const hay = [
        r.invoice_number,
        r.freelancer_email,
        r.freelancer_name,
        r.project_name,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(q);
    });
  }, [rows, tab, query]);

  const activities = [
    { title: "Payment made", detail: "Invoice marked paid", time: "2h ago", tone: "green" as const },
    { title: "Invoice sent", detail: "New invoice shared", time: "1d ago", tone: "blue" as const },
    { title: "Payment overdue", detail: "Follow up needed", time: "2d ago", tone: "red" as const },
    { title: "Invoice viewed", detail: "Freelancer opened link", time: "3d ago", tone: "slate" as const },
  ];

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader
        title="Invoices"
        subtitle="View and manage all invoices shared by freelancers."
        icon={FileText}
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <ClientStatCard
          label="Total invoices"
          value={counts.all}
          trend={counts.all > 0 ? "↑ 22% vs last 30 days" : undefined}
          icon={FileText}
          iconTone="bg-sky-100 text-sky-800"
        />
        <ClientStatCard
          label="Paid"
          value={`${counts.paid}`}
          sub={money(totals.paid)}
          icon={CheckCircle2}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <ClientStatCard
          label="Pending"
          value={`${counts.pending}`}
          sub={money(totals.pending)}
          icon={Wallet}
          iconTone="bg-amber-100 text-amber-800"
        />
        <ClientStatCard
          label="Overdue"
          value={`${counts.overdue}`}
          sub={money(totals.overdue)}
          icon={Calendar}
          iconTone="bg-red-100 text-red-700"
        />
      </div>

      <p className="text-sm text-text-secondary">
        Total amount:{" "}
        <span className="font-bold text-navy">{money(totals.all)}</span>
        {totals.all > 0 && (
          <span className="ml-2 text-xs font-semibold text-success">↑ 18% vs last 30 days</span>
        )}
      </p>

      <div className="grid gap-4 xl:grid-cols-[1fr_280px]">
        <div className="space-y-4">
          <ClientCard>
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
              <div className="relative min-w-0 flex-1">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
                <input
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search by freelancer or project..."
                  className="w-full rounded-xl border border-border bg-background py-2.5 pl-10 pr-3 text-sm"
                />
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  className="inline-flex items-center gap-1.5 rounded-xl border border-border px-3 py-2 text-xs font-semibold text-text-secondary"
                >
                  <Filter className="h-3.5 w-3.5" />
                  Filters
                </button>
                <button
                  type="button"
                  className="rounded-xl border border-border px-3 py-2 text-xs font-semibold text-text-secondary"
                >
                  Status
                </button>
                <button
                  type="button"
                  className="rounded-xl border border-border px-3 py-2 text-xs font-semibold text-text-secondary"
                >
                  Export
                </button>
              </div>
            </div>

            <div className="mt-4 flex gap-1 overflow-x-auto border-b border-border">
              {TABS.map((t) => (
                <button
                  key={t.key}
                  type="button"
                  onClick={() => setTab(t.key)}
                  className={cn(
                    "shrink-0 border-b-2 px-3 py-2.5 text-sm font-semibold transition",
                    tab === t.key
                      ? "border-client-accent text-navy"
                      : "border-transparent text-text-muted hover:text-navy",
                  )}
                >
                  {t.label} ({counts[t.key]})
                </button>
              ))}
            </div>

            {filtered.length === 0 ? (
              <div className="mt-6 rounded-xl border border-dashed border-border bg-client-surface/50 p-8 text-center">
                <p className="font-semibold text-navy">No invoices in this view</p>
                <p className="mt-1 text-sm text-text-secondary">
                  Invoices shared by freelancers will appear here.
                </p>
              </div>
            ) : (
              <div className="mt-4 overflow-x-auto">
                <table className="min-w-full text-sm">
                  <thead>
                    <tr className="text-left text-[11px] font-bold uppercase tracking-wide text-text-muted">
                      <th className="pb-3 pr-3">Invoice</th>
                      <th className="pb-3 pr-3">Freelancer</th>
                      <th className="pb-3 pr-3">Project</th>
                      <th className="pb-3 pr-3">Issue date</th>
                      <th className="pb-3 pr-3">Due date</th>
                      <th className="pb-3 pr-3 text-right">Amount</th>
                      <th className="pb-3 pr-3">Status</th>
                      <th className="pb-3 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {filtered.map((r) => {
                      const b = bucket(r.status);
                      const publicHref = r.public_token ? `/i/${r.public_token}` : null;
                      const overdueDays = b === "overdue" ? daysOverdue(r.due_date) : 0;
                      const name =
                        r.freelancer_name ||
                        (r.freelancer_email ? r.freelancer_email.split("@")[0] : "Freelancer");
                      return (
                        <tr key={r.share_id} className="align-top">
                          <td className="py-3 pr-3">
                            <p className="font-semibold text-navy">
                              {r.invoice_number || `INV-${r.share_id.slice(0, 6)}`}
                            </p>
                            <p className="text-xs text-text-muted">{formatDate(r.issue_date || r.updated_at)}</p>
                          </td>
                          <td className="py-3 pr-3">
                            <div className="flex items-center gap-2">
                              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-navy text-xs font-bold text-white">
                                {name.charAt(0).toUpperCase()}
                              </span>
                              <span className="font-medium text-navy">{name}</span>
                            </div>
                          </td>
                          <td className="py-3 pr-3">
                            <p className="font-medium text-navy">{r.project_name || "Shared work"}</p>
                            <p className="text-xs text-text-muted">{r.project_category || "General"}</p>
                          </td>
                          <td className="py-3 pr-3 text-text-secondary">
                            {formatDate(r.issue_date || r.updated_at)}
                          </td>
                          <td className="py-3 pr-3">
                            <p className="text-text-secondary">{formatDate(r.due_date)}</p>
                            {overdueDays > 0 && (
                              <p className="text-xs font-semibold text-error">
                                {overdueDays} days overdue
                              </p>
                            )}
                          </td>
                          <td className="py-3 pr-3 text-right font-bold text-navy">
                            {money(Number(r.total) || 0)}
                          </td>
                          <td className="py-3 pr-3">
                            <ClientStatusPill
                              tone={
                                b === "paid"
                                  ? "green"
                                  : b === "overdue"
                                    ? "red"
                                    : b === "draft"
                                      ? "gray"
                                      : "amber"
                              }
                            >
                              {b}
                            </ClientStatusPill>
                          </td>
                          <td className="py-3 text-right">
                            <div className="inline-flex gap-1">
                              {publicHref ? (
                                <>
                                  <a
                                    href={publicHref}
                                    className="rounded-lg p-2 text-text-secondary hover:bg-client-surface"
                                    title="View"
                                  >
                                    <Eye className="h-4 w-4" />
                                  </a>
                                  <a
                                    href={publicHref}
                                    className="rounded-lg p-2 text-text-secondary hover:bg-client-surface"
                                    title="Download"
                                  >
                                    <Download className="h-4 w-4" />
                                  </a>
                                </>
                              ) : (
                                <span className="text-xs text-text-muted">-</span>
                              )}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}

            <p className="mt-4 text-xs text-text-muted">
              Showing 1 to {Math.min(5, filtered.length)} of {filtered.length} invoices
            </p>
          </ClientCard>
        </div>

        <aside className="space-y-4">
          <ClientCard title="Payments overview">
            <ul className="space-y-3 text-sm">
              <li className="flex items-center justify-between">
                <span className="text-text-secondary">Total paid</span>
                <span className="font-bold text-navy">
                  {money(totals.paid)}{" "}
                  <span className="text-[10px] text-success">↑</span>
                </span>
              </li>
              <li className="flex items-center justify-between">
                <span className="text-text-secondary">Total pending</span>
                <span className="font-bold text-navy">
                  {money(totals.pending)}{" "}
                  <span className="text-[10px] text-success">↑</span>
                </span>
              </li>
              <li className="flex items-center justify-between">
                <span className="text-text-secondary">Total overdue</span>
                <span className="font-bold text-navy">
                  {money(totals.overdue)}{" "}
                  <span className="text-[10px] text-error">↓</span>
                </span>
              </li>
            </ul>
            <Link
              href="/app/payments"
              className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-client-accent hover:underline"
            >
              View full report <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </ClientCard>

          <ClientCard title="Recent activity">
            <ul className="space-y-3">
              {activities.map((a) => (
                <li key={a.title} className="flex gap-3">
                  <span
                    className={cn(
                      "mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full",
                      a.tone === "green" && "bg-emerald-50 text-emerald-700",
                      a.tone === "blue" && "bg-sky-50 text-sky-700",
                      a.tone === "red" && "bg-red-50 text-red-700",
                      a.tone === "slate" && "bg-client-surface text-client-accent",
                    )}
                  >
                    {a.tone === "red" ? (
                      <AlertTriangle className="h-3.5 w-3.5" />
                    ) : (
                      <FileText className="h-3.5 w-3.5" />
                    )}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-semibold text-navy">{a.title}</p>
                    <p className="text-xs text-text-muted">{a.detail}</p>
                  </div>
                  <span className="shrink-0 text-[10px] text-text-muted">{a.time}</span>
                </li>
              ))}
            </ul>
          </ClientCard>

          <ClientCard title="Quick actions">
            <ul className="space-y-2">
              <li>
                <Link
                  href="/app/connect/manage"
                  className="flex items-center justify-between rounded-xl border border-border px-3 py-2.5 text-sm font-semibold text-navy hover:bg-client-surface"
                >
                  <span className="flex items-center gap-2">
                    <FileText className="h-4 w-4 text-client-accent" />
                    Create invoice
                  </span>
                  <ArrowRight className="h-4 w-4 text-text-muted" />
                </Link>
                <p className="mt-1 pl-3 text-[11px] text-text-muted">Bill a freelancer</p>
              </li>
              <li>
                <Link
                  href="/app/payments/payment-methods"
                  className="flex items-center justify-between rounded-xl border border-border px-3 py-2.5 text-sm font-semibold text-navy hover:bg-client-surface"
                >
                  <span className="flex items-center gap-2">
                    <CreditCard className="h-4 w-4 text-client-accent" />
                    Payment methods
                  </span>
                  <ArrowRight className="h-4 w-4 text-text-muted" />
                </Link>
                <p className="mt-1 pl-3 text-[11px] text-text-muted">Manage your payment cards</p>
              </li>
            </ul>
          </ClientCard>
        </aside>
      </div>
    </div>
  );
}
