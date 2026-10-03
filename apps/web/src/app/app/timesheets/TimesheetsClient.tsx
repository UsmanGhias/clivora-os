"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { TimeEntry } from "./page";

function formatDate(iso?: string | null) {
  if (!iso) return "-";
  return iso.slice(0, 10);
}

function statusBadge(s?: string | null) {
  const map: Record<string, string> = {
    pending: "bg-amber-100 text-amber-800",
    approved: "bg-emerald-100 text-emerald-800",
    rejected: "bg-red-100 text-red-800",
  };
  return map[s ?? ""] ?? "bg-slate-100 text-slate-700";
}

export function TimesheetsClient({
  initial,
  ownerUid,
}: {
  initial: TimeEntry[];
  ownerUid: string;
}) {
  const router = useRouter();
  const [entries, setEntries] = useState(initial);
  const [description, setDescription] = useState("");
  const [hours, setHours] = useState("");
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState(false);

  async function addEntry(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setOk(false);
    try {
      const supabase = createClient();
      const { data, error: err } = await supabase
        .from("crm_time_entries")
        .insert({
          owner_uid: ownerUid,
          description: description.trim(),
          hours: hours ? Number(hours) : null,
          date: date || null,
          status: "pending",
        })
        .select()
        .single();
      if (err) throw err;
      setEntries((prev) => [data as TimeEntry, ...prev]);
      setDescription("");
      setHours("");
      setOk(true);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not add entry");
    } finally {
      setBusy(false);
    }
  }

  async function updateStatus(id: string, status: "approved" | "rejected") {
    setBusy(true);
    try {
      const supabase = createClient();
      await supabase
        .from("crm_time_entries")
        .update({ status })
        .eq("id", id)
        .eq("owner_uid", ownerUid);
      setEntries((prev) =>
        prev.map((e) => (e.id === id ? { ...e, status } : e)),
      );
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  const totalHours = entries.reduce((s, e) => s + (e.hours ?? 0), 0);

  return (
    <div className="space-y-4">
      <form
        onSubmit={addEntry}
        className="rounded-2xl border border-border bg-surface p-4 space-y-3"
      >
        <p className="text-sm font-semibold text-navy">Log time</p>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          <input
            required
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="rounded-xl border border-border px-3 py-2 text-sm"
          />
          <input
            required
            type="number"
            min="0.1"
            step="0.25"
            placeholder="Hours"
            value={hours}
            onChange={(e) => setHours(e.target.value)}
            className="rounded-xl border border-border px-3 py-2 text-sm"
          />
          <input
            required
            placeholder="Description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="col-span-2 rounded-xl border border-border px-3 py-2 text-sm sm:col-span-1"
          />
        </div>
        {error && <p className="text-sm text-error">{error}</p>}
        {ok && <p className="text-sm text-green-700">Entry logged.</p>}
        <button
          type="submit"
          disabled={busy}
          className="rounded-full bg-navy px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        >
          {busy ? "Saving…" : "Log entry"}
        </button>
      </form>

      {entries.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center text-sm text-text-secondary">
          No time entries yet. Log your first entry above.
        </div>
      ) : (
        <div className="rounded-2xl border border-border bg-surface overflow-hidden shadow-sm">
          <div className="flex items-center justify-between px-4 py-3 border-b border-border">
            <p className="text-sm font-semibold text-navy">
              {entries.length} entries · {totalHours.toFixed(1)} hrs total
            </p>
          </div>
          <ul className="divide-y divide-border">
            {entries.map((entry) => (
              <li key={entry.id} className="flex flex-wrap items-start justify-between gap-2 px-4 py-3">
                <div>
                  <p className="text-sm font-medium">{entry.description || "-"}</p>
                  <p className="text-xs text-text-muted mt-0.5">
                    {formatDate(entry.date)}
                    {entry.hours != null ? ` · ${entry.hours}h` : ""}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <span
                    className={`inline-block rounded px-2 py-0.5 text-[10px] font-bold uppercase ${statusBadge(entry.status)}`}
                  >
                    {entry.status ?? "pending"}
                  </span>
                  {entry.status === "pending" && (
                    <>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => updateStatus(entry.id, "approved")}
                        className="rounded-lg bg-emerald-600 px-2 py-0.5 text-[10px] font-bold text-white disabled:opacity-50"
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => updateStatus(entry.id, "rejected")}
                        className="rounded-lg bg-red-600 px-2 py-0.5 text-[10px] font-bold text-white disabled:opacity-50"
                      >
                        Reject
                      </button>
                    </>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
