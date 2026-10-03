"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { CrmProject } from "@/lib/crm/api";
import { cn } from "@/lib/utils";

const COLUMNS = [
  { id: "not_started", label: "Backlog" },
  { id: "in_progress", label: "In progress" },
  { id: "on_hold", label: "On hold" },
  { id: "completed", label: "Done" },
] as const;

function normalizeStatus(s: string) {
  const v = (s || "not_started").toLowerCase().replace(/\s+/g, "_");
  if (v === "active" || v === "ongoing") return "in_progress";
  if (v === "done" || v === "complete") return "completed";
  if (COLUMNS.some((c) => c.id === v)) return v;
  return "not_started";
}

export function ProjectKanban({ initial }: { initial: CrmProject[] }) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dragId, setDragId] = useState<string | null>(null);

  const byCol = useMemo(() => {
    const map: Record<string, CrmProject[]> = {};
    for (const c of COLUMNS) map[c.id] = [];
    for (const p of rows) {
      const st = normalizeStatus(p.status);
      (map[st] ?? map.not_started).push(p);
    }
    return map;
  }, [rows]);

  async function moveTo(projectId: string, status: string) {
    setBusyId(projectId);
    setError(null);
    const prev = rows;
    setRows((r) => r.map((p) => (p.id === projectId ? { ...p, status } : p)));
    try {
      const supabase = createClient();
      const { error: err } = await supabase
        .from("crm_projects")
        .update({ status, updated_at: new Date().toISOString() })
        .eq("id", projectId);
      if (err) throw err;
      router.refresh();
    } catch (e) {
      setRows(prev);
      setError(e instanceof Error ? e.message : "Could not update status");
    } finally {
      setBusyId(null);
      setDragId(null);
    }
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="font-display text-lg font-bold text-navy">Project pipeline</h2>
        <p className="text-xs text-text-muted">Drag on desktop · tap status on mobile</p>
      </div>
      {error && <p className="rounded-lg bg-error/10 px-3 py-2 text-sm text-error">{error}</p>}
      <div className="-mx-1 flex gap-3 overflow-x-auto px-1 pb-3 snap-x snap-mandatory md:mx-0 md:grid md:grid-cols-4 md:overflow-visible md:px-0 md:pb-2 md:snap-none">
        {COLUMNS.map((col) => (
          <div
            key={col.id}
            className="w-[78vw] max-w-[280px] shrink-0 snap-start rounded-2xl border border-border bg-background p-3 sm:w-[240px] md:w-auto md:max-w-none"
            onDragOver={(e) => e.preventDefault()}
            onDrop={() => {
              if (dragId) void moveTo(dragId, col.id);
            }}
          >
            <p className="mb-2 flex items-center justify-between gap-2 text-xs font-bold uppercase tracking-wide text-text-secondary">
              <span>{col.label}</span>
              <span className="rounded-full bg-surface px-2 py-0.5 text-[10px] text-text-muted">
                {byCol[col.id]?.length ?? 0}
              </span>
            </p>
            <div className="max-h-[22rem] space-y-2 overflow-y-auto md:max-h-[28rem]">
              {(byCol[col.id] ?? []).length === 0 && (
                <p className="rounded-xl border border-dashed border-border px-3 py-6 text-center text-[11px] text-text-muted">
                  Empty
                </p>
              )}
              {(byCol[col.id] ?? []).map((p) => (
                <article
                  key={p.id}
                  draggable
                  onDragStart={() => setDragId(p.id)}
                  className={cn(
                    "cursor-grab rounded-xl border border-border bg-surface p-3 shadow-sm active:cursor-grabbing",
                    busyId === p.id && "opacity-60",
                  )}
                >
                  <p className="text-sm font-bold text-navy">{p.name || "Untitled"}</p>
                  <p className="mt-1 text-xs text-text-secondary">
                    {p.currency} {Number(p.budget || 0).toLocaleString()}
                    {p.priority ? ` · ${p.priority}` : ""}
                    {p.pricing_type === "hourly" ? " · hourly" : ""}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-1">
                    {COLUMNS.filter((c) => c.id !== normalizeStatus(p.status)).map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        disabled={!!busyId}
                        onClick={() => void moveTo(p.id, c.id)}
                        className="rounded-md bg-background px-1.5 py-0.5 text-[10px] font-semibold text-text-secondary hover:text-navy"
                      >
                        → {c.label}
                      </button>
                    ))}
                  </div>
                </article>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
