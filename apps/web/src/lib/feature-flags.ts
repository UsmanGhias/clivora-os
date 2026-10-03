import "server-only";
import { createClient } from "@/lib/supabase/server";

/** Read a boolean feature flag from app_feature_flags (defaults to false). */
export async function isFeatureEnabled(key: string): Promise<boolean> {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("app_feature_flags")
      .select("enabled")
      .eq("key", key)
      .maybeSingle();
    if (error || !data) return false;
    return data.enabled === true;
  } catch {
    return false;
  }
}

export async function writeAuditEvent(input: {
  action: string;
  entityType: string;
  entityId?: string | null;
  workspaceUid?: string | null;
  payload?: Record<string, unknown>;
}): Promise<string | null> {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("write_audit_event", {
      p_action: input.action,
      p_entity_type: input.entityType,
      p_entity_id: input.entityId ?? null,
      p_workspace_uid: input.workspaceUid ?? null,
      p_payload: input.payload ?? {},
    });
    if (error) return null;
    return data as string;
  } catch {
    return null;
  }
}
