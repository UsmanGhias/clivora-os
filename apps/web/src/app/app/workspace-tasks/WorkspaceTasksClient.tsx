"use client";

import { FormEvent, useEffect, useState } from "react";
import {
  deleteWorkspaceTask,
  listWorkspaceTasks,
  upsertWorkspaceTask,
  type WorkspaceTask,
} from "@/lib/workspace-tasks";

export function WorkspaceTasksClient() {
  const [rows, setRows] = useState<WorkspaceTask[]>([]);
  const [title, setTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setRows(await listWorkspaceTasks());
  }

  useEffect(() => {
    void refresh().catch((e) => setError(e instanceof Error ? e.message : "Load failed"));
  }, []);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await upsertWorkspaceTask({ title, priority: "medium", status: "pending" });
      setTitle("");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      {error ? <p className="text-sm text-red-700">{error}</p> : null}
      <form onSubmit={onCreate} className="flex flex-wrap gap-2">
        <input
          className="min-w-[12rem] flex-1 rounded-lg border border-border px-3 py-2 text-sm"
          placeholder="Task title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          aria-label="Task title"
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded-lg bg-primary px-3 py-2 text-sm font-bold text-white disabled:opacity-60"
        >
          Add task
        </button>
      </form>
      <ul className="space-y-2">
        {rows.map((t) => (
          <li
            key={t.id}
            className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-border bg-surface px-4 py-3 text-sm"
          >
            <div>
              <p className="font-semibold text-navy">{t.title}</p>
              <p className="text-text-muted">
                {t.status} · {t.priority}
                {t.is_milestone ? " · milestone" : ""}
              </p>
            </div>
            <button
              type="button"
              disabled={busy}
              className="rounded-lg border border-border px-3 py-1.5 text-sm font-bold"
              onClick={() =>
                void (async () => {
                  setBusy(true);
                  try {
                    await deleteWorkspaceTask(t.id);
                    await refresh();
                  } catch (err) {
                    setError(err instanceof Error ? err.message : "Delete failed");
                  } finally {
                    setBusy(false);
                  }
                })()
              }
            >
              Delete
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
