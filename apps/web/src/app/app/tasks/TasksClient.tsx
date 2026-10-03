"use client";

import { FormEvent, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

export type TaskRow = {
  id: string;
  title?: string | null;
  status?: string | null;
  description?: string | null;
  is_read?: boolean | null;
  created_at?: string | null;
  project_share_id?: string | null;
};

export type TaskPeer = {
  id: string;
  label: string;
  peerUid: string;
  projectShareId?: string | null;
};

const STATUSES = [
  { value: "open", label: "Open" },
  { value: "in_progress", label: "In progress" },
  { value: "done", label: "Done" },
] as const;

type Filter = "all" | "open" | "in_progress" | "done" | "unread";

function normalizeStatus(status?: string | null) {
  const s = (status || "open").toLowerCase().replace(/\s+/g, "_");
  if (s === "pending" || s === "todo") return "open";
  if (s === "completed" || s === "complete") return "done";
  if (s === "in_progress" || s === "open" || s === "done") return s;
  return "open";
}

function statusTone(status: string) {
  if (status === "done") return "bg-success/10 text-success";
  if (status === "in_progress") return "bg-amber-100 text-amber-900";
  return "bg-sky-100 text-sky-900";
}

function formatCreated(iso?: string | null) {
  if (!iso) return null;
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
    });
  } catch {
    return null;
  }
}

export function TasksClient({
  initial,
  isClient = false,
  canCreate = false,
  peers = [],
}: {
  initial: TaskRow[];
  isClient?: boolean;
  canCreate?: boolean;
  peers?: TaskPeer[];
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>("all");
  const [selectedPeerId, setSelectedPeerId] = useState(peers[0]?.id ?? "");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [createBusy, setCreateBusy] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);
  const accentBtn = isClient
    ? "bg-client-accent hover:bg-client-header"
    : "bg-primary hover:bg-primary-dark";
  const activeRing = isClient
    ? "ring-2 ring-client-accent"
    : "ring-2 ring-primary";
  const canCreateTask = isClient && canCreate;
  const selectedPeer = peers.find((p) => p.id === selectedPeerId) ?? peers[0] ?? null;

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      const status = normalizeStatus(r.status);
      if (filter === "unread") return r.is_read === false;
      if (filter === "all") return true;
      return status === filter;
    });
  }, [rows, filter]);

  const counts = useMemo(() => {
    const base = { all: rows.length, open: 0, in_progress: 0, done: 0, unread: 0 };
    for (const r of rows) {
      const status = normalizeStatus(r.status);
      if (status in base) base[status as keyof typeof base] += 1;
      if (r.is_read === false) base.unread += 1;
    }
    return base;
  }, [rows]);

  async function updateStatus(id: string, status: string) {
    setBusyId(id);
    try {
      const supabase = createClient();
      const payload: { status: string; is_read?: boolean } = { status };
      payload.is_read = true;
      const { error } = await supabase
        .from("client_tasks")
        .update(payload)
        .eq("id", id);
      if (error) {
        if (error.message?.includes("is_read")) {
          const { error: err2 } = await supabase
            .from("client_tasks")
            .update({ status })
            .eq("id", id);
          if (err2) throw err2;
        } else {
          throw error;
        }
      }
      setRows((prev) =>
        prev.map((r) =>
          r.id === id ? { ...r, status, is_read: true } : r,
        ),
      );
      router.refresh();
    } finally {
      setBusyId(null);
    }
  }

  async function markRead(id: string) {
    const row = rows.find((r) => r.id === id);
    if (!row || row.is_read) return;
    setBusyId(id);
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from("client_tasks")
        .update({ is_read: true })
        .eq("id", id);
      if (error) {
        if (!error.message?.includes("is_read")) throw error;
        return;
      }
      setRows((prev) =>
        prev.map((r) => (r.id === id ? { ...r, is_read: true } : r)),
      );
      router.refresh();
    } finally {
      setBusyId(null);
    }
  }

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!canCreateTask || !selectedPeer || !title.trim()) return;
    setCreateBusy(true);
    setCreateError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const payload = isClient
        ? {
            client_uid: user.id,
            freelancer_uid: selectedPeer.peerUid,
            project_share_id: selectedPeer.projectShareId ?? null,
            title: title.trim(),
            description: description.trim(),
            status: "open",
          }
        : {
            client_uid: selectedPeer.peerUid,
            freelancer_uid: user.id,
            project_share_id: selectedPeer.projectShareId ?? null,
            title: title.trim(),
            description: description.trim(),
            status: "open",
          };
      const { data, error } = await supabase
        .from("client_tasks")
        .insert(payload)
        .select("id, title, status, description, created_at, is_read, project_share_id")
        .single();
      if (error) throw error;
      setRows((prev) => [data as TaskRow, ...prev]);
      setTitle("");
      setDescription("");
      router.refresh();
    } catch (err) {
      setCreateError(err instanceof Error ? err.message : "Could not create task");
    } finally {
      setCreateBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      {canCreateTask && peers.length > 0 && (
        <form
          onSubmit={onCreate}
          className="space-y-3 rounded-2xl border border-border bg-surface p-4 shadow-sm"
        >
          <p className="text-sm font-bold text-navy">Add task</p>
          <label className="block text-xs font-semibold text-text-secondary">
            Peer / project
            <select
              value={selectedPeer?.id ?? ""}
              onChange={(e) => setSelectedPeerId(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border px-3 py-2 text-sm"
            >
              {peers.map((peer) => (
                <option key={peer.id} value={peer.id}>
                  {peer.label}
                </option>
              ))}
            </select>
          </label>
          <input
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Task title"
            className="w-full rounded-xl border border-border px-3 py-2 text-sm"
          />
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Optional details"
            rows={2}
            className="w-full rounded-xl border border-border px-3 py-2 text-sm"
          />
          {createError && <p className="text-sm text-error">{createError}</p>}
          <button
            type="submit"
            disabled={createBusy || !title.trim()}
            className={cn(
              "rounded-xl px-4 py-2 text-sm font-semibold text-white disabled:opacity-50",
              accentBtn,
            )}
          >
            {createBusy ? "Adding…" : "Add task"}
          </button>
        </form>
      )}

      <div className="flex flex-wrap gap-1.5">
        {(
          [
            ["all", "All"],
            ["open", "Open"],
            ["in_progress", "In progress"],
            ["done", "Done"],
            ["unread", "Unread"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setFilter(key)}
            className={cn(
              "rounded-lg px-3 py-1.5 text-xs font-bold",
              filter === key
                ? cn("text-white", accentBtn)
                : "border border-border bg-background text-text-secondary",
            )}
          >
            {label} {counts[key]}
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
          <p className="font-semibold text-navy">
            {rows.length === 0 ? "No shared tasks yet" : "No tasks match this filter"}
          </p>
          <p className="mt-1 text-sm text-text-secondary">
            Tasks appear when a client or freelancer assigns work on a shared project.
          </p>
        </div>
      ) : (
        <ul className="space-y-2">
          {filtered.map((r) => {
            const status = normalizeStatus(r.status);
            const unread = r.is_read === false;
            const created = formatCreated(r.created_at);
            return (
              <li
                key={r.id}
                className={cn(
                  "rounded-xl border bg-surface px-4 py-3",
                  unread
                    ? isClient
                      ? "border-client-accent/30 bg-client-surface"
                      : "border-primary/30 bg-primary/5"
                    : "border-border",
                )}
              >
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-semibold text-navy">{r.title || "Task"}</p>
                      <span
                        className={cn(
                          "rounded-full px-2 py-0.5 text-[10px] font-bold",
                          statusTone(status),
                        )}
                      >
                        {STATUSES.find((s) => s.value === status)?.label ?? status}
                      </span>
                      {unread && (
                        <span className="rounded-full bg-sky-500 px-2 py-0.5 text-[10px] font-bold text-white">
                          New
                        </span>
                      )}
                    </div>
                    {r.description && (
                      <p className="mt-1 text-sm text-text-secondary line-clamp-2">
                        {r.description}
                      </p>
                    )}
                    <p className="mt-2 text-[11px] text-text-muted">
                      {[created ? `Created ${created}` : null, r.project_share_id ? "Linked to project" : null]
                        .filter(Boolean)
                        .join(" · ") || "Shared workspace task"}
                    </p>
                  </div>
                  {unread && (
                    <button
                      type="button"
                      disabled={busyId === r.id}
                      onClick={() => void markRead(r.id)}
                      className="text-xs font-semibold text-text-muted hover:text-navy disabled:opacity-50"
                    >
                      Mark read
                    </button>
                  )}
                </div>
                <div className="mt-3 flex flex-wrap gap-1.5">
                  {STATUSES.map((s) => (
                    <button
                      key={s.value}
                      type="button"
                      disabled={busyId === r.id}
                      onClick={() => void updateStatus(r.id, s.value)}
                      className={cn(
                        "rounded-lg px-3 py-1.5 text-xs font-bold transition disabled:opacity-50",
                        status === s.value
                          ? cn("text-white", accentBtn, activeRing)
                          : "border border-border bg-background text-text-secondary hover:bg-surface",
                      )}
                    >
                      {s.label}
                    </button>
                  ))}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
