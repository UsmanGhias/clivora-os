import { createClient } from "@/lib/supabase/client";
import { invoiceMinorFields } from "@/lib/money";

export type CrmCustomer = {
  id: string;
  owner_uid: string;
  local_id: number | null;
  contact_person: string;
  company: string;
  emails: string[] | unknown;
  phones: string[] | unknown;
  whatsapp: string;
  address: string;
  city: string;
  postal_code: string;
  country: string;
  notes: string;
  status: string;
  updated_at: string;
  custom_fields?: Record<string, string> | null;
  company_id?: string | null;
  lead_score?: number | null;
  next_action?: string | null;
  next_action_at?: string | null;
  duplicate_of?: string | null;
};

export type CrmProject = {
  id: string;
  owner_uid: string;
  local_id: number | null;
  customer_id: string | null;
  name: string;
  description: string;
  budget: number;
  currency: string;
  status: string;
  priority: string;
  pricing_type?: string | null;
  deadline: string | null;
  updated_at: string;
};

export type CrmInvoice = {
  id: string;
  owner_uid: string;
  local_id: number | null;
  customer_id: string | null;
  project_id: string | null;
  invoice_number: string;
  status: string;
  total: number;
  currency: string;
  line_items: unknown;
  due_date: string | null;
  created_at?: string;
  updated_at: string;
};

export function asStringList(v: unknown): string[] {
  if (Array.isArray(v)) return v.map(String);
  return [];
}

export async function upsertCustomerClient(input: {
  id?: string;
  contact_person: string;
  company?: string;
  emails?: string[];
  phones?: string[];
  whatsapp?: string;
  address?: string;
  city?: string;
  country?: string;
  notes?: string;
  status?: string;
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  const row = {
    owner_uid: user.id,
    contact_person: input.contact_person.trim(),
    company: input.company?.trim() ?? "",
    emails: input.emails ?? [],
    phones: input.phones ?? [],
    whatsapp: input.whatsapp?.trim() ?? "",
    address: input.address?.trim() ?? "",
    city: input.city?.trim() ?? "",
    country: input.country?.trim() ?? "",
    notes: input.notes?.trim() ?? "",
    status: input.status ?? "active",
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabase.from("crm_customers").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_customers").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function upsertProjectClient(input: {
  id?: string;
  name: string;
  customer_id?: string | null;
  description?: string;
  budget?: number;
  currency?: string;
  status?: string;
  priority?: string;
  pricing_type?: string | null;
  deadline?: string | null;
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  const row = {
    owner_uid: user.id,
    name: input.name.trim(),
    customer_id: input.customer_id || null,
    description: input.description?.trim() ?? "",
    budget: input.budget ?? 0,
    currency: input.currency ?? "USD",
    status: input.status ?? "not_started",
    priority: input.priority ?? "medium",
    pricing_type: input.pricing_type ?? "fixed",
    deadline: input.deadline || null,
    updated_at: new Date().toISOString(),
  };
  if (input.id) {
    const { error } = await supabase.from("crm_projects").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_projects").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function upsertInvoiceClient(input: {
  id?: string;
  invoice_number: string;
  customer_id?: string | null;
  project_id?: string | null;
  status?: string;
  total?: number;
  currency?: string;
  line_items?: unknown[];
  due_date?: string | null;
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Sign in required");
  const total = input.total ?? 0;
  const minors = invoiceMinorFields({ subtotal: total, total, amountPaid: 0 });
  const row = {
    owner_uid: user.id,
    invoice_number: input.invoice_number.trim(),
    customer_id: input.customer_id || null,
    project_id: input.project_id || null,
    status: input.status ?? "draft",
    total,
    subtotal: total,
    currency: input.currency ?? "USD",
    line_items: input.line_items ?? [],
    due_date: input.due_date || null,
    updated_at: new Date().toISOString(),
    ...minors,
  };
  if (input.id) {
    const { error } = await supabase.from("crm_invoices").update(row).eq("id", input.id);
    if (error) throw error;
    return input.id;
  }
  const { data, error } = await supabase.from("crm_invoices").insert(row).select("id").single();
  if (error) throw error;
  return data.id as string;
}

export async function deleteCrmRow(table: "crm_customers" | "crm_projects" | "crm_invoices", id: string) {
  const supabase = createClient();
  const { error } = await supabase.from(table).delete().eq("id", id);
  if (error) throw error;
}
