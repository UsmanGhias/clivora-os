import { getProfile } from "@/lib/profile";
import { isFeatureEnabled } from "@/lib/feature-flags";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { ConflictsClient } from "./ConflictsClient";

export default async function ConflictsPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const enabled =
    (await isFeatureEnabled("crm_conflict_ui")) ||
    (await isFeatureEnabled("phase4_crm_conflicts"));

  let rows: Array<Record<string, unknown>> = [];
  if (enabled) {
    const supabase = await createClient();
    const { data } = await supabase
      .from("crm_sync_conflicts")
      .select("*")
      .eq("owner_uid", profile.id)
      .eq("status", "open")
      .order("created_at", { ascending: false })
      .limit(50);
    rows = (data ?? []) as Array<Record<string, unknown>>;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">CRM sync conflicts</h1>
        <p className="text-sm text-text-secondary">
          Resolve divergent local vs cloud CRM edits (Keep local / Take cloud).
        </p>
      </div>
      {enabled ? (
        <ConflictsClient initial={rows} />
      ) : (
        <p className="rounded-2xl border border-dashed border-border bg-surface p-6 text-sm text-text-secondary">
          Conflict UI is behind a feature flag and not enabled yet.
        </p>
      )}
    </div>
  );
}
