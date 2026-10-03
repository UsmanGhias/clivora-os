import { getProfile, isClientAccount } from "@/lib/profile";
import {
  listCustomersServer,
  listInvoicesServer,
  listProjectsServer,
} from "@/lib/crm/server";
import type { CrmInvoice } from "@/lib/crm/api";
import { canCreateInvoice, invoicesCreatedThisMonth } from "@/lib/plan-gates";
import { InvoicesCrmPanel } from "@/components/crm/CrmPanels";
import { createClient } from "@/lib/supabase/server";
import { AlertTriangle, Clock, FileText, Plus, Settings, TrendingUp } from "lucide-react";
import { DonutChart } from "@/components/dashboard/DonutChart";
import {
  FreelancerCard,
  FreelancerPageHeader,
  FreelancerStatCard,
  OutlineButton,
  PrimaryButton,
  money,
} from "@/components/freelancer/ui";

type InvoiceShareRow = {
  share_id: string;
  invoice_number?: string | null;
  total?: number | null;
  currency?: string | null;
  status?: string | null;
  freelancer_uid?: string | null;
  freelancer_email?: string | null;
  client_uid?: string | null;
  client_email?: string | null;
  public_token?: string | null;
  due_date?: string | null;
  updated_at?: string | null;
};

function formatMoney(currency?: string | null, total?: number | null) {
  return `${currency || "USD"} ${Number(total ?? 0).toFixed(2)}`;
}

function formatDate(value?: string | null) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

function statusLabel(status?: string | null) {
  return (status || "shared").replaceAll("_", " ");
}

export default async function InvoicesPage() {
  const profile = await getProfile();
  const client = isClientAccount(profile);
  const supabase = await createClient();
  const uid = profile?.id ?? "";

  if (client) {
    let rows: InvoiceShareRow[] = [];
    try {
      const { data, error } = await supabase
        .from("invoice_shares")
        .select(
          "share_id, invoice_number, total, currency, status, freelancer_uid, freelancer_email, client_uid, client_email, public_token, due_date, updated_at",
        )
        .or(`client_uid.eq.${uid},client_email.eq.${(profile?.email ?? '').toLowerCase()}`)
        .order("updated_at", { ascending: false })
        .limit(40);
      if (!error && data) rows = data;
    } catch {
      rows = [];
    }
    const freelancerIds = [...new Set(rows.map((r) => r.freelancer_uid).filter(Boolean))] as string[];
    const { data: freelancerProfiles } = freelancerIds.length
      ? await supabase.from("profiles").select("id, email, name").in("id", freelancerIds)
      : { data: [] };
    const freelancerMap = new Map((freelancerProfiles ?? []).map((p) => [p.id, p]));
    const clientEmail = (profile?.email ?? "").toLowerCase();

    const { ClientInvoicesPanel } = await import("@/components/client/ClientInvoicesPanel");
    return (
      <ClientInvoicesPanel
        rows={rows.map((r) => {
          const freelancer = r.freelancer_uid ? freelancerMap.get(r.freelancer_uid) : null;
          const freelancerEmail = r.freelancer_email || freelancer?.email || null;
          const safeFreelancerEmail =
            freelancerEmail && freelancerEmail.toLowerCase() !== clientEmail ? freelancerEmail : null;
          return {
            ...r,
            freelancer_email: safeFreelancerEmail,
            freelancer_name: freelancer?.name ?? null,
            issue_date: r.updated_at,
          };
        })}
      />
    );
  }

  let invoices: CrmInvoice[] = [];
  let customers: Awaited<ReturnType<typeof listCustomersServer>> = [];
  let projects: Awaited<ReturnType<typeof listProjectsServer>> = [];
  try {
    invoices = await listInvoicesServer();
  } catch {
    invoices = [];
  }
  try {
    customers = await listCustomersServer();
  } catch {
    customers = [];
  }
  try {
    projects = await listProjectsServer();
  } catch {
    projects = [];
  }

  // Approximate month count from updated_at when created_at not selected
  const monthCount = invoicesCreatedThisMonth(
    invoices.map((i) => ({ created_at: i.created_at ?? i.updated_at })),
  );
  const gate = canCreateInvoice(profile, monthCount);

  const totalRevenue = invoices.reduce((s, i) => s + (Number(i.total) || 0), 0);
  const paid = invoices
    .filter((i) => (i.status || "").toLowerCase() === "paid")
    .reduce((s, i) => s + (Number(i.total) || 0), 0);
  const pending = invoices
    .filter((i) => {
      const st = (i.status || "").toLowerCase();
      return st === "sent" || st === "pending" || st === "unpaid";
    })
    .reduce((s, i) => s + (Number(i.total) || 0), 0);
  const overdue = invoices
    .filter((i) => (i.status || "").toLowerCase() === "overdue")
    .reduce((s, i) => s + (Number(i.total) || 0), 0);
  const drafts = invoices.filter((i) => (i.status || "").toLowerCase() === "draft").length;
  const pct = (n: number) => (totalRevenue > 0 ? Math.round((n / totalRevenue) * 100) : 0);

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Invoices"
        subtitle="Create, send, and track invoices with branded totals and collection status."
        actions={
          <>
            <PrimaryButton href="#create">
              <Plus className="h-4 w-4" />
              Create Invoice
            </PrimaryButton>
            <OutlineButton href="/app/settings">
              <Settings className="h-4 w-4" />
              Invoice Settings
            </OutlineButton>
          </>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <FreelancerStatCard
          label="Total Revenue"
          value={money(totalRevenue)}
          trend={undefined}
          icon={TrendingUp}
        />
        <FreelancerStatCard
          label="Paid"
          value={money(paid)}
          sub={`${pct(paid)}% of total`}
          icon={FileText}
          iconTone="bg-emerald-100 text-emerald-700"
        />
        <FreelancerStatCard
          label="Pending"
          value={money(pending)}
          sub={`${pct(pending)}% of total`}
          icon={Clock}
          iconTone="bg-amber-100 text-amber-800"
        />
        <FreelancerStatCard
          label="Overdue"
          value={money(overdue)}
          sub={`${pct(overdue)}% of total`}
          icon={AlertTriangle}
          iconTone="bg-red-100 text-red-700"
        />
        <FreelancerStatCard
          label="Draft"
          value={`${drafts} Invoices`}
          icon={FileText}
          iconTone="bg-sky-100 text-sky-800"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[1fr_280px]">
        <div id="create" className="space-y-4">
          <InvoicesCrmPanel
            initial={invoices}
            customers={customers}
            projects={projects}
            canCreate={gate.ok}
            gateReason={!gate.ok ? gate.reason : undefined}
            upgradeHref={!gate.ok ? gate.upgradeHref : undefined}
          />
        </div>
        <aside className="space-y-4">
          <DonutChart
            title="Invoice analytics"
            slices={[
              { name: "Paid", value: Math.max(paid, 1), color: "#10B981" },
              { name: "Pending", value: Math.max(pending, 1), color: "#F59E0B" },
              { name: "Overdue", value: Math.max(overdue, 1), color: "#DC2626" },
            ]}
            centerValue={money(totalRevenue, 0)}
            centerLabel="Total"
          />
          <FreelancerCard title="Payment methods">
            <p className="text-sm text-text-secondary">
              Clients pay you directly. Add your bank, card or wallet details to invoices; CLIVORA records
              payments against invoices and milestones but never holds funds.
            </p>
            <ul className="mt-3 space-y-2 text-sm">
              {[
                { name: "Bank transfer", status: "Direct" },
                { name: "Card or wallet link", status: "Direct" },
                { name: "Cash or other", status: "Recorded manually" },
              ].map((m) => (
                <li
                  key={m.name}
                  className="flex items-center justify-between rounded-xl border border-border px-3 py-2.5"
                >
                  <span className="font-semibold text-navy">{m.name}</span>
                  <span className="text-xs font-bold text-slate-500">{m.status}</span>
                </li>
              ))}
            </ul>
            <a
              href="/app/account"
              className="mt-3 inline-block text-sm font-semibold text-primary hover:underline"
            >
              Set bank and payout details
            </a>
          </FreelancerCard>
          <FreelancerCard title="Quick actions">
            <ul className="space-y-2 text-sm font-semibold text-navy">
              <li>
                <a
                  href="#create"
                  className="flex justify-between rounded-xl border border-border px-3 py-2.5 hover:border-primary/40"
                >
                  Create Invoice <span>→</span>
                </a>
              </li>
              <li>
                <a
                  href="/app/clients"
                  className="flex justify-between rounded-xl border border-border px-3 py-2.5 hover:border-primary/40"
                >
                  Manage clients <span>→</span>
                </a>
              </li>
              <li>
                <a
                  href="/app/projects"
                  className="flex justify-between rounded-xl border border-border px-3 py-2.5 hover:border-primary/40"
                >
                  Link to projects <span>→</span>
                </a>
              </li>
              <li>
                <a
                  href="/app/earnings"
                  className="flex justify-between rounded-xl border border-border px-3 py-2.5 hover:border-primary/40"
                >
                  View earnings <span>→</span>
                </a>
              </li>
              <li>
                <a
                  href="/app/account"
                  className="flex justify-between rounded-xl border border-border px-3 py-2.5 hover:border-primary/40"
                >
                  Payout settings <span>→</span>
                </a>
              </li>
            </ul>
          </FreelancerCard>
        </aside>
      </div>
    </div>
  );
}
