"use client";

import { FormEvent, useEffect, useState } from "react";
import {
  addActivity,
  findDuplicateCustomers,
  listActivities,
  listCompanies,
  recomputeLeadScore,
  upsertCompany,
  type CrmActivity,
  type CrmCompany,
} from "@/lib/crm/enrichment";
import { isFeatureEnabledClient } from "@/lib/feature-flags-client";

export function CrmEnrichmentPanel({ customerId }: { customerId?: string | null }) {
  const [enabled, setEnabled] = useState(false);
  const [companies, setCompanies] = useState<CrmCompany[]>([]);
  const [activities, setActivities] = useState<CrmActivity[]>([]);
  const [score, setScore] = useState<number | null>(null);
  const [dupes, setDupes] = useState<
    Array<{ id: string; contact_person: string; company: string; score: number }>
  >([]);
  const [companyName, setCompanyName] = useState("");
  const [noteTitle, setNoteTitle] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      const on =
        (await isFeatureEnabledClient("crm_enrichment")) ||
        (await isFeatureEnabledClient("phase1_crm_enrichment"));
      setEnabled(on);
      if (!on) return;
      try {
        setCompanies(await listCompanies());
        if (customerId) {
          setActivities(await listActivities(customerId));
        }
      } catch (e) {
        setError(e instanceof Error ? e.message : "Failed to load enrichment");
      }
    })();
  }, [customerId]);

  if (!enabled) return null;

  async function onAddCompany(e: FormEvent) {
    e.preventDefault();
    if (!companyName.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await upsertCompany({ name: companyName });
      setCompanyName("");
      setCompanies(await listCompanies());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed");
    } finally {
      setBusy(false);
    }
  }

  async function onAddNote(e: FormEvent) {
    e.preventDefault();
    if (!customerId || !noteTitle.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await addActivity({ customer_id: customerId, title: noteTitle, activity_type: "note" });
      setNoteTitle("");
      setActivities(await listActivities(customerId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Activity failed");
    } finally {
      setBusy(false);
    }
  }

  async function onScore() {
    if (!customerId) return;
    setBusy(true);
    setError(null);
    try {
      setScore(await recomputeLeadScore(customerId));
      setDupes(await findDuplicateCustomers(customerId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Score failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="mt-6 space-y-4 rounded-2xl border border-border bg-surface p-5">
      <div>
        <h2 className="text-lg font-extrabold text-navy">CRM enrichment</h2>
        <p className="text-sm text-text-secondary">
          Companies, timeline, lead score, and duplicates (flag-gated).
        </p>
      </div>
      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <form onSubmit={onAddCompany} className="flex flex-wrap gap-2">
        <input
          className="min-w-[12rem] flex-1 rounded-lg border border-border px-3 py-2 text-sm"
          placeholder="Company name"
          value={companyName}
          onChange={(e) => setCompanyName(e.target.value)}
          aria-label="Company name"
        />
        <button
          type="submit"
          disabled={busy}
          className="rounded-lg bg-primary px-3 py-2 text-sm font-bold text-white disabled:opacity-60"
        >
          Add company
        </button>
      </form>
      <ul className="text-sm text-text-secondary">
        {companies.slice(0, 8).map((c) => (
          <li key={c.id}>{c.name}</li>
        ))}
      </ul>

      {customerId ? (
        <>
          <form onSubmit={onAddNote} className="flex flex-wrap gap-2">
            <input
              className="min-w-[12rem] flex-1 rounded-lg border border-border px-3 py-2 text-sm"
              placeholder="Activity title"
              value={noteTitle}
              onChange={(e) => setNoteTitle(e.target.value)}
              aria-label="Activity title"
            />
            <button
              type="submit"
              disabled={busy}
              className="rounded-lg bg-primary px-3 py-2 text-sm font-bold text-white disabled:opacity-60"
            >
              Log activity
            </button>
          </form>
          <ul className="space-y-1 text-sm">
            {activities.slice(0, 10).map((a) => (
              <li key={a.id}>
                <span className="font-semibold">{a.activity_type}</span>: {a.title}
              </li>
            ))}
          </ul>
          <button
            type="button"
            onClick={() => void onScore()}
            disabled={busy}
            className="rounded-lg border border-border px-3 py-2 text-sm font-bold disabled:opacity-60"
          >
            Recompute lead score &amp; duplicates
          </button>
          {score != null ? <p className="text-sm">Lead score: {score}</p> : null}
          {dupes.length > 0 ? (
            <ul className="text-sm text-text-secondary">
              {dupes
                .filter((d) => d.score > 0)
                .map((d) => (
                  <li key={d.id}>
                    Possible duplicate: {d.contact_person} ({d.company}) - {d.score}
                  </li>
                ))}
            </ul>
          ) : null}
        </>
      ) : null}
    </section>
  );
}
