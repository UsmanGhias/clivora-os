import { createClient } from "@/lib/supabase/client";

export type CrmCompany = {
  id: string;
  owner_uid: string;
  name: string;
  website?: string | null;
  industry?: string | null;
  notes?: string;
  updated_at?: string;
};

export type CrmTag = {
  id: string;
  owner_uid: string;
  name: string;
  color: string;
};

export type CrmGroup = {
  id: string;
  owner_uid: string;
  name: string;
  description?: string;
};

export type CrmActivity = {
  id: string;
  owner_uid: string;
  customer_id?: string | null;
  company_id?: string | null;
  activity_type: string;
  title: string;
  body: string;
  occurred_at: string;
};

async function requireUser() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  return { supabase, user };
}

export async function listCompanies(): Promise<CrmCompany[]> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("crm_companies")
    .select("*")
    .eq("owner_uid", user.id)
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as CrmCompany[];
}

export async function upsertCompany(input: {
  id?: string;
  name: string;
  website?: string;
  industry?: string;
  notes?: string;
}): Promise<string> {
  const { supabase, user } = await requireUser();
  const row = {
    owner_uid: user.id,
    name: input.name.trim(),
    website: input.website?.trim() || null,
    industry: input.industry?.trim() || null,
    notes: input.notes?.trim() ?? "",
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabase.from("crm_companies").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_companies").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function listTags(): Promise<CrmTag[]> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase.from("crm_tags").select("*").eq("owner_uid", user.id);
  if (error) throw error;
  return (data ?? []) as CrmTag[];
}

export async function upsertTag(input: { id?: string; name: string; color?: string }): Promise<string> {
  const { supabase, user } = await requireUser();
  const row = {
    owner_uid: user.id,
    name: input.name.trim(),
    color: input.color ?? "#64748b",
  };
  if (input.id) {
    const { error } = await supabase.from("crm_tags").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_tags").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function listGroups(): Promise<CrmGroup[]> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase.from("crm_groups").select("*").eq("owner_uid", user.id);
  if (error) throw error;
  return (data ?? []) as CrmGroup[];
}

export async function upsertGroup(input: {
  id?: string;
  name: string;
  description?: string;
}): Promise<string> {
  const { supabase, user } = await requireUser();
  const row = {
    owner_uid: user.id,
    name: input.name.trim(),
    description: input.description?.trim() ?? "",
  };
  if (input.id) {
    const { error } = await supabase.from("crm_groups").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_groups").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function listActivities(customerId?: string): Promise<CrmActivity[]> {
  const { supabase, user } = await requireUser();
  let q = supabase
    .from("crm_activities")
    .select("*")
    .eq("owner_uid", user.id)
    .order("occurred_at", { ascending: false })
    .limit(100);
  if (customerId) q = q.eq("customer_id", customerId);
  const { data, error } = await q;
  if (error) throw error;
  return (data ?? []) as CrmActivity[];
}

export async function addActivity(input: {
  customer_id?: string | null;
  company_id?: string | null;
  activity_type?: string;
  title: string;
  body?: string;
}): Promise<string> {
  const { supabase, user } = await requireUser();
  const { data, error } = await supabase
    .from("crm_activities")
    .insert({
      owner_uid: user.id,
      customer_id: input.customer_id || null,
      company_id: input.company_id || null,
      activity_type: input.activity_type ?? "note",
      title: input.title.trim(),
      body: input.body?.trim() ?? "",
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id as string;
}

export async function recomputeLeadScore(customerId: string): Promise<number> {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("crm_recompute_lead_score", {
    p_customer_id: customerId,
  });
  if (error) throw error;
  return Number(data ?? 0);
}

export async function findDuplicateCustomers(customerId: string) {
  const { supabase } = await requireUser();
  const { data, error } = await supabase.rpc("crm_find_duplicate_customers", {
    p_customer_id: customerId,
  });
  if (error) throw error;
  return (data ?? []) as Array<{
    id: string;
    contact_person: string;
    company: string;
    score: number;
  }>;
}

export async function setCustomerEnrichment(
  customerId: string,
  patch: {
    company_id?: string | null;
    next_action?: string | null;
    next_action_at?: string | null;
    duplicate_of?: string | null;
  },
) {
  const { supabase } = await requireUser();
  const { error } = await supabase
    .from("crm_customers")
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq("id", customerId);
  if (error) throw error;
}
