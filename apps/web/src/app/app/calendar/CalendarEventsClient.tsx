"use client";

import { FormEvent, useEffect, useState } from "react";
import { listCalendarEvents, upsertCalendarEvent, type CalendarEvent } from "@/lib/calendar-events";

export function CalendarEventsClient() {
  const [rows, setRows] = useState<CalendarEvent[]>([]);
  const [title, setTitle] = useState("");
  const [startsAt, setStartsAt] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setRows(await listCalendarEvents());
  }

  useEffect(() => {
    void refresh().catch((e) => setError(e instanceof Error ? e.message : "Load failed"));
  }, []);

  async function onCreate(e: FormEvent) {
    e.preventDefault();
    if (!title.trim() || !startsAt) return;
    setBusy(true);
    setError(null);
    try {
      await upsertCalendarEvent({ title, starts_at: new Date(startsAt).toISOString() });
      setTitle("");
      setStartsAt("");
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
          placeholder="Event title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          aria-label="Event title"
        />
        <input
          type="datetime-local"
          className="rounded-lg border border-border px-3 py-2 text-sm"
          value={startsAt}
          onChange={(e) => setStartsAt(e.target.value)}
          aria-label="Starts at"
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded-lg bg-primary px-3 py-2 text-sm font-bold text-white disabled:opacity-60"
        >
          Add event
        </button>
      </form>
      <ul className="space-y-2">
        {rows.map((ev) => (
          <li key={ev.id} className="rounded-xl border border-border bg-surface px-4 py-3 text-sm">
            <p className="font-semibold text-navy">{ev.title}</p>
            <p className="text-text-muted">{new Date(ev.starts_at).toLocaleString()}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
