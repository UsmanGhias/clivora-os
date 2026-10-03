import Link from "next/link";
import { cn } from "@/lib/utils";

export type DashboardProject = {
  id: string;
  name: string;
  client?: string | null;
  status?: string | null;
  budget?: number | null;
};

const STATUS_STYLE: Record<string, string> = {
  in_progress: "bg-primary/10 text-primary-dark",
  active: "bg-primary/10 text-primary-dark",
  on_hold: "bg-amber-100 text-amber-800",
  review: "bg-violet-100 text-violet-800",
  completed: "bg-success/10 text-success",
  not_started: "bg-slate-100 text-slate-700",
};

const STATUS_LABEL: Record<string, string> = {
  in_progress: "In Progress",
  active: "In Progress",
  on_hold: "On Hold",
  review: "Review",
  completed: "Done",
  not_started: "Backlog",
};

function normalize(status?: string | null) {
  const s = (status || "active").toLowerCase().replace(/\s+/g, "_");
  if (s === "ongoing") return "in_progress";
  if (s === "done" || s === "complete") return "completed";
  return s;
}

export function ProjectListCard({
  projects,
  href = "/app/projects",
  isClient,
}: {
  projects: DashboardProject[];
  href?: string;
  isClient?: boolean;
}) {
  return (
    <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
      <div className="flex items-center justify-between gap-2">
        <h2 className="font-display text-lg font-bold text-navy">Active projects</h2>
        <Link
          href={href}
          className={cn(
            "text-xs font-semibold",
            isClient ? "text-client-accent" : "text-primary",
          )}
        >
          View all →
        </Link>
      </div>
      {projects.length === 0 ? (
        <p className="mt-4 text-sm text-text-secondary">No active projects yet.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {projects.slice(0, 5).map((p) => {
            const key = normalize(p.status);
            return (
              <li
                key={p.id}
                className="flex items-center justify-between gap-3 rounded-xl border border-border/70 px-3 py-2.5"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold text-navy">{p.name}</p>
                  {p.client && (
                    <p className="truncate text-xs text-text-secondary">{p.client}</p>
                  )}
                </div>
                <span
                  className={cn(
                    "shrink-0 rounded-full px-2.5 py-1 text-[10px] font-bold",
                    isClient && key === "in_progress"
                      ? "bg-client-surface text-client-accent"
                      : STATUS_STYLE[key] ?? STATUS_STYLE.active,
                  )}
                >
                  {STATUS_LABEL[key] ?? p.status ?? "Active"}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
