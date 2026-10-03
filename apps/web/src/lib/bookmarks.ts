import { createClient } from "@/lib/supabase/client";

export type BookmarkTargetType = "freelancer" | "job";

export async function toggleBookmark({
  targetId,
  targetType,
  title,
  meta,
  saved,
}: {
  targetId: string;
  targetType: BookmarkTargetType;
  title?: string | null;
  meta?: Record<string, unknown>;
  saved: boolean;
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");

  if (saved) {
    const { error } = await supabase
      .from("freelancer_bookmarks")
      .delete()
      .eq("user_id", user.id)
      .eq("target_type", targetType)
      .eq("target_id", targetId);
    if (error) throw error;
    return false;
  }

  const { error } = await supabase.from("freelancer_bookmarks").upsert(
    {
      user_id: user.id,
      target_type: targetType,
      target_id: targetId,
      title: title ?? null,
      meta: meta ?? {},
    },
    { onConflict: "user_id,target_type,target_id" },
  );
  if (error) throw error;
  return true;
}

export async function listSavedIds(targetTypes: BookmarkTargetType[] = ["freelancer", "job"]) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];

  const { data, error } = await supabase
    .from("freelancer_bookmarks")
    .select("target_id")
    .eq("user_id", user.id)
    .in("target_type", targetTypes);
  if (error) throw error;
  return (data ?? []).map((row) => String(row.target_id));
}
