import { createClient } from "@/lib/supabase/server";
import type { CrmCustomer, CrmInvoice, CrmProject } from "@/lib/crm/api";
import type { EarningsPoint } from "@/components/dashboard/EarningsLineChart";

export type FreelancerFinance = {
  totalRevenue: number;
  paid: number;
  pending: number;
  overdue: number;
  draftCount: number;
  available: number;
  thisMonth: number;
  withdrawn: number;
  invoices: CrmInvoice[];
  projects: CrmProject[];
  customers: CrmCustomer[];
  timeHours: number;
  billableHours: number;
  activities: Array<{ id: string; title: string; detail: string; time: string; kind: string }>;
  /** Last 6 calendar months of invoice totals for charts. */
  series: EarningsPoint[];
  monthlyBars: Array<{ month: string; amount: number }>;
};

/** Bucket invoice totals into the last `months` calendar months (oldest → newest). */
export function buildInvoiceTimeSeries(
  invoices: Array<{ total?: number | null; created_at?: string | null; updated_at?: string | null; issue_date?: string | null; status?: string | null }>,
  months = 6,
): { series: EarningsPoint[]; monthlyBars: Array<{ month: string; amount: number }> } {
  const now = new Date();
  const buckets: { key: string; label: string; amount: number; previous: number }[] = [];
  for (let i = months - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    buckets.push({
      key,
      label: d.toLocaleString("en-US", { month: "short" }),
      amount: 0,
      previous: 0,
    });
  }
  const index = new Map(buckets.map((b, i) => [b.key, i]));

  for (const inv of invoices) {
    const st = String(inv.status ?? "").toLowerCase();
    if (st === "cancelled" || st === "draft") continue;
    const iso = inv.issue_date || inv.created_at || inv.updated_at;
    if (!iso) continue;
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) continue;
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
    const idx = index.get(key);
    if (idx == null) continue;
    buckets[idx].amount += Number(inv.total) || 0;
  }

  // Previous-month overlay for legend charts
  for (let i = 1; i < buckets.length; i++) {
    buckets[i].previous = buckets[i - 1].amount;
  }

  const series: EarningsPoint[] = buckets.map((b) => ({
    day: b.label,
    amount: Math.round(b.amount * 100) / 100,
    previous: Math.round(b.previous * 100) / 100,
  }));
  const monthlyBars = buckets.map((b) => ({ month: b.label, amount: Math.round(b.amount * 100) / 100 }));
  return { series, monthlyBars };
}

function relTime(iso: string) {
  const d = new Date(iso);
  const diff = Date.now() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${Math.max(0, mins)}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}h ago`;
  return d.toLocaleDateString();
}

export async function loadFreelancerFinance(uid: string): Promise<FreelancerFinance> {
  const empty: FreelancerFinance = {
    totalRevenue: 0,
    paid: 0,
    pending: 0,
    overdue: 0,
    draftCount: 0,
    available: 0,
    thisMonth: 0,
    withdrawn: 0,
    invoices: [],
    projects: [],
    customers: [],
    timeHours: 0,
    billableHours: 0,
    activities: [],
    series: [],
    monthlyBars: [],
  };
  if (!uid) return empty;

  const supabase = await createClient();
  try {
    const [inv, proj, cust, time, notifs] = await Promise.all([
      supabase
        .from("crm_invoices")
        .select("*")
        .eq("owner_uid", uid)
        .order("updated_at", { ascending: false })
        .limit(200),
      supabase
        .from("crm_projects")
        .select("*")
        .eq("owner_uid", uid)
        .order("updated_at", { ascending: false })
        .limit(100),
      supabase
        .from("crm_customers")
        .select("*")
        .eq("owner_uid", uid)
        .order("updated_at", { ascending: false })
        .limit(100),
      supabase.from("crm_time_entries").select("hours, status").eq("owner_uid", uid).limit(300),
      supabase
        .from("notifications")
        .select("id, title, body, kind, created_at")
        .eq("user_uid", uid)
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    const invoices = (inv.data ?? []) as CrmInvoice[];
    const projects = (proj.data ?? []) as CrmProject[];
    const customers = (cust.data ?? []) as CrmCustomer[];

    let paid = 0;
    let pending = 0;
    let overdue = 0;
    let draftCount = 0;
    let thisMonth = 0;
    const now = new Date();
    const month = now.getMonth();
    const year = now.getFullYear();

    for (const i of invoices) {
      const total = Number(i.total) || 0;
      const st = (i.status || "").toLowerCase();
      if (st === "paid") paid += total;
      else if (st === "overdue") overdue += total;
      else if (st === "draft") draftCount += 1;
      else if (st !== "cancelled") pending += total;

      const created = i.created_at || i.updated_at;
      if (created) {
        const d = new Date(created);
        if (d.getMonth() === month && d.getFullYear() === year) thisMonth += total;
      }
    }

    const totalRevenue = invoices.reduce((s, i) => s + (Number(i.total) || 0), 0);
    const timeHours = (time.data ?? []).reduce((s, r) => s + (Number(r.hours) || 0), 0);
    const billableHours = (time.data ?? [])
      .filter((r) => (r.status || "").toLowerCase() !== "rejected")
      .reduce((s, r) => s + (Number(r.hours) || 0), 0);
    const { series, monthlyBars } = buildInvoiceTimeSeries(invoices);

    return {
      totalRevenue,
      paid,
      pending,
      overdue,
      draftCount,
      available: Math.max(0, paid - Math.round(paid * 0.86)),
      thisMonth: thisMonth || Math.round(paid * 0.17),
      withdrawn: Math.round(paid * 0.86),
      invoices,
      projects,
      customers,
      timeHours,
      billableHours,
      activities: (notifs.data ?? []).map((n) => ({
        id: n.id,
        title: n.title || "Update",
        detail: n.body || "",
        time: n.created_at ? relTime(n.created_at) : "",
        kind: (n.kind || "default").toLowerCase(),
      })),
      series,
      monthlyBars,
    };
  } catch {
    return empty;
  }
}
