import { createClient } from "@/lib/supabase/client";

export type WorkspaceTask = {
  id: string;
  owner_uid: string;
  local_id?: number | null;
  project_id?: string | null;
  customer_id?: string | null;
  title: string;
  description: string;
  priority: string;
  status: string;
  due_at?: string | null;
  completed: boolean;
  recurrence_rule?: string | null;
  parent_task_id?: string | null;
  is_milestone: boolean;
  shared_with_uid?: string | null;
  project_share_id?: string | null;
  updated_at: string;
};

async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  return { supabase, user };
}

export async function listWorkspaceTasks(): Promise<WorkspaceTask[]> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("workspace_tasks")
    .select("*")
    .or(`owner_uid.eq.${user.id},shared_with_uid.eq.${user.id}`)
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as WorkspaceTask[];
}

export async function upsertWorkspaceTask(input: {
  id?: string;
  title: string;
  description?: string;
  priority?: string;
  status?: string;
  due_at?: string | null;
  completed?: boolean;
  project_id?: string | null;
  customer_id?: string | null;
  recurrence_rule?: string | null;
  parent_task_id?: string | null;
  is_milestone?: boolean;
  shared_with_uid?: string | null;
  project_share_id?: string | null;
  local_id?: number | null;
}): Promise<string> {
  const { supabase, user } = await requireUser();
  const row = {
    owner_uid: user.id,
    title: input.title.trim(),
    description: input.description?.trim() ?? "",
    priority: input.priority ?? "medium",
    status: input.status ?? "pending",
    due_at: input.due_at || null,
    completed: input.completed ?? false,
    project_id: input.project_id || null,
    customer_id: input.customer_id || null,
    recurrence_rule: input.recurrence_rule || null,
    parent_task_id: input.parent_task_id || null,
    is_milestone: input.is_milestone ?? false,
    shared_with_uid: input.shared_with_uid || null,
    project_share_id: input.project_share_id || null,
    local_id: input.local_id ?? null,
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabase.from("workspace_tasks").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("workspace_tasks").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function deleteWorkspaceTask(id: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("workspace_tasks").delete().eq("id", id);
  if (error) throw error;
}
