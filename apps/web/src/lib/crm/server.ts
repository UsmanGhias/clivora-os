import { createClient as createServerClient } from "@/lib/supabase/server";
import type { CrmCustomer, CrmInvoice, CrmProject } from "@/lib/crm/api";

export async function listCustomersServer() {
  const supabase = await createServerClient();
  const { data, error } = await supabase
    .from("crm_customers")
    .select("*")
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as CrmCustomer[];
}

export async function listProjectsServer() {
  const supabase = await createServerClient();
  const { data, error } = await supabase
    .from("crm_projects")
    .select("*")
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as CrmProject[];
}

export async function listInvoicesServer() {
  const supabase = await createServerClient();
  const { data, error } = await supabase
    .from("crm_invoices")
    .select("*")
    .order("updated_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as CrmInvoice[];
}
