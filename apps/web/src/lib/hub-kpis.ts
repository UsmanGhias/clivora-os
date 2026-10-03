import { createClient } from "@/lib/supabase/server";

export type HubKpis = {
  overdueInvoices: number;
  pendingConnect: number;
  profileCompleteness: number | null;
};

export async function getHubKpis(userId: string): Promise<HubKpis> {
  const supabase = await createClient();
  const now = new Date().toISOString();

  const [inv, reqs, profile] = await Promise.all([
    supabase
      .from("crm_invoices")
      .select("id", { count: "exact", head: true })
      .eq("owner_uid", userId)
      .in("status", ["sent", "overdue", "partial", "unpaid"])
      .lte("due_date", now),
    supabase
      .from("connect_requests")
      .select("id", { count: "exact", head: true })
      .eq("to_user_id", userId)
      .eq("status", "pending"),
    supabase
      .from("connect_profiles")
      .select("profile_completeness")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  return {
    overdueInvoices: inv.count ?? 0,
    pendingConnect: reqs.count ?? 0,
    profileCompleteness:
      profile.data?.profile_completeness != null
        ? Number(profile.data.profile_completeness)
        : null,
  };
}
