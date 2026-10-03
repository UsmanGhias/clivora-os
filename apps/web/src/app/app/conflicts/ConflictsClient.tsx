"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

type Row = Record<string, unknown>;

function asRecord(v: unknown): Record<string, unknown> {
  if (v && typeof v === "object" && !Array.isArray(v)) return v as Record<string, unknown>;
  return {};
}

export function ConflictsClient({ initial }: { initial: Row[] }) {
  const [rows, setRows] = useState(initial);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function resolve(id: string, resolution: "keep_local" | "take_cloud") {
    setBusy(id);
    setError(null);
    try {
      const supabase = createClient();
      const row = rows.find((r) => String(r.id) === id);
      if (!row) throw new Error("Conflict not found");

      const entityType = String(row.entity_type || "");
      const entityId = row.entity_id ? String(row.entity_id) : null;
      const localSnap = asRecord(row.local_snapshot);
      const cloudSnap = asRecord(row.cloud_snapshot);

      if (entityType === "customer" && entityId) {
        if (resolution === "keep_local") {
          const patch: Record<string, unknown> = {
            updated_at: new Date().toISOString(),
          };
          if (typeof localSnap.contact_person === "string") {
            patch.contact_person = localSnap.contact_person;
          }
          if (typeof localSnap.company === "string") {
            patch.company = localSnap.company;
          }
          const { error: upErr } = await supabase
            .from("crm_customers")
            .update(patch)
            .eq("id", entityId);
          if (upErr) throw upErr;
        } else if (resolution === "take_cloud") {
          const patch: Record<string, unknown> = {
            updated_at: new Date().toISOString(),
          };
          if (typeof cloudSnap.contact_person === "string") {
            patch.contact_person = cloudSnap.contact_person;
          }
          if (typeof cloudSnap.company === "string") {
            patch.company = cloudSnap.company;
          }
          const { error: upErr } = await supabase
            .from("crm_customers")
            .update(patch)
            .eq("id", entityId);
          if (upErr) throw upErr;
        }
      }

      const { error: err } = await supabase
        .from("crm_sync_conflicts")
        .update({
          status: "resolved",
          resolution,
          resolved_at: new Date().toISOString(),
        })
        .eq("id", id);
      if (err) throw err;
      setRows((prev) => prev.filter((r) => r.id !== id));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Resolve failed");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="space-y-3">
      {error ? <p className="text-sm text-red-700">{error}</p> : null}
      {rows.length === 0 ? (
        <p className="text-sm text-text-secondary">No open conflicts.</p>
      ) : (
        rows.map((r) => (
          <article
            key={String(r.id)}
            className="rounded-xl border border-border bg-surface p-4 text-sm"
          >
            <p className="font-semibold text-navy">
              {String(r.entity_type)} {r.local_id != null ? `#${String(r.local_id)}` : ""}
            </p>
            <div className="mt-2 grid gap-2 sm:grid-cols-2">
              <pre className="overflow-auto rounded-lg bg-background p-2 text-xs">
                Local: {JSON.stringify(r.local_snapshot, null, 2)}
              </pre>
              <pre className="overflow-auto rounded-lg bg-background p-2 text-xs">
                Cloud: {JSON.stringify(r.cloud_snapshot, null, 2)}
              </pre>
            </div>
            <div className="mt-3 flex gap-2">
              <button
                type="button"
                disabled={busy === r.id}
                className="rounded-lg border border-border px-3 py-1.5 text-sm font-bold"
                onClick={() => void resolve(String(r.id), "keep_local")}
              >
                Keep local
              </button>
              <button
                type="button"
                disabled={busy === r.id}
                className="rounded-lg border border-border px-3 py-1.5 text-sm font-bold"
                onClick={() => void resolve(String(r.id), "take_cloud")}
              >
                Take cloud
              </button>
            </div>
          </article>
        ))
      )}
    </div>
  );
}
