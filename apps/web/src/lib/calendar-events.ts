import { createClient } from "@/lib/supabase/client";

export type CalendarEvent = {
  id: string;
  owner_uid: string;
  title: string;
  description: string;
  starts_at: string;
  ends_at?: string | null;
  location?: string;
  project_id?: string | null;
  customer_id?: string | null;
  meeting_link_id?: string | null;
  all_day: boolean;
};

async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  return { supabase, user };
}

export async function listCalendarEvents(): Promise<CalendarEvent[]> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("calendar_events")
    .select("*")
    .eq("owner_uid", user.id)
    .order("starts_at", { ascending: true });
  if (error) throw error;
  return (data ?? []) as CalendarEvent[];
}

export async function upsertCalendarEvent(input: {
  id?: string;
  title: string;
  description?: string;
  starts_at: string;
  ends_at?: string | null;
  location?: string;
  project_id?: string | null;
  customer_id?: string | null;
  meeting_link_id?: string | null;
  all_day?: boolean;
  local_id?: number | null;
}): Promise<string> {
  const { supabase, user } = await requireUser();
  const row = {
    owner_uid: user.id,
    title: input.title.trim(),
    description: input.description?.trim() ?? "",
    starts_at: input.starts_at,
    ends_at: input.ends_at || null,
    location: input.location?.trim() ?? "",
    project_id: input.project_id || null,
    customer_id: input.customer_id || null,
    meeting_link_id: input.meeting_link_id || null,
    all_day: input.all_day ?? false,
    local_id: input.local_id ?? null,
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabase.from("calendar_events").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("calendar_events").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}
