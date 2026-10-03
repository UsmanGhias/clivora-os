import { createClient } from "@/lib/supabase/server";
import type { ProposalRow } from "@/lib/connect-proposals-shared";

export type { ProposalRow } from "@/lib/connect-proposals-shared";
export { proposalStatusLabel } from "@/lib/connect-proposals-shared";

export async function listFreelancerProposals(uid: string): Promise<ProposalRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("connect_proposals")
    .select("*")
    .eq("from_user_id", uid)
    .order("created_at", { ascending: false })
    .limit(80);
  if (!data?.length) return [];

  const needIds = [...new Set(data.map((p) => p.need_id).filter(Boolean))] as string[];
  const jobIds = [...new Set(data.map((p) => p.job_id).filter(Boolean))] as string[];
  const toIds = [...new Set(data.map((p) => p.to_user_id))];
  const [needs, jobs, profiles] = await Promise.all([
    needIds.length
      ? supabase
          .from("connect_need_posts")
          .select("id, title, budget_band, client_user_id")
          .in("id", needIds)
      : Promise.resolve({ data: [] }),
    jobIds.length
      ? supabase
          .from("connect_jobs")
          .select("id, title, company_name, salary_min, salary_max, currency")
          .in("id", jobIds)
      : Promise.resolve({ data: [] }),
    supabase.from("profiles").select("id, name").in("id", toIds),
  ]);
  const needMap = new Map((needs.data ?? []).map((n) => [n.id, n]));
  const jobMap = new Map((jobs.data ?? []).map((j) => [j.id, j]));
  const profileMap = new Map((profiles.data ?? []).map((p) => [p.id, p.name]));

  return data.map((p) => {
    const need = p.need_id ? needMap.get(p.need_id) : null;
    const job = p.job_id ? jobMap.get(p.job_id) : null;
    const jobBudget = job
      ? job.salary_min && job.salary_max
        ? `$${job.salary_min.toLocaleString()} - $${job.salary_max.toLocaleString()} USD`
        : job.salary_min
          ? `$${job.salary_min.toLocaleString()} USD`
          : "Market Rate"
      : null;

    return {
      ...p,
      need_title: need?.title ?? job?.title ?? p.client_name ? `Role at ${p.client_name}` : "Direct proposal",
      need_budget: need?.budget_band ?? jobBudget ?? null,
      to_name: job?.company_name ?? p.client_name ?? profileMap.get(p.to_user_id) ?? "Client",
    };
  }) as ProposalRow[];
}

export async function listClientProposals(uid: string): Promise<ProposalRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("connect_proposals")
    .select("*")
    .eq("to_user_id", uid)
    .order("created_at", { ascending: false })
    .limit(80);
  if (!data?.length) return [];

  const needIds = [...new Set(data.map((p) => p.need_id).filter(Boolean))] as string[];
  const fromIds = [...new Set(data.map((p) => p.from_user_id))];
  const [needs, profiles, connectProfiles] = await Promise.all([
    needIds.length
      ? supabase.from("connect_need_posts").select("id, title, budget_band").in("id", needIds)
      : Promise.resolve({ data: [] }),
    supabase.from("profiles").select("id, name").in("id", fromIds),
    supabase
      .from("connect_profiles")
      .select("user_id, headline, display_title, avg_rating, review_count, completion_rate, is_verified")
      .in("user_id", fromIds),
  ]);
  const needMap = new Map((needs.data ?? []).map((n) => [n.id, n]));
  const profileMap = new Map((profiles.data ?? []).map((p) => [p.id, p.name]));
  const cpMap = new Map((connectProfiles.data ?? []).map((c) => [c.user_id, c]));

  return data.map((p) => {
    const need = p.need_id ? needMap.get(p.need_id) : null;
    const cp = cpMap.get(p.from_user_id);
    return {
      ...p,
      need_title: need?.title ?? "Job proposal",
      need_budget: need?.budget_band ?? null,
      from_name: profileMap.get(p.from_user_id) ?? "Freelancer",
      from_headline: cp?.headline ?? cp?.display_title ?? null,
    };
  }) as ProposalRow[];
}
