import { redirect } from "next/navigation";
import Link from "next/link";
import {
  Bookmark,
  Building2,
  Filter,
  FolderKanban,
  Plus,
  ShoppingBag,
  Star,
  Users,
} from "lucide-react";
import { getProfile, isClientAccount } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";
import { listCustomersServer, listProjectsServer } from "@/lib/crm/server";
import { listPublicConnectNeeds, listPublicConnectProfiles } from "@/lib/connect";
import {
  FreelancerCard,
  FreelancerPageHeader,
  OutlineButton,
  PrimaryButton,
  StatusPill,
} from "@/components/freelancer/ui";
import {
  ClientCard,
  ClientPageHeader,
  ClientPrimaryButton,
  ClientStatCard,
} from "@/components/client/ui";

export const metadata = { title: "Bookmarks" };

export default async function BookmarksPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const isClient = isClientAccount(profile);
  const supabase = await createClient();

  type BookmarkRow = {
    id: string;
    target_id: string;
    target_type: string;
    title: string | null;
    meta: Record<string, unknown> | null;
    created_at: string | null;
  };

  let bookmarks: BookmarkRow[] = [];
  try {
    const { data } = await supabase
      .from("freelancer_bookmarks")
      .select("id, target_id, target_type, title, meta, created_at")
      .eq("user_id", profile.id)
      .order("created_at", { ascending: false })
      .limit(50);
    bookmarks = (data ?? []) as BookmarkRow[];
  } catch {
    bookmarks = [];
  }

  if (isClient) {
    const freelancerBookmarks = bookmarks.filter(
      (b) => b.target_type === "freelancer",
    );
    const jobBookmarks = bookmarks.filter((b) => b.target_type === "job");
    let talent: Awaited<ReturnType<typeof listPublicConnectProfiles>> = [];
    let jobs: Awaited<ReturnType<typeof listPublicConnectNeeds>> = [];
    try {
      [talent, jobs] = await Promise.all([
        listPublicConnectProfiles(),
        listPublicConnectNeeds(),
      ]);
    } catch {
      talent = [];
      jobs = [];
    }
    const byUserId = new Map(talent.map((t) => [t.user_id, t]));
    const byId = new Map(talent.map((t) => [t.id, t]));
    const jobsById = new Map(jobs.map((j) => [j.id, j]));
    const savedTalent = freelancerBookmarks.flatMap((bookmark) => {
      const profileRow = byUserId.get(bookmark.target_id) || byId.get(bookmark.target_id);
      return profileRow ? [{ bookmark, profile: profileRow }] : [];
    });
    const savedJobs = jobBookmarks.flatMap((bookmark) => {
      const job = jobsById.get(bookmark.target_id);
      return job ? [{ bookmark, job }] : [];
    });
    const totalSaved = savedTalent.length + savedJobs.length;

    return (
      <div className="space-y-6 pb-10">
        <ClientPageHeader
          title="Bookmarks"
          subtitle="Save freelancers and Connect profiles you want to hire later."
          icon={Bookmark}
          actions={
            <ClientPrimaryButton href="/app/connect">
              <Plus className="h-4 w-4" />
              Browse talent
            </ClientPrimaryButton>
          }
        />

        <div className="grid gap-3 sm:grid-cols-3">
          <ClientStatCard label="Saved freelancers" value={savedTalent.length} icon={Users} />
          <ClientStatCard label="Saved jobs" value={savedJobs.length} icon={ShoppingBag} />
          <ClientStatCard
            label="Total bookmarks"
            value={totalSaved}
            icon={Bookmark}
          />
        </div>

        <ClientCard title="Saved freelancers">
          {savedTalent.length === 0 ? (
            <div className="rounded-xl border border-dashed border-border px-4 py-8 text-center">
              <p className="font-semibold text-navy">No saved freelancers yet</p>
              <p className="mt-2 text-sm text-text-secondary">
                Bookmark Connect profiles from the marketplace to find them here.
              </p>
              <Link
                href="/app/connect"
                className="mt-4 inline-block text-sm font-semibold text-client-accent"
              >
                Open Connect →
              </Link>
            </div>
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2">
              {savedTalent.map(({ bookmark, profile: cp }) => (
                <li
                  key={bookmark.id}
                  className="rounded-xl border border-border bg-background px-4 py-3"
                >
                  <div className="flex items-start gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-client-surface text-sm font-bold text-client-accent">
                      {(cp?.display_title || bookmark.title || "F").charAt(0)}
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-navy">
                        {cp?.display_title || bookmark.title || "Freelancer"}
                      </p>
                      <p className="truncate text-xs text-text-secondary">
                        {cp?.headline || "Saved Connect profile"}
                      </p>
                      {cp?.avg_rating != null && (
                        <p className="mt-1 text-xs text-amber-600">
                          ★ {Number(cp.avg_rating).toFixed(1)}
                          {cp.review_count != null ? ` · ${cp.review_count} reviews` : ""}
                        </p>
                      )}
                      <Link
                        href="/app/messages"
                        className="mt-2 inline-block text-xs font-semibold text-client-accent"
                      >
                        Message →
                      </Link>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </ClientCard>

        <ClientCard title="Saved jobs">
          {savedJobs.length === 0 ? (
            <div className="rounded-xl border border-dashed border-border px-4 py-8 text-center">
              <p className="font-semibold text-navy">No saved jobs yet</p>
              <p className="mt-2 text-sm text-text-secondary">
                Save Connect job posts to review them later.
              </p>
              <Link
                href="/app/connect?tab=jobs"
                className="mt-4 inline-block text-sm font-semibold text-client-accent"
              >
                Browse jobs →
              </Link>
            </div>
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2">
              {savedJobs.map(({ bookmark, job }) => (
                <li
                  key={bookmark.id}
                  className="rounded-xl border border-border bg-background px-4 py-3"
                >
                  <div className="flex items-start gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-client-surface text-client-accent">
                      <ShoppingBag className="h-5 w-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-navy">{job.title || "Connect job"}</p>
                      <p className="line-clamp-2 text-xs text-text-secondary">
                        {job.summary || "Open Connect brief"}
                      </p>
                      {job.budget_band && (
                        <p className="mt-1 text-xs font-semibold text-client-accent">
                          {job.budget_band}
                        </p>
                      )}
                      <Link
                        href={`/app/connect?tab=jobs`}
                        className="mt-2 inline-block text-xs font-semibold text-client-accent"
                      >
                        View jobs →
                      </Link>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </ClientCard>
      </div>
    );
  }

  let projects: Awaited<ReturnType<typeof listProjectsServer>> = [];
  let customers: Awaited<ReturnType<typeof listCustomersServer>> = [];
  let talent: Awaited<ReturnType<typeof listPublicConnectProfiles>> = [];
  let jobs: Awaited<ReturnType<typeof listPublicConnectNeeds>> = [];

  try {
    [projects, customers, talent, jobs] = await Promise.all([
      listProjectsServer(),
      listCustomersServer(),
      listPublicConnectProfiles(),
      listPublicConnectNeeds(),
    ]);
  } catch {
    /* ignore */
  }

  function matchesTargetId(
    row: { id?: string | null; local_id?: number | null },
    targetId: string,
  ) {
    return String(row.id ?? "") === targetId || String(row.local_id ?? "") === targetId;
  }

  const findProject = (targetId: string) => projects.find((p) => matchesTargetId(p, targetId));
  const findCustomer = (targetId: string) => customers.find((c) => matchesTargetId(c, targetId));
  const findTalent = (targetId: string) =>
    talent.find((t) => t.user_id === targetId || t.id === targetId);
  const findJob = (targetId: string) => jobs.find((j) => j.id === targetId);

  const savedProjects = bookmarks
    .filter((b) => b.target_type === "project")
    .flatMap((bookmark) => {
      const project = findProject(bookmark.target_id);
      return project ? [{ bookmark, project }] : [];
    });
  const savedClients = bookmarks
    .filter((b) => b.target_type === "client")
    .flatMap((bookmark) => {
      const client = findCustomer(bookmark.target_id);
      return client ? [{ bookmark, client }] : [];
    });
  const savedTalent = bookmarks
    .filter((b) => b.target_type === "freelancer")
    .flatMap((bookmark) => {
      const profile = findTalent(bookmark.target_id);
      return profile ? [{ bookmark, profile }] : [];
    });
  const savedJobs = bookmarks
    .filter((b) => b.target_type === "job")
    .flatMap((bookmark) => {
      const job = findJob(bookmark.target_id);
      return job ? [{ bookmark, job }] : [];
    });
  const total = savedProjects.length + savedClients.length + savedTalent.length + savedJobs.length;
  const recentBookmarks = bookmarks
    .map((bookmark) => {
      if (bookmark.target_type === "project") {
        const project = findProject(bookmark.target_id);
        return project
          ? { id: bookmark.id, label: project.name, type: "Project", icon: "project" as const }
          : null;
      }
      if (bookmark.target_type === "client") {
        const clientRow = findCustomer(bookmark.target_id);
        return clientRow
          ? {
              id: bookmark.id,
              label: clientRow.company || clientRow.contact_person || "Client",
              type: "Client",
              icon: "client" as const,
            }
          : null;
      }
      if (bookmark.target_type === "freelancer") {
        const profileRow = findTalent(bookmark.target_id);
        return profileRow
          ? {
              id: bookmark.id,
              label: profileRow.display_title || profileRow.headline || "Freelancer",
              type: "Freelancer",
              icon: "talent" as const,
            }
          : null;
      }
      if (bookmark.target_type === "job") {
        const job = findJob(bookmark.target_id);
        return job
          ? { id: bookmark.id, label: job.title || "Job", type: "Job", icon: "job" as const }
          : null;
      }
      return null;
    })
    .filter((item): item is NonNullable<typeof item> => Boolean(item))
    .slice(0, 5);

  return (
    <div className="space-y-6 pb-10">
      <FreelancerPageHeader
        title="Bookmarks"
        subtitle="Save and organize your favorite items to access them anytime."
        icon={Bookmark}
        actions={
          <>
            <OutlineButton>
              <Filter className="h-4 w-4" />
              Filters
            </OutlineButton>
            <PrimaryButton href="/app/connect">
              <Plus className="h-4 w-4" />
              Add New
            </PrimaryButton>
          </>
        }
      />

      <div className="flex flex-wrap gap-2">
        {[
          { label: `All Items (${total})`, active: true },
          { label: `Projects (${savedProjects.length})`, active: false },
          { label: `Clients (${savedClients.length})`, active: false },
          { label: `Freelancers (${savedTalent.length})`, active: false },
          { label: `Jobs (${savedJobs.length})`, active: false },
        ].map((t) => (
          <button
            key={t.label}
            type="button"
            className={`rounded-full px-4 py-2 text-xs font-bold ${
              t.active ? "bg-navy text-white" : "bg-surface text-text-secondary border border-border"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_280px]">
        <div className="space-y-6">
          <section>
            <h2 className="mb-3 font-display text-lg font-bold text-navy">Saved projects</h2>
            <div className="space-y-3">
              {savedProjects.map(({ bookmark, project: p }, i) => (
                <article
                  key={bookmark.id}
                  className="relative flex flex-col gap-3 rounded-2xl border border-border bg-surface p-4 shadow-sm sm:flex-row sm:items-center"
                >
                  <span className="absolute left-3 top-0 text-violet-500">
                    <Bookmark className="h-4 w-4 fill-violet-500" />
                  </span>
                  <span
                    className={`mt-2 flex h-12 w-12 shrink-0 items-center justify-center rounded-xl text-white ${
                      i % 2 === 0 ? "bg-primary" : "bg-violet-500"
                    }`}
                  >
                    <ShoppingBag className="h-5 w-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="font-bold text-navy">{p.name}</p>
                    <p className="text-xs text-text-secondary">
                      {p.description || "CRM project"}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      <StatusPill tone="violet">{p.status || "Project"}</StatusPill>
                      <StatusPill tone="blue">{p.currency || "USD"}</StatusPill>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-navy">
                      ${Number(p.budget || 0).toLocaleString()}
                    </p>
                    <p className="text-xs text-text-muted">Budget</p>
                  </div>
                </article>
              ))}
              {savedProjects.length === 0 && (
                <p className="rounded-2xl border border-dashed border-border bg-surface p-5 text-sm text-text-secondary">
                  Bookmark CRM projects to see them here.
                </p>
              )}
            </div>
            <Link
              href="/app/projects"
              className="mt-3 flex w-full items-center justify-center rounded-xl border border-border bg-surface py-3 text-sm font-semibold text-navy hover:border-primary/40"
            >
              View all Projects →
            </Link>
          </section>

          <section>
            <h2 className="mb-3 font-display text-lg font-bold text-navy">Saved clients</h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {savedClients.slice(0, 4).map(({ bookmark, client: c }) => (
                <article
                  key={bookmark.id}
                  className="relative rounded-2xl border border-border bg-surface p-4 shadow-sm"
                >
                  <Bookmark className="absolute right-3 top-3 h-4 w-4 fill-violet-500 text-violet-500" />
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                    <Building2 className="h-5 w-5" />
                  </span>
                  <p className="mt-3 font-bold text-navy">{c.company || c.contact_person}</p>
                  <p className="truncate text-xs text-text-secondary">
                    {Array.isArray(c.emails) ? String(c.emails[0] || "") : c.city || "Client"}
                  </p>
                  <p className="mt-2 text-xs font-semibold text-text-muted">
                    {c.status || "CRM client"}
                  </p>
                </article>
              ))}
              {savedClients.length === 0 && (
                <p className="col-span-full text-sm text-text-secondary">
                  Bookmark clients from your CRM to see them here.{" "}
                  <Link href="/app/clients" className="font-semibold text-primary">
                    Open clients →
                  </Link>
                </p>
              )}
            </div>
          </section>

          <section>
            <h2 className="mb-3 font-display text-lg font-bold text-navy">Saved Connect</h2>
            <div className="grid gap-3 sm:grid-cols-2">
              {savedTalent.map(({ bookmark, profile: cp }) => (
                <article
                  key={bookmark.id}
                  className="rounded-2xl border border-border bg-surface p-4 shadow-sm"
                >
                  <div className="flex items-start gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                      <Star className="h-5 w-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-navy">{cp.display_title || "Freelancer"}</p>
                      <p className="line-clamp-2 text-xs text-text-secondary">
                        {cp.headline || "Connect profile"}
                      </p>
                      {cp.rate_band && (
                        <p className="mt-1 text-xs font-semibold text-primary-dark">
                          {cp.rate_band}
                        </p>
                      )}
                    </div>
                  </div>
                </article>
              ))}
              {savedJobs.map(({ bookmark, job }) => (
                <article
                  key={bookmark.id}
                  className="rounded-2xl border border-border bg-surface p-4 shadow-sm"
                >
                  <div className="flex items-start gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                      <Users className="h-5 w-5" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-navy">{job.title || "Job"}</p>
                      <p className="line-clamp-2 text-xs text-text-secondary">
                        {job.summary || "Open Connect brief"}
                      </p>
                      {job.budget_band && (
                        <p className="mt-1 text-xs font-semibold text-primary-dark">
                          {job.budget_band}
                        </p>
                      )}
                    </div>
                  </div>
                </article>
              ))}
              {savedTalent.length === 0 && savedJobs.length === 0 && (
                <p className="col-span-full text-sm text-text-secondary">
                  Save Connect profiles or jobs to see them here.{" "}
                  <Link href="/app/connect" className="font-semibold text-primary">
                    Open Connect →
                  </Link>
                </p>
              )}
            </div>
          </section>
        </div>

        <aside className="space-y-4">
          <FreelancerCard title="Collections">
            <ul className="space-y-2">
              {[
                { name: "Saved projects", color: "bg-violet-500", count: savedProjects.length },
                { name: "Saved clients", color: "bg-primary", count: savedClients.length },
                { name: "Connect talent", color: "bg-sky-500", count: savedTalent.length },
                { name: "Connect jobs", color: "bg-amber-500", count: savedJobs.length },
              ].map((c) => (
                <li
                  key={c.name}
                  className="flex items-center gap-3 rounded-xl border border-border px-3 py-2.5"
                >
                  <span className={`h-3 w-3 rounded-full ${c.color}`} />
                  <span className="flex-1 text-sm font-semibold text-navy">{c.name}</span>
                  <span className="text-xs text-text-muted">{c.count}</span>
                </li>
              ))}
            </ul>
          </FreelancerCard>

          <FreelancerCard title="Recent bookmarks">
            <ul className="space-y-3 text-sm">
              {recentBookmarks.map((item) => (
                <li key={item.id} className="flex items-center gap-2">
                  {item.icon === "project" ? (
                    <FolderKanban className="h-4 w-4 text-primary" />
                  ) : item.icon === "client" ? (
                    <Building2 className="h-4 w-4 text-primary" />
                  ) : item.icon === "talent" ? (
                    <Star className="h-4 w-4 text-sky-600" />
                  ) : (
                    <Users className="h-4 w-4 text-sky-600" />
                  )}
                  <span className="flex-1 truncate font-medium text-navy">{item.label}</span>
                  <span className="text-[10px] text-text-muted">{item.type}</span>
                </li>
              ))}
              {recentBookmarks.length === 0 && (
                <li className="text-text-secondary">No recent bookmarks yet.</li>
              )}
            </ul>
          </FreelancerCard>

          <div className="rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/5 to-white p-5">
            <p className="font-display font-bold text-navy">Sync across devices</p>
            <p className="mt-1 text-sm text-text-secondary">
              Bookmarks stay available on web and the Android app.
            </p>
            <Link href="/app/account" className="mt-3 inline-block text-sm font-semibold text-primary">
              Learn more →
            </Link>
          </div>
          {bookmarks.length > 0 && (
            <p className="text-[10px] text-text-muted">{bookmarks.length} synced bookmarks</p>
          )}
        </aside>
      </div>
    </div>
  );
}
