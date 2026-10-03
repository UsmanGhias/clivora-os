import Link from "next/link";
import { getProfile, isClientAccount } from "@/lib/profile";
import { listCustomersServer, listProjectsServer } from "@/lib/crm/server";
import { canCreateProject } from "@/lib/plan-gates";
import { ProjectsCrmPanel } from "@/components/crm/CrmPanels";
import { ProjectKanban } from "@/components/crm/ProjectKanban";
import { createClient } from "@/lib/supabase/server";

const STATUS_LABELS: Record<string, string> = {
  not_started: "Backlog",
  in_progress: "In progress",
  on_hold: "On hold",
  completed: "Done",
  active: "Active",
};

const STATUS_PROGRESS: Record<string, number> = {
  not_started: 10,
  in_progress: 55,
  on_hold: 35,
  completed: 100,
  active: 55,
};

function normalizeStatus(status?: string | null) {
  const value = (status || "active").toLowerCase().replace(/\s+/g, "_");
  if (value === "ongoing") return "in_progress";
  if (value === "done" || value === "complete") return "completed";
  return value in STATUS_LABELS ? value : "active";
}

function StatusChip({ status }: { status?: string | null }) {
  const normalized = normalizeStatus(status);
  const className =
    normalized === "completed"
      ? "bg-success/10 text-success"
      : normalized === "on_hold"
        ? "bg-amber-100 text-amber-900"
        : "bg-client-surface text-client-accent";
  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-[11px] font-bold ${className}`}>
      {STATUS_LABELS[normalized] ?? status ?? "Active"}
    </span>
  );
}

function Progress({ status }: { status?: string | null }) {
  const pct = STATUS_PROGRESS[normalizeStatus(status)] ?? 35;
  return (
    <div className="flex items-center gap-2">
      <div className="h-1.5 w-24 overflow-hidden rounded-full bg-client-surface">
        <div className="h-full rounded-full bg-client-accent" style={{ width: `${pct}%` }} />
      </div>
      <span className="text-[11px] font-semibold text-text-muted">{pct}%</span>
    </div>
  );
}

export default async function ProjectsPage() {
  const profile = await getProfile();
  const client = isClientAccount(profile);
  let projects: Awaited<ReturnType<typeof listProjectsServer>> = [];
  let customers: Awaited<ReturnType<typeof listCustomersServer>> = [];

  if (!client) {
    try {
      projects = await listProjectsServer();
    } catch {
      projects = [];
    }
    try {
      customers = await listCustomersServer();
    } catch {
      customers = [];
    }
  }

  // Client view: shared projects
  if (client) {
    const supabase = await createClient();
    let rows: Array<{
      share_id: string;
      project_name?: string | null;
      freelancer_email?: string | null;
      status?: string | null;
      budget?: number | null;
      currency?: string | null;
      updated_at?: string | null;
    }> = [];
    try {
      const clientFilter = profile?.email
        ? `client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`
        : `client_uid.eq.${profile?.id ?? ""}`;
      const { data } = await supabase
        .from("project_shares")
        .select("share_id, project_name, freelancer_email, status, budget, currency, updated_at")
        .or(clientFilter)
        .order("updated_at", { ascending: false })
        .limit(50);
      if (data) rows = data;
    } catch {
      rows = [];
    }
    const { ClientProjectsPanel } = await import("@/components/client/ClientProjectsPanel");
    return <ClientProjectsPanel rows={rows} />;
  }

  const gate = canCreateProject(profile, projects.length);
  const { loadFreelancerFinance } = await import("@/lib/freelancer-finance");
  const fin = profile?.id ? await loadFreelancerFinance(profile.id) : null;
  const active = projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return !["completed", "done", "cancelled", "canceled"].includes(s);
  }).length;
  const inProgress = projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return s.includes("progress") || s === "active";
  }).length;
  const completed = projects.filter((p) => {
    const s = (p.status || "").toLowerCase();
    return s.includes("complet") || s === "done";
  }).length;
  const completionRate =
    projects.length > 0 ? Math.round((completed / projects.length) * 100) : 0;

  let tasksTotal = 0;
  let tasksInProgress = 0;
  if (profile?.id) {
    try {
      const supabase = await createClient();
      const { data: taskRows } = await supabase
        .from("client_tasks")
        .select("id, status")
        .eq("freelancer_uid", profile.id)
        .limit(200);
      const tasks = taskRows ?? [];
      tasksTotal = tasks.length;
      tasksInProgress = tasks.filter((t) => {
        const s = (t.status || "").toLowerCase();
        return s.includes("progress") || s === "open" || s === "pending" || s === "todo";
      }).length;
    } catch {
      tasksTotal = 0;
      tasksInProgress = 0;
    }
  }

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">
            My Projects{" "}
            <span className="ml-2 rounded-full bg-primary/10 px-2.5 py-1 text-xs font-bold text-primary">
              {active} Active
            </span>
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            Track pipeline status, budgets, and client delivery in one workspace.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link
            href="#projects-crm"
            className="inline-flex min-h-11 items-center rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white"
          >
            + Add Project
          </Link>
          <Link
            href="/app/analytics"
            className="inline-flex min-h-11 items-center rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-semibold text-navy"
          >
            View Analytics
          </Link>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-6">
        {[
          {
            label: "Total Earnings",
            value: `$${(fin?.totalRevenue ?? 0).toLocaleString()}`,
            sub: "From paid invoices",
          },
          {
            label: "Active Projects",
            value: String(active),
            sub: `${inProgress} in progress`,
          },
          {
            label: "Tasks in Progress",
            value: String(tasksInProgress),
            sub: tasksTotal ? `of ${tasksTotal} shared tasks` : "No shared tasks yet",
          },
          {
            label: "Hours Tracked",
            value: `${Math.floor(fin?.timeHours ?? 0)}h`,
            sub: "Logged time",
          },
          {
            label: "Completion Rate",
            value: `${completionRate}%`,
            sub: `${completed} of ${projects.length} completed`,
          },
          {
            label: "Pending Payments",
            value: `$${(fin?.pending ?? 0).toLocaleString()}`,
            sub: "Open invoices",
          },
        ].map((s) => (
          <div key={s.label} className="rounded-2xl border border-border bg-surface p-4 shadow-sm">
            <p className="text-xs font-semibold uppercase text-text-muted">{s.label}</p>
            <p className="mt-1 font-display text-xl font-extrabold text-navy">{s.value}</p>
            <p className="mt-1 text-xs text-text-secondary">{s.sub}</p>
          </div>
        ))}
      </div>

      <div id="projects-crm" className="space-y-4">
        <ProjectsCrmPanel
          initial={projects}
          customers={customers}
          canCreate={gate.ok}
          gateReason={!gate.ok ? gate.reason : undefined}
          upgradeHref={!gate.ok ? gate.upgradeHref : undefined}
        />
        {projects.length > 0 && (
          <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="font-display text-lg font-bold text-navy">Project Pipeline</h2>
              <span className="text-xs font-semibold text-text-muted">Kanban view</span>
            </div>
            <ProjectKanban initial={projects} />
          </div>
        )}
      </div>
    </div>
  );
}
