import Link from "next/link";
import { getProfile, isClientAccount } from "@/lib/profile";
import { listCustomersServer } from "@/lib/crm/server";
import { canCreateCustomer } from "@/lib/plan-gates";
import { CustomersCrmPanel } from "@/components/crm/CrmPanels";
import { CrmEnrichmentPanel } from "@/components/crm/CrmEnrichmentPanel";
import { createClient } from "@/lib/supabase/server";

type SharedWorkRow = {
  share_id: string;
  freelancer_email?: string | null;
  project_name?: string | null;
  status?: string | null;
  updated_at?: string | null;
};

function formatDate(value?: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export default async function ClientsPage() {
  const profile = await getProfile();
  const client = isClientAccount(profile);
  let customers: Awaited<ReturnType<typeof listCustomersServer>> = [];
  try {
    customers = await listCustomersServer();
  } catch {
    customers = [];
  }

  if (client) {
    const supabase = await createClient();
    let sharedWork: SharedWorkRow[] = [];
    try {
      const clientFilter = profile?.email
        ? `client_uid.eq.${profile.id},client_email.eq.${(profile.email ?? '').toLowerCase()}`
        : `client_uid.eq.${profile?.id ?? ""}`;
      const { data } = await supabase
        .from("project_shares")
        .select("share_id, freelancer_email, project_name, status, updated_at")
        .or(clientFilter)
        .order("updated_at", { ascending: false })
        .limit(20);
      if (data) sharedWork = data;
    } catch {
      sharedWork = [];
    }
    const freelancers = Array.from(
      new Set(sharedWork.map((r) => r.freelancer_email).filter(Boolean) as string[]),
    );

    return (
      <div className="space-y-4">
        <div>
          <h1 className="text-2xl font-extrabold">Clients</h1>
          <p className="text-sm text-text-secondary">
            Freelancers connected to your client workspace and the work they have shared.
          </p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <section className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
            <p className="text-xs font-bold uppercase tracking-wide text-client-accent">
              Connected freelancers
            </p>
            <p className="mt-1 text-3xl font-extrabold text-navy">{freelancers.length}</p>
            <p className="mt-2 text-sm text-text-secondary">
              {freelancers.length > 0
                ? freelancers.slice(0, 3).join(", ")
                : "Accept a Connect match or receive shared work to build this list."}
            </p>
          </section>
          <section className="rounded-2xl border border-border bg-client-surface p-5 shadow-sm">
            <p className="text-xs font-bold uppercase tracking-wide text-client-accent">Shared work</p>
            <p className="mt-1 text-3xl font-extrabold text-navy">{sharedWork.length}</p>
            <p className="mt-2 text-sm text-text-secondary">
              Projects, invoices, and updates from freelancers stay available in your web portal.
            </p>
            <Link
              href="/connect"
              className="mt-4 inline-flex rounded-xl bg-client-accent px-4 py-2 text-sm font-bold text-white"
            >
              Find freelancers on Connect
            </Link>
          </section>
        </div>
        {sharedWork.length > 0 ? (
          <ul className="space-y-2">
            {sharedWork.map((row) => (
              <li
                key={row.share_id}
                className="flex items-center justify-between gap-3 rounded-xl border border-border bg-surface px-4 py-3"
              >
                <div>
                  <p className="font-semibold text-navy">{row.project_name || "Shared project"}</p>
                  <p className="text-sm text-text-secondary">
                    {row.freelancer_email || "Freelancer"} · {(row.status || "active").replaceAll("_", " ")}
                  </p>
                </div>
                <span className="text-xs text-text-muted">{formatDate(row.updated_at)}</span>
              </li>
            ))}
          </ul>
        ) : (
          <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
            <p className="font-semibold text-navy">No freelancer work shared yet</p>
            <p className="mt-2 text-sm text-text-secondary">
              Once a freelancer shares a project or invoice, it will appear here.
            </p>
          </div>
        )}
      </div>
    );
  }

  const gate = canCreateCustomer(profile, customers.length);
  const { loadFreelancerFinance } = await import("@/lib/freelancer-finance");
  const fin = profile?.id
    ? await loadFreelancerFinance(profile.id)
    : { totalRevenue: 0, projects: [], invoices: [] };
  const activeClients = customers.filter((c) => (c.status || "active").toLowerCase() === "active").length;

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h1 className="font-display text-2xl font-extrabold text-navy sm:text-3xl">
            My Clients{" "}
            <span className="ml-2 rounded-full bg-primary/10 px-2.5 py-1 text-xs font-bold text-primary">
              {customers.length} Total
            </span>
          </h1>
          <p className="mt-1 text-sm text-text-secondary">
            Manage relationships, revenue, and follow-ups across your CRM clients.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link
            href="#clients-crm"
            className="inline-flex min-h-11 items-center rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white"
          >
            + Add Client
          </Link>
          <Link
            href="#clients-crm"
            className="inline-flex min-h-11 items-center rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-semibold text-navy"
          >
            Import Clients
          </Link>
        </div>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {[
          { label: "Total Clients", value: String(customers.length), sub: "In your CRM", tone: "bg-primary/10 text-primary" },
          { label: "Active Clients", value: String(activeClients || customers.length), sub: customers.length ? `${Math.round((activeClients / Math.max(1, customers.length)) * 100)}% of total` : "No clients yet", tone: "bg-violet-100 text-violet-700" },
          { label: "Total Revenue", value: `$${fin.totalRevenue.toLocaleString()}`, sub: "From paid invoices", tone: "bg-emerald-100 text-emerald-700" },
          { label: "Projects", value: String(fin.projects.length), sub: "In Progress", tone: "bg-sky-100 text-sky-800" },
          { label: "Total Invoices", value: String(fin.invoices.length), sub: "This Year", tone: "bg-red-100 text-red-700" },
        ].map((s) => (
          <div key={s.label} className="rounded-2xl border border-border bg-surface p-4 shadow-sm">
            <span className={`inline-flex h-9 w-9 items-center justify-center rounded-xl text-xs font-bold ${s.tone}`}>
              ●
            </span>
            <p className="mt-3 text-xs font-semibold uppercase text-text-muted">{s.label}</p>
            <p className="mt-1 font-display text-2xl font-extrabold text-navy">{s.value}</p>
            <p className="mt-1 text-xs text-text-secondary">{s.sub}</p>
          </div>
        ))}
      </div>

      <div id="clients-crm" className="grid gap-4 xl:grid-cols-[1fr_280px]">
        <CustomersCrmPanel
          initial={customers}
          canCreate={gate.ok}
          gateReason={!gate.ok ? gate.reason : undefined}
          upgradeHref={!gate.ok ? gate.upgradeHref : undefined}
        />
        <aside className="space-y-4">
          <div className="overflow-hidden rounded-2xl border border-border bg-surface shadow-sm">
            <div className="bg-primary/10 p-5">
              <p className="text-xs font-bold uppercase text-primary">Top client</p>
              <p className="mt-2 font-display text-lg font-bold text-navy">
                {customers[0]?.company || customers[0]?.contact_person || "Add your first client"}
              </p>
              <p className="mt-1 text-sm font-semibold text-navy">
                ${fin.totalRevenue.toLocaleString()} Total Revenue
              </p>
            </div>
          </div>
          <div className="rounded-2xl border border-border bg-surface p-5 shadow-sm">
            <p className="font-display font-bold text-navy">Client insights</p>
            <ul className="mt-3 space-y-2 text-sm text-text-secondary">
              <li>75% Repeat Clients</li>
              <li>4.8 Avg. Rating</li>
              <li>2.4 yrs Avg. Retention</li>
            </ul>
          </div>
          <div className="rounded-2xl bg-navy p-5 text-white">
            <p className="font-display font-bold">Upgrade to Pro Plus</p>
            <p className="mt-1 text-sm text-white/70">Unlock unlimited clients and CRM depth.</p>
            <Link
              href="/edition"
              className="mt-4 inline-flex rounded-xl bg-primary px-4 py-2 text-sm font-bold text-white"
            >
              Upgrade Now
            </Link>
          </div>
        </aside>
      </div>
      <CrmEnrichmentPanel customerId={customers[0]?.id ?? null} />
    </div>
  );
}
