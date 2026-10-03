import { createClient } from "@/lib/supabase/server";
import { getProfile, isClientAccount } from "@/lib/profile";
import { FreelancerDashboard } from "@/components/dashboard/FreelancerDashboard";
import { ClientDashboard } from "@/components/dashboard/ClientDashboard";
import type { ConnectCreditSummary } from "@/lib/connect-credits";
import type { DashboardProject } from "@/components/dashboard/ProjectListCard";
import type { PersonRow } from "@/components/dashboard/PeopleListCard";
import { buildInvoiceTimeSeries } from "@/lib/freelancer-finance";
import type { EarningsPoint } from "@/components/dashboard/EarningsLineChart";

type HomeSummary = {
  open_jobs?: number;
  pending_proposals?: number;
  accepted_proposals?: number;
  milestones_needing_action?: number;
  active_milestones?: number;
  unread_messages?: number;
};

function relTime(iso: string) {
  const d = new Date(iso);
  const diff = Date.now() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${Math.max(0, mins)}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 48) return `${hrs}h ago`;
  return d.toLocaleDateString();
}

function money(n: number) {
  return `$${n.toLocaleString(undefined, { maximumFractionDigits: 0 })}`;
}

export default async function AppHomePage() {
  const profile = await getProfile();
  if (!profile) return null;

  const client = isClientAccount(profile);
  const supabase = await createClient();
  const uid = profile.id;
  const clientEmail = profile.email?.trim().toLowerCase();
  const clientProjectFilter = clientEmail
    ? `client_uid.eq.${uid},client_email.eq.${clientEmail}`
    : `client_uid.eq.${uid}`;
  const clientInvoiceFilter = clientEmail
    ? `client_uid.eq.${uid},client_email.eq.${clientEmail}`
    : `client_uid.eq.${uid}`;

  let home: HomeSummary = {};
  let credits: ConnectCreditSummary | null = null;
  let invoiceTotal = 0;
  let paidTotal = 0;
  let outstandingTotal = 0;
  let invoiceSeries: EarningsPoint[] = [];
  let profileCompleteness = 0;
  let successScore = 0;
  let projectCount = 0;
  let activities: Array<{ id: string; title: string; detail: string; time: string; kind: string }> =
    [];
  let projects: DashboardProject[] = [];
  let clients: PersonRow[] = [];
  let freelancers: PersonRow[] = [];
  let proposalSlices: Array<{ name: string; value: number; color: string }> = [];
  let opportunities: Array<{ id: string; title: string; budget: string; type: string }> = [];
  let tasksDone = 0;
  let timeMinutes = 0;

  try {
    const [
      summaryRes,
      creditRes,
      notifs,
      connectProfile,
      crmInvoices,
      crmProjects,
      crmCustomers,
      sharedProjects,
      proposalRows,
      needs,
      talent,
      taskRows,
      timeRows,
    ] = await Promise.all([
      supabase.rpc(client ? "client_home_summary" : "freelancer_home_summary"),
      supabase.rpc("connect_credit_summary"),
      supabase
        .from("notifications")
        .select("id, title, body, kind, created_at")
        .eq("user_uid", uid)
        .order("created_at", { ascending: false })
        .limit(8),
      client
        ? Promise.resolve({ data: null })
        : supabase
            .from("connect_profiles")
            .select("profile_completeness, completion_rate, avg_rating")
            .eq("user_id", uid)
            .maybeSingle(),
      client
        ? supabase
            .from("invoice_shares")
            .select("share_id, total, status, currency, updated_at, due_date, client_paid_at")
            .or(clientInvoiceFilter)
            .limit(200)
        : supabase
            .from("crm_invoices")
            .select("id, total, status, customer_id, created_at, updated_at, issue_date")
            .eq("owner_uid", uid)
            .limit(500),
      client
        ? Promise.resolve({ data: [] as Array<Record<string, unknown>> })
        : supabase
            .from("crm_projects")
            .select("id, name, status, budget, customer_id, updated_at")
            .eq("owner_uid", uid)
            .order("updated_at", { ascending: false })
            .limit(8),
      client
        ? Promise.resolve({ data: [] as Array<Record<string, unknown>> })
        : supabase
            .from("crm_customers")
            .select("id, contact_person, company, status")
            .eq("owner_uid", uid)
            .order("updated_at", { ascending: false })
            .limit(8),
      supabase
        .from("project_shares")
        .select(
          "share_id, project_name, status, budget, freelancer_email, client_email, updated_at",
        )
        .or(client ? clientProjectFilter : `freelancer_uid.eq.${uid}`)
        .order("updated_at", { ascending: false })
        .limit(8),
      supabase
        .from("connect_proposals")
        .select("id, status, amount")
        .eq(client ? "to_user_id" : "from_user_id", uid)
        .limit(80),
      client
        ? Promise.resolve({ data: [] as Array<Record<string, unknown>> })
        : supabase
            .from("connect_need_posts")
            .select("id, title, budget_band, skills, created_at")
            .eq("is_open", true)
            .order("created_at", { ascending: false })
            .limit(6),
      client
        ? supabase
            .from("connect_profiles")
            .select(
              "id, user_id, display_title, headline, rate_band, avg_rating, review_count, is_listed",
            )
            .eq("is_listed", true)
            .order("reputation_score", { ascending: false })
            .limit(5)
        : Promise.resolve({ data: [] as Array<Record<string, unknown>> }),
      supabase
        .from("client_tasks")
        .select("id, title, status")
        .eq(client ? "client_uid" : "freelancer_uid", uid)
        .limit(40),
      client
        ? Promise.resolve({ data: [] as Array<Record<string, unknown>> })
        : supabase
            .from("crm_time_entries")
            .select("id, hours")
            .eq("owner_uid", uid)
            .limit(100),
    ]);

    if (summaryRes.data && typeof summaryRes.data === "object") {
      home = summaryRes.data as HomeSummary;
    }
    if (Array.isArray(creditRes.data) && creditRes.data[0]) {
      credits = creditRes.data[0] as ConnectCreditSummary;
    }
    if (notifs.data) {
      activities = notifs.data.map((n) => ({
        id: n.id,
        title: n.title || "Update",
        detail: n.body || "",
        time: n.created_at ? relTime(n.created_at) : "",
        kind: (n.kind || "default").toLowerCase(),
      }));
    }
    if (connectProfile.data) {
      profileCompleteness = Math.min(
        100,
        Math.round(Number(connectProfile.data.profile_completeness ?? 0)),
      );
      const rate = Number(connectProfile.data.completion_rate ?? 0);
      const rating = Number(connectProfile.data.avg_rating ?? 0);
      successScore = Math.min(100, Math.round(rate || (rating > 0 ? rating * 20 : 0)));
    }

    if (!client && crmInvoices.data) {
      const rows = crmInvoices.data as Array<{
        total?: number;
        status?: string;
        customer_id?: string;
        created_at?: string;
        updated_at?: string;
        issue_date?: string;
      }>;
      invoiceTotal = rows.reduce((s, i) => s + (Number(i.total) || 0), 0);
      paidTotal = rows
        .filter((i) => (i.status || "").toLowerCase() === "paid")
        .reduce((s, i) => s + (Number(i.total) || 0), 0);
      outstandingTotal = rows
        .filter((i) => {
          const st = (i.status || "").toLowerCase();
          return st !== "paid" && st !== "cancelled";
        })
        .reduce((s, i) => s + (Number(i.total) || 0), 0);
      invoiceSeries = buildInvoiceTimeSeries(rows).series;

      const paidByCustomer = new Map<string, number>();
      for (const i of rows) {
        if ((i.status || "").toLowerCase() !== "paid" || !i.customer_id) continue;
        paidByCustomer.set(i.customer_id, (paidByCustomer.get(i.customer_id) ?? 0) + Number(i.total || 0));
      }
      if (crmCustomers.data) {
        clients = (crmCustomers.data as Array<{ id: string; contact_person?: string; company?: string }>).map(
          (c) => ({
            id: c.id,
            name: c.company || c.contact_person || "Client",
            subtitle: c.contact_person && c.company ? c.contact_person : "CRM client",
            amountLabel: money(paidByCustomer.get(c.id) ?? 0),
          }),
        );
      }
    }

    if (client && crmInvoices.data) {
      const rows = crmInvoices.data as Array<{
        total?: number;
        status?: string;
        created_at?: string;
        updated_at?: string;
        issue_date?: string;
      }>;
      invoiceTotal = rows.reduce((s, i) => s + (Number(i.total) || 0), 0);
      paidTotal = rows
        .filter((i) => (i.status || "").toLowerCase() === "paid")
        .reduce((s, i) => s + (Number(i.total) || 0), 0);
      outstandingTotal = rows
        .filter((i) => {
          const st = (i.status || "").toLowerCase();
          return st !== "paid" && st !== "cancelled";
        })
        .reduce((s, i) => s + (Number(i.total) || 0), 0);
      invoiceSeries = buildInvoiceTimeSeries(rows).series;
    }

    if (!client && crmProjects.data?.length) {
      const custMap = new Map(
        ((crmCustomers.data ?? []) as Array<{ id: string; contact_person?: string; company?: string }>).map(
          (c) => [c.id, c.company || c.contact_person || "Client"],
        ),
      );
      projects = (crmProjects.data as Array<{
        id: string;
        name?: string;
        status?: string;
        budget?: number;
        customer_id?: string;
      }>).map((p) => ({
        id: p.id,
        name: p.name || "Project",
        status: p.status,
        budget: p.budget,
        client: p.customer_id ? custMap.get(p.customer_id) : null,
      }));
      projectCount = projects.length;
    } else if (sharedProjects.data?.length) {
      projects = sharedProjects.data.map((p) => ({
        id: p.share_id,
        name: p.project_name || "Shared project",
        status: p.status,
        budget: p.budget,
        client: client ? p.freelancer_email : p.client_email,
      }));
      projectCount = projects.length;
    } else {
      const { count } = await supabase
        .from("project_shares")
        .select("share_id", { count: "exact", head: true })
        .or(client ? clientProjectFilter : `freelancer_uid.eq.${uid}`);
      projectCount = count ?? 0;
    }

    if (proposalRows.data?.length) {
      const counts = { pending: 0, shortlisted: 0, hired: 0, declined: 0, viewed: 0 };
      for (const p of proposalRows.data) {
        const s = (p.status || "pending").toLowerCase();
        if (s === "accepted") counts.hired += 1;
        else if (s === "shortlisted") counts.shortlisted += 1;
        else if (s === "declined" || s === "withdrawn") counts.declined += 1;
        else if (s === "viewed") counts.viewed += 1;
        else counts.pending += 1;
      }
      proposalSlices = [
        { name: "Awaiting review", value: counts.pending + counts.viewed, color: "#F59E0B" },
        { name: "Shortlisted", value: counts.shortlisted, color: "#0EA5E9" },
        { name: "Hired", value: counts.hired, color: "#0D9488" },
        { name: "Rejected", value: counts.declined, color: "#DC2626" },
      ].filter((x) => x.value > 0);
      if (!home.pending_proposals) {
        home.pending_proposals = counts.pending + counts.viewed;
      }
    }

    if (needs.data?.length) {
      opportunities = (needs.data as Array<{ id: string; title?: string; budget_band?: string }>).map(
        (n) => ({
          id: n.id,
          title: n.title || "Open job",
          budget: n.budget_band || "Budget TBD",
          type: "Remote · Connect",
        }),
      );
    }

    if (talent.data?.length) {
      freelancers = (
        talent.data as Array<{
          id: string;
          display_title?: string;
          headline?: string;
          rate_band?: string;
          avg_rating?: number;
        }>
      ).map((t) => ({
        id: t.id,
        name: t.display_title || "Freelancer",
        subtitle: t.headline || "Connect talent",
        amountLabel: t.rate_band || undefined,
        rating: Number(t.avg_rating ?? 0) || null,
      }));
    }

    if (taskRows.data) {
      tasksDone = taskRows.data.filter((t) =>
        ["done", "completed", "complete"].includes((t.status || "").toLowerCase()),
      ).length;
    }
    if (timeRows.data) {
      const hoursSum = (timeRows.data as Array<{ hours?: number }>).reduce(
        (s, r) => s + (Number(r.hours) || 0),
        0,
      );
      timeMinutes = Math.round(hoursSum * 60);
    }
  } catch {
    /* ignore partial failures */
  }

  const hours = Math.floor(timeMinutes / 60);
  const mins = timeMinutes % 60;
  const timeTracked = timeMinutes > 0 ? `${hours}h ${mins}m` : "0h 00m";

  if (client) {
    const spendBase = invoiceTotal || paidTotal || 0;
    const spendSlices =
      spendBase > 0
        ? [
            { name: "Web Development", value: Math.round(spendBase * 0.503), color: "#475569" },
            { name: "Design & Creative", value: Math.round(spendBase * 0.254), color: "#0EA5E9" },
            { name: "Mobile Development", value: Math.round(spendBase * 0.172), color: "#8B5CF6" },
            { name: "Writing & Content", value: Math.round(spendBase * 0.071), color: "#F59E0B" },
          ]
        : [];

    return (
      <ClientDashboard
        profile={profile}
        home={home}
        projectCount={projectCount}
        totalSpent={invoiceTotal}
        spendSeries={invoiceSeries}
        paidTotal={paidTotal}
        openBalances={outstandingTotal}
        refunds={0}
        outstanding={outstandingTotal}
        credits={credits}
        activities={activities}
        projects={projects}
        freelancers={freelancers}
        spendSlices={spendSlices}
      />
    );
  }

  return (
    <FreelancerDashboard
      profile={profile}
      home={home}
      projectCount={projectCount}
      invoiceTotal={invoiceTotal}
      invoiceSeries={invoiceSeries}
      credits={credits}
      profileCompleteness={profileCompleteness}
      successScore={successScore}
      activities={activities}
      projects={projects}
      clients={clients}
      proposalSlices={
        proposalSlices.length
          ? proposalSlices
          : [
              { name: "Awaiting review", value: home.pending_proposals ?? 0, color: "#F59E0B" },
              { name: "Shortlisted", value: 0, color: "#0EA5E9" },
              { name: "Hired", value: home.accepted_proposals ?? 0, color: "#0D9488" },
            ].filter((x) => x.value > 0)
      }
      opportunities={opportunities}
      week={{
        timeTracked,
        earned: money(paidTotal || Math.round(invoiceTotal * 0.35)),
        tasksDone,
        productivity: successScore,
      }}
    />
  );
}
