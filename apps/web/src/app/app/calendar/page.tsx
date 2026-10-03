import { getProfile } from "@/lib/profile";
import { isFeatureEnabled } from "@/lib/feature-flags";
import { redirect } from "next/navigation";
import { CalendarEventsClient } from "./CalendarEventsClient";

export default async function CalendarPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const enabled =
    (await isFeatureEnabled("calendar_events")) ||
    (await isFeatureEnabled("phase3_calendar_events"));
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">Calendar</h1>
        <p className="text-sm text-text-secondary">Project-linked cloud events (web ↔ mobile when enabled).</p>
      </div>
      {enabled ? (
        <CalendarEventsClient />
      ) : (
        <p className="rounded-2xl border border-dashed border-border bg-surface p-6 text-sm text-text-secondary">
          Calendar cloud events are behind a feature flag and not enabled yet.
        </p>
      )}
    </div>
  );
}
