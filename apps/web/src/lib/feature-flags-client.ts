import { createClient } from "@/lib/supabase/client";

/** Browser-safe feature flag read (defaults false on error). */
export async function isFeatureEnabledClient(key: string): Promise<boolean> {
  try {
    const supabase = createClient();
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
