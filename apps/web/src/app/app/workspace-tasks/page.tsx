import { getProfile } from "@/lib/profile";
import { isFeatureEnabled } from "@/lib/feature-flags";
import { redirect } from "next/navigation";
import { WorkspaceTasksClient } from "./WorkspaceTasksClient";

export default async function WorkspaceTasksPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const enabled =
    (await isFeatureEnabled("workspace_tasks")) ||
    (await isFeatureEnabled("phase2_workspace_tasks"));
  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">Workspace tasks</h1>
        <p className="text-sm text-text-secondary">
          Unified cloud tasks (priority, deadlines, recurrence, milestones). Syncs with Android when enabled.
        </p>
      </div>
      {enabled ? (
        <WorkspaceTasksClient />
      ) : (
        <p className="rounded-2xl border border-dashed border-border bg-surface p-6 text-sm text-text-secondary">
          Workspace tasks flag is off. Legacy shared tasks remain at{" "}
          <a className="font-semibold text-primary underline" href="/app/tasks">
            /app/tasks
          </a>
          .
        </p>
      )}
    </div>
  );
}
