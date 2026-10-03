import { createClient } from "@/lib/supabase/server";
import { getProfile, isClientAccount } from "@/lib/profile";
import { TasksClient, type TaskPeer, type TaskRow } from "./TasksClient";

export const metadata = { title: "Tasks" };

export default async function TasksPage() {
  const profile = await getProfile();
  const client = isClientAccount(profile);
  const supabase = await createClient();
  let rows: TaskRow[] = [];
  let peers: TaskPeer[] = [];

  try {
    const col = client ? "client_uid" : "freelancer_uid";
    const { data, error } = await supabase
      .from("client_tasks")
      .select("id, title, status, description, created_at, is_read, project_share_id, client_uid, freelancer_uid")
      .eq(col, profile?.id ?? "")
      .order("created_at", { ascending: false })
      .limit(40);
    if (!error && data) {
      rows = data;
    } else if (error?.message?.includes("is_read") || error?.message?.includes("project_share")) {
      const { data: fallback } = await supabase
        .from("client_tasks")
        .select("id, title, status, description, created_at, client_uid, freelancer_uid")
        .eq(col, profile?.id ?? "")
        .order("created_at", { ascending: false })
        .limit(40);
      if (fallback) {
        rows = fallback;
      }
    }
  } catch {
    rows = [];
  }

  if (profile?.id) {
    try {
      let shareQuery = supabase
        .from("project_shares")
        .select("share_id, project_name, freelancer_uid, freelancer_email, client_uid, client_email")
        .order("updated_at", { ascending: false })
        .limit(100);
      shareQuery = client
        ? profile.email
          ? shareQuery.or(`client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`)
          : shareQuery.eq("client_uid", profile.id)
        : shareQuery.eq("freelancer_uid", profile.id);
      const { data: shareRows } = await shareQuery;
      peers = (shareRows ?? [])
        .flatMap((share, index) => {
          const peerUid = client ? share.freelancer_uid : share.client_uid;
          if (!peerUid) return [];
          const projectName = share.project_name?.trim() || "Shared project";
          const peerLabel = client ? share.freelancer_email : share.client_email;
          return [{
            id: share.share_id || `${peerUid}-${index}`,
            label: peerLabel ? `${projectName} · ${peerLabel}` : projectName,
            peerUid,
            projectShareId: share.share_id ?? null,
          }];
        });
    } catch {
      peers = [];
    }
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold">Tasks</h1>
        <p className="text-sm text-text-secondary">
          Shared client tasks from your freelancer/client workspace.
          {!client ? (
            <>
              {" "}
              Freelancer workspace tasks (cloud sync):{" "}
              <a className="font-semibold text-primary underline" href="/app/workspace-tasks">
                /app/workspace-tasks
              </a>
            </>
          ) : null}
        </p>
      </div>
      <TasksClient
        initial={rows}
        isClient={!!client}
        canCreate={!!client && peers.length > 0}
        peers={peers}
      />
    </div>
  );
}
