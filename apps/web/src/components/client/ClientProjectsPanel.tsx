"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import {
  FolderKanban,
  Plus,
  Search,
  MoreHorizontal,
  Headphones,
  Pause,
  CheckCircle2,
  MessageSquare,
  FileText,
  ShoppingCart,
  Smartphone,
} from "lucide-react";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientOutlineButton,
  ClientStatCard,
  ClientStatusPill,
  money,
} from "@/components/client/ui";
import { DonutChart } from "@/components/dashboard/DonutChart";
import { cn } from "@/lib/utils";

export type ClientProjectRow = {
  share_id: string;
  project_name?: string | null;
  freelancer_email?: string | null;
  freelancer_name?: string | null;
  client_company?: string | null;
  status?: string | null;
  budget?: number | null;
  currency?: string | null;
  billing_type?: string | null;
  due_date?: string | null;
  updated_at?: string | null;
};

const TABS = [
  { key: "all", label: "All Projects" },
  { key: "in_progress", label: "In Progress" },
  { key: "completed", label: "Completed" },
  { key: "on_hold", label: "On Hold" },
  { key: "cancelled", label: "Cancelled" },
] as const;

function normalize(status?: string | null) {
  const s = (status || "active").toLowerCase().replace(/\s+/g, "_");
  if (s === "ongoing" || s === "active") return "in_progress";
  if (s === "done" || s === "complete") return "completed";
  if (s === "paused" || s === "hold") return "on_hold";
  if (s === "canceled") return "cancelled";
  return s;
}

const PROGRESS: Record<string, number> = {
  in_progress: 60,
  completed: 100,
  on_hold: 30,
  cancelled: 0,
  not_started: 10,
};

function formatDate(value?: string | null) {
  if (!value) return "-";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "-";
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

const ICONS = [ShoppingCart, Smartphone, FolderKanban, FileText];

export function ClientProjectsPanel({ rows }: { rows: ClientProjectRow[] }) {
  const [tab, setTab] = useState<(typeof TABS)[number]["key"]>("all");
  const [query, setQuery] = useState("");

  const counts = useMemo(() => {
    const c = {
      all: rows.length,
      in_progress: 0,
      completed: 0,
      on_hold: 0,
      cancelled: 0,
    };
    for (const r of rows) {
      const n = normalize(r.status);
      if (n in c) c[n as keyof typeof c] += 1;
    }
    return c;
  }, [rows]);

  const totalBudget = rows.reduce((s, r) => s + (Number(r.budget) || 0), 0);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return rows.filter((r) => {
      if (tab !== "all" && normalize(r.status) !== tab) return false;
      if (!q) return true;
      const hay = [r.project_name, r.freelancer_email, r.freelancer_name, r.client_company]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return hay.includes(q);
    });
  }, [rows, tab, query]);

  const slices = [
    { name: "In Progress", value: counts.in_progress || 1, color: "#0EA5E9" },
    { name: "Completed", value: counts.completed || 0, color: "#10B981" },
    { name: "On Hold", value: counts.on_hold || 0, color: "#F59E0B" },
    { name: "Cancelled", value: counts.cancelled || 0, color: "#DC2626" },
  ].filter((x) => x.value > 0);

  const activity = [
    { title: "Milestone completed", icon: CheckCircle2, tone: "bg-emerald-50 text-emerald-700", time: "2h ago" },
    { title: "New message", icon: MessageSquare, tone: "bg-sky-50 text-sky-700", time: "5h ago" },
    { title: "Invoice paid", icon: FileText, tone: "bg-emerald-50 text-emerald-700", time: "1d ago" },
    { title: "Project on hold", icon: Pause, tone: "bg-amber-50 text-amber-800", time: "2d ago" },
  ];

  return (
    <div className="space-y-6 pb-10">
      <ClientPageHeader
        title="Work / Projects"
        subtitle="Manage all projects shared with you. Track progress, manage budgets, and collaborate with your team."
        icon={FolderKanban}
        actions={
          <>
            <ClientPrimaryButton href="/app/connect/manage">
              <Plus className="h-4 w-4" />
              New project
            </ClientPrimaryButton>
            <ClientOutlineButton href="/app/connect">$ Find freelancers</ClientOutlineButton>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <ClientStatCard
          label="Total projects"
          value={counts.all}
          trend={counts.all > 0 ? "+20%" : undefined}
          icon={FolderKanban}
          iconTone="bg-violet-100 text-violet-700"
        />
        <ClientStatCard
          label="In progress"
          value={counts.in_progress}
          trend="+15%"
          icon={FolderKanban}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <ClientStatCard
          label="Completed"
          value={counts.completed}
          trend="+25%"
          icon={CheckCircle2}
          iconTone="bg-sky-100 text-sky-800"
        />
        <ClientStatCard
          label="On hold"
          value={counts.on_hold}
          trend={counts.on_hold > 0 ? "-10%" : "No change"}
          trendDown={counts.on_hold > 0}
          icon={Pause}
          iconTone="bg-amber-100 text-amber-800"
        />
        <ClientStatCard
          label="Cancelled"
          value={counts.cancelled}
          trend="No change"
          icon={FolderKanban}
          iconTone="bg-red-100 text-red-700"
        />
        <ClientStatCard
          label="Total budget"
          value={money(totalBudget, 0)}
          trend={totalBudget > 0 ? "+18%" : undefined}
          icon={FileText}
          iconTone="bg-client-surface text-client-accent"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_280px]">
        <div className="space-y-4">
          <div className="flex gap-1 overflow-x-auto border-b border-border">
            {TABS.map((t) => (
              <button
                key={t.key}
                type="button"
                onClick={() => setTab(t.key)}
                className={cn(
                  "shrink-0 border-b-2 px-3 py-2.5 text-sm font-semibold",
                  tab === t.key
                    ? "border-client-accent text-navy"
                    : "border-transparent text-text-muted",
                )}
              >
                {t.label} ({counts[t.key as keyof typeof counts] ?? 0})
              </button>
            ))}
          </div>

          <div className="flex flex-col gap-3 sm:flex-row">
            <div className="relative min-w-0 flex-1">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
              <input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search projects by name or freelancer..."
                className="w-full rounded-xl border border-border bg-surface py-2.5 pl-10 pr-3 text-sm"
              />
            </div>
            <select className="rounded-xl border border-border bg-surface px-3 py-2 text-sm font-semibold text-text-secondary">
              <option>All clients</option>
            </select>
            <select className="rounded-xl border border-border bg-surface px-3 py-2 text-sm font-semibold text-text-secondary">
              <option>All status</option>
            </select>
          </div>

          {filtered.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
              <p className="font-semibold text-navy">No projects yet</p>
              <Link href="/app/connect" className="mt-3 inline-block text-sm font-semibold text-client-accent">
                Find freelancers on Connect →
              </Link>
            </div>
          ) : (
            <ul className="space-y-3">
              {filtered.map((r, idx) => {
                const n = normalize(r.status);
                const pct = PROGRESS[n] ?? 40;
                const Icon = ICONS[idx % ICONS.length];
                const freelancer =
                  r.freelancer_name ||
                  (r.freelancer_email ? r.freelancer_email.split("@")[0] : "Freelancer");
                return (
                  <li
                    key={r.share_id}
                    className="flex flex-col gap-4 rounded-2xl border border-border bg-surface p-4 shadow-sm sm:flex-row sm:items-center"
                  >
                    <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-client-surface text-client-accent">
                      <Icon className="h-5 w-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="font-semibold text-navy">{r.project_name || "Project"}</p>
                        <ClientStatusPill
                          tone={
                            n === "completed"
                              ? "green"
                              : n === "on_hold"
                                ? "amber"
                                : n === "cancelled"
                                  ? "red"
                                  : "blue"
                          }
                        >
                          {n === "in_progress" ? "In Progress" : n.replace("_", " ")}
                        </ClientStatusPill>
                        <span className="rounded-lg bg-slate-100 px-2 py-0.5 text-[10px] font-bold uppercase text-slate-600">
                          {r.billing_type || "Fixed Price"}
                        </span>
                      </div>
                      <p className="mt-1 text-xs text-text-secondary">
                        by {r.client_company || "Your company"} · {freelancer}
                      </p>
                      <div className="mt-3 flex items-center gap-3">
                        <div className="h-1.5 max-w-xs flex-1 overflow-hidden rounded-full bg-slate-100">
                          <div
                            className="h-full rounded-full bg-sky-500"
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                        <span className="text-xs font-semibold text-text-muted">{pct}%</span>
                      </div>
                    </div>
                    <div className="flex shrink-0 items-center gap-4 sm:flex-col sm:items-end">
                      <div className="text-right">
                        <p className="font-bold text-navy">
                          {r.budget != null ? money(Number(r.budget), 0) : "-"}
                        </p>
                        <p className="text-xs text-text-muted">
                          Due {formatDate(r.due_date || r.updated_at)}
                        </p>
                      </div>
                      <button
                        type="button"
                        className="rounded-lg p-2 text-text-muted hover:bg-client-surface"
                        aria-label="More"
                      >
                        <MoreHorizontal className="h-4 w-4" />
                      </button>
                    </div>
                  </li>
                );
              })}
            </ul>
          )}
        </div>

        <aside className="space-y-4">
          <DonutChart
            title="Project overview"
            slices={slices}
            centerValue={counts.all}
            centerLabel="Projects"
          />
          <Link
            href="/app/activity"
            className="-mt-2 block text-center text-sm font-semibold text-client-accent hover:underline"
          >
            View full report →
          </Link>

          <ClientCard title="Recent activity">
            <ul className="space-y-3">
              {activity.map((a) => {
                const Icon = a.icon;
                return (
                  <li key={a.title} className="flex gap-3">
                    <span className={cn("flex h-8 w-8 items-center justify-center rounded-full", a.tone)}>
                      <Icon className="h-3.5 w-3.5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-semibold text-navy">{a.title}</p>
                    </div>
                    <span className="text-[10px] text-text-muted">{a.time}</span>
                  </li>
                );
              })}
            </ul>
          </ClientCard>

          <ClientCard>
            <div className="flex items-start gap-3">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-client-surface text-client-accent">
                <Headphones className="h-5 w-5" />
              </span>
              <div>
                <p className="font-semibold text-navy">Need help managing projects?</p>
                <p className="mt-1 text-xs text-text-secondary">
                  Get expert support from our team.
                </p>
                <Link
                  href="/app/support"
                  className="mt-3 inline-flex rounded-xl bg-client-accent px-3 py-2 text-xs font-bold text-white"
                >
                  Visit Help Center
                </Link>
              </div>
            </div>
          </ClientCard>
        </aside>
      </div>
    </div>
  );
}
