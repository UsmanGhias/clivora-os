"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { CheckCheck, Trash2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export type NotificationRow = {
  id: string;
  title?: string | null;
  body?: string | null;
  created_at?: string | null;
  is_read?: boolean | null;
  user_uid?: string | null;
};

export function NotificationsClient({
  initial,
  isClient = false,
}: {
  initial: NotificationRow[];
  isClient?: boolean;
}) {
  const router = useRouter();
  const [rows, setRows] = useState(initial);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [busyAll, setBusyAll] = useState(false);

  const unreadCount = rows.filter((r) => !r.is_read).length;
  const accent = isClient ? "text-client-accent" : "text-primary";
  const unreadBorder = isClient
    ? "border-client-accent/30 bg-client-surface"
    : "border-primary/30 bg-primary/5";

  async function markRead(id: string) {
    setBusyId(id);
    try {
      const supabase = createClient();
      const { error } = await supabase
        .from("notifications")
        .update({ is_read: true })
        .eq("id", id);
      if (error) throw error;
      setRows((prev) => prev.map((r) => (r.id === id ? { ...r, is_read: true } : r)));
      router.refresh();
    } finally {
      setBusyId(null);
    }
  }

  async function markAllRead() {
    if (unreadCount === 0 || busyAll) return;
    setBusyAll(true);
    try {
      const supabase = createClient();
      const ids = rows.filter((r) => !r.is_read).map((r) => r.id);
      if (ids.length === 0) return;
      const { error } = await supabase
        .from("notifications")
        .update({ is_read: true })
        .in("id", ids);
      if (error) throw error;
      setRows((prev) => prev.map((r) => ({ ...r, is_read: true })));
      router.refresh();
    } finally {
      setBusyAll(false);
    }
  }

  async function deleteOne(id: string) {
    setBusyId(id);
    try {
      const supabase = createClient();
      const { error } = await supabase.from("notifications").delete().eq("id", id);
      if (error) throw error;
      setRows((prev) => prev.filter((r) => r.id !== id));
      router.refresh();
    } finally {
      setBusyId(null);
    }
  }

  if (rows.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
        <p className="font-semibold text-navy">No notifications yet</p>
        <p className="mt-2 text-sm text-text-secondary">
          Updates about proposals, projects, and payments will appear here.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-text-secondary">
          {unreadCount > 0 ? `${unreadCount} unread` : "All caught up"}
        </p>
        {unreadCount > 0 && (
          <button
            type="button"
            onClick={markAllRead}
            disabled={busyAll}
            className={`inline-flex items-center gap-1.5 text-sm font-semibold ${accent} disabled:opacity-50`}
          >
            <CheckCheck className="h-4 w-4" />
            {busyAll ? "Marking…" : "Mark all read"}
          </button>
        )}
      </div>
      <ul className="space-y-2">
        {rows.map((r) => {
          const busy = busyId === r.id;
          return (
            <li
              key={r.id}
              className={`rounded-xl border px-4 py-3 ${
                r.is_read ? "border-border bg-surface" : unreadBorder
              }`}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <p className="font-semibold text-navy">{r.title || "Update"}</p>
                  {r.body && <p className="mt-1 text-sm text-text-secondary">{r.body}</p>}
                  <p className="mt-1 text-xs text-text-muted">
                    {r.created_at ? new Date(r.created_at).toLocaleString() : ""}
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-1">
                  {!r.is_read && (
                    <button
                      type="button"
                      onClick={() => markRead(r.id)}
                      disabled={busy}
                      className={`rounded-lg px-2 py-1 text-xs font-semibold ${accent} hover:underline disabled:opacity-50`}
                    >
                      {busy ? "…" : "Mark read"}
                    </button>
                  )}
                  <button
                    type="button"
                    onClick={() => deleteOne(r.id)}
                    disabled={busy}
                    className="inline-flex items-center justify-center rounded-lg p-1.5 text-text-muted hover:bg-error/10 hover:text-error disabled:opacity-50"
                    aria-label="Delete notification"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
