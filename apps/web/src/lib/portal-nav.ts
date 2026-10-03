import { createClient } from "@/lib/supabase/server";

export type PortalNavCounts = {
  proposals: number;
  messages: number;
  notifications: number;
  projects: number;
};

export async function getPortalNavCounts(
  uid: string,
  isClient: boolean,
  email?: string | null,
): Promise<PortalNavCounts> {
  const supabase = await createClient();
  const counts: PortalNavCounts = { proposals: 0, messages: 0, notifications: 0, projects: 0 };
  if (!uid) return counts;

  try {
    const [proposals, notifications, messages, projects] = await Promise.all([
      supabase
        .from("connect_proposals")
        .select("id", { count: "exact", head: true })
        .eq(isClient ? "to_user_id" : "from_user_id", uid)
        .in("status", isClient ? ["pending", "shortlisted", "viewed"] : ["pending", "viewed", "shortlisted"]),
      supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_uid", uid)
        .eq("is_read", false),
      supabase.rpc('unread_message_count'),
      supabase
        .from("project_shares")
        .select("share_id", { count: "exact", head: true })
        .or(
          isClient && email
            ? `client_uid.eq.${uid},client_email.eq.${email.trim().toLowerCase()}`
            : `${isClient ? "client_uid" : "freelancer_uid"}.eq.${uid}`,
        ),
    ]);
    counts.proposals = proposals.count ?? 0;
    counts.notifications = notifications.count ?? 0;
    counts.messages =
      typeof messages.data === "number"
        ? messages.data
        : Number(messages.data ?? 0) || 0;
    counts.projects = projects.count ?? 0;
  } catch {
    /* ignore */
  }

  return counts;
}

export function portalGreeting() {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}
