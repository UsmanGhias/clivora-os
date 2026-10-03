"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { SupportTicket } from "./page";

function statusBadge(s?: string | null) {
  const map: Record<string, string> = {
    open: "bg-amber-100 text-amber-800",
    in_progress: "bg-blue-100 text-blue-800",
    resolved: "bg-emerald-100 text-emerald-800",
    closed: "bg-slate-100 text-slate-600",
  };
  return map[s ?? ""] ?? "bg-slate-100 text-slate-700";
}

function formatDate(iso?: string | null) {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
  } catch {
    return iso;
  }
}

export function SupportClient({
  initial,
  userUid,
  userEmail,
}: {
  initial: SupportTicket[];
  userUid: string;
  userEmail: string;
}) {
  const router = useRouter();
  const [tickets, setTickets] = useState(initial);
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setOk(false);
    try {
      const supabase = createClient();
      const { data, error: err } = await supabase
        .from("support_tickets")
        .insert({
          user_id: userUid,
          subject: subject.trim(),
          body: body.trim(),
          status: "open",
          priority: "normal",
        })
        .select()
        .single();
      if (err) throw err;
      setTickets((prev) => [data as SupportTicket, ...prev]);
      setSubject("");
      setBody("");
      setOk(true);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not submit ticket");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      <form
        onSubmit={submit}
        className="rounded-2xl border border-border bg-surface p-4 space-y-3"
      >
        <p className="text-sm font-semibold text-navy">New support request</p>
        <input
          required
          placeholder="Subject"
          value={subject}
          onChange={(e) => setSubject(e.target.value)}
          className="w-full rounded-xl border border-border px-3 py-2 text-sm"
        />
        <textarea
          required
          rows={4}
          placeholder="Describe your issue or question…"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          className="w-full rounded-xl border border-border px-3 py-2 text-sm"
        />
        {error && <p className="text-sm text-error">{error}</p>}
        {ok && (
          <p className="text-sm text-green-700">
            Ticket submitted. We will reply to {userEmail || "your email"}.
          </p>
        )}
        <button
          type="submit"
          disabled={busy}
          className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Submitting…" : "Submit ticket"}
        </button>
      </form>

      {tickets.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center text-sm text-text-secondary">
          No tickets yet. Submit one above if you need help.
        </div>
      ) : (
        <div className="rounded-2xl border border-border bg-surface overflow-hidden shadow-sm">
          <div className="border-b border-border px-4 py-3">
            <p className="text-sm font-semibold text-navy">{tickets.length} ticket{tickets.length !== 1 ? "s" : ""}</p>
          </div>
          <ul className="divide-y divide-border">
            {tickets.map((t) => (
              <li key={t.id} className="px-4 py-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="text-sm font-semibold">{t.subject || "-"}</p>
                    {t.body && (
                      <p className="mt-1 text-sm text-text-secondary line-clamp-2">{t.body}</p>
                    )}
                    {t.created_at && (
                      <p className="mt-1 text-xs text-text-muted">{formatDate(t.created_at)}</p>
                    )}
                  </div>
                  <span
                    className={`inline-block rounded px-2 py-0.5 text-[10px] font-bold uppercase ${statusBadge(t.status)}`}
                  >
                    {t.status ?? "open"}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
