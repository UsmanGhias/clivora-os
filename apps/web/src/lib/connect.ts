import { createClient } from "@/lib/supabase/server";
import { cleanText } from "@/lib/clean-text";
import type { ConnectNeed, ConnectProfile, ConnectRequestRow } from "@/lib/connect-types";

export type { ConnectNeed, ConnectProfile, ConnectRequestRow } from "@/lib/connect-types";
export { skillsList } from "@/lib/connect-types";

export async function listPublicConnectProfiles(search?: string) {
  const supabase = await createClient();
  let q = supabase
    .from("connect_profiles")
    .select(
      "id, user_id, display_title, headline, bio, skills, rate_band, availability, location_label, is_listed, is_verified, moderation_status, account_type, created_at, updated_at, avg_rating, review_count, completion_rate, reputation_score, profile_completeness",
    )
    .eq("is_listed", true)
    .eq("moderation_status", "approved")
    .order("reputation_score", { ascending: false })
    .limit(200);
  if (search?.trim()) {
    const s = `%${search.trim()}%`;
    q = q.or(`display_title.ilike.${s},headline.ilike.${s},bio.ilike.${s},location_label.ilike.${s}`);
  }
  const { data } = await q;
  const rows = (data ?? []) as ConnectProfile[];
  const userIds = [...new Set(rows.map((r) => r.user_id).filter(Boolean))];
  if (userIds.length === 0) return rows;

  const { data: avatars } = await supabase
    .from("profiles")
    .select("id, avatar_url")
    .in("id", userIds);
  const byId = new Map(
    (avatars ?? []).map((a) => [String((a as { id: string }).id), (a as { avatar_url?: string | null }).avatar_url ?? null]),
  );
  return rows.map((r) => ({
    ...r,
    avatar_url: byId.get(r.user_id) ?? null,
  }));
}

export async function listPublicConnectNeeds(search?: string) {
  const supabase = await createClient();
  const [needsRes, jobsRes] = await Promise.all([
    supabase
      .from("connect_need_posts")
      .select(
        "id, client_user_id, title, summary, skills, budget_band, is_open, moderation_status, created_at",
      )
      .eq("is_open", true)
      .eq("moderation_status", "approved")
      .order("created_at", { ascending: false })
      .limit(100),
    supabase
      .from("connect_jobs")
      .select(
        "id, title, company_name, company_email, description, category, tags, salary_min, salary_max, currency, location, job_type, seo_slug, posted_by, created_at",
      )
      .eq("is_public", true)
      .eq("status", "published")
      .order("created_at", { ascending: false })
      .limit(500),
  ]);

  const rawNeeds: ConnectNeed[] = ((needsRes.data ?? []) as ConnectNeed[]).map((n) => ({
    ...n,
    is_direct_client: true,
  }));

  const mappedJobs: ConnectNeed[] = (jobsRes.data ?? []).map((j) => {
    const budget =
      j.salary_min && j.salary_max
        ? `$${j.salary_min.toLocaleString()} - $${j.salary_max.toLocaleString()} USD`
        : j.salary_min
          ? `$${j.salary_min.toLocaleString()} USD`
          : "Market Rate ($ USD)";

    return {
      id: j.id,
      client_user_id: j.posted_by || "00000000-0000-0000-0000-000000000000",
      title: cleanText(j.title) || "Remote Role",
      summary: cleanText(j.description) || "",
      skills: j.tags && j.tags.length > 0 ? j.tags.map((t: string) => cleanText(t)) : [j.category || "General"],
      budget_band: budget,
      is_open: true,
      moderation_status: "approved",
      created_at: j.created_at,
      company_name: cleanText(j.company_name),
      company_email: j.company_email,
      job_id: j.id,
      seo_slug: j.seo_slug,
      location: j.location,
      is_direct_client: !!j.posted_by,
    };
  });

  const combined = [...rawNeeds, ...mappedJobs].sort((a, b) => {
    const aDirect = a.is_direct_client ? 1 : 0;
    const bDirect = b.is_direct_client ? 1 : 0;
    if (aDirect !== bDirect) return bDirect - aDirect;
    return String(b.created_at || "").localeCompare(String(a.created_at || ""));
  });

  if (search?.trim()) {
    const s = search.trim().toLowerCase();
    return combined.filter(
      (item) =>
        (item.title || "").toLowerCase().includes(s) ||
        (item.summary || "").toLowerCase().includes(s) ||
        (item.company_name || "").toLowerCase().includes(s),
    );
  }
  return combined;
}

export async function listMyConnectRequests() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [] as ConnectRequestRow[];
  const { data } = await supabase
    .from("connect_request_details")
    .select("*")
    .or(`from_user_id.eq.${user.id},to_user_id.eq.${user.id}`)
    .order("created_at", { ascending: false })
    .limit(200);
  return (data ?? []) as ConnectRequestRow[];
}

export type ConnectReview = {
  id: string;
  request_id: string | null;
  from_user_id: string;
  to_user_id: string;
  rating: number;
  body: string | null;
  created_at: string;
};

export type ConnectProposal = {
  id: string;
  need_id: string | null;
  from_user_id: string;
  to_user_id: string;
  amount: number | null;
  currency: string | null;
  timeline_days: number | null;
  message: string | null;
  status: string;
  created_at: string;
};

export type ConnectMilestone = {
  id: string;
  engagement_request_id: string;
  client_user_id: string;
  freelancer_user_id: string;
  title: string;
  amount: number | null;
  currency: string | null;
  status: string;
  funded_at?: string | null;
  released_at?: string | null;
  created_at: string;
};

export async function listReviewsForRequest(requestId: string): Promise<ConnectReview[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("connect_reviews")
    .select("*")
    .eq("request_id", requestId)
    .order("created_at", { ascending: false });
  return (data ?? []) as ConnectReview[];
}

export async function listProposalsForNeed(needId: string): Promise<ConnectProposal[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("connect_proposals")
    .select("*")
    .eq("need_id", needId)
    .order("created_at", { ascending: false });
  return (data ?? []) as ConnectProposal[];
}

export async function listMilestonesForRequest(requestId: string): Promise<ConnectMilestone[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("connect_milestones")
    .select("*")
    .eq("engagement_request_id", requestId)
    .order("created_at", { ascending: true });
  return (data ?? []) as ConnectMilestone[];
}
