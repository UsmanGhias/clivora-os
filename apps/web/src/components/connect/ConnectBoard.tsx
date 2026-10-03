"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import {
  Briefcase,
  Check,
  Inbox,
  Loader2,
  MapPin,
  MessageSquare,
  Search,
  ShieldCheck,
  Sparkles,
  Users,
  X,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { CONNECT_CREDIT_COSTS, parseConnectCreditError } from "@/lib/connect-credits";
import {
  skillsList,
  type ConnectNeed,
  type ConnectProfile,
  type ConnectRequestRow,
} from "@/lib/connect-types";
import { stripPortfolioMeta, parsePortfolioMeta } from "@/lib/connect-portfolio";
import { ConnectTrust } from "@/components/connect/ConnectTrust";
import { ConnectActions } from "@/components/connect/ConnectActions";
import { site } from "@/lib/site";
import { cn } from "@/lib/utils";
import { toggleBookmark, type BookmarkTargetType } from "@/lib/bookmarks";

const CATEGORIES = [
  "Web & Software",
  "Design & Creative",
  "Sales & Marketing",
  "Writing",
  "Admin & Support",
  "Other",
] as const;

function matchesCategory(hay: string, category: string): boolean {
  const map: Record<string, string[]> = {
    "Web & Software": ["web", "software", "dev", "code", "react", "flutter", "mobile", "api", "app"],
    "Design & Creative": ["design", "ui", "ux", "brand", "figma", "creative", "illustrat"],
    "Sales & Marketing": ["sales", "marketing", "seo", "ads", "growth", "content market"],
    Writing: ["writ", "copy", "blog", "edit", "content"],
    "Admin & Support": ["admin", "support", "va", "assistant", "ops"],
    Other: [],
  };
  const keys = map[category] ?? [];
  if (category === "Other" || keys.length === 0) return true;
  return keys.some((k) => hay.includes(k));
}

type Tab = "talent" | "jobs" | "inbox";
type SortMode = "featured" | "rating" | "rate" | "newest";

function memberSinceLabel(iso?: string | null) {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString(undefined, { month: "short", year: "numeric" });
}

function TrustStars({ rating, count }: { rating?: number | null; count?: number | null }) {
  const n = Number(count ?? 0);
  const avg = Number(rating ?? 0);
  if (n <= 0 || avg <= 0) {
    return (
      <span className="rounded-lg bg-sky-50 px-2 py-0.5 text-[10px] font-bold uppercase text-sky-800">
        New
      </span>
    );
  }
  const topRated = avg >= 4.5 && n >= 3;
  return (
    <span className="inline-flex flex-wrap items-center justify-end gap-1">
      {topRated && (
        <span className="rounded-lg bg-amber-100 px-2 py-0.5 text-[10px] font-bold uppercase text-amber-900">
          Top rated
        </span>
      )}
      <span className="inline-flex items-center gap-1 text-xs font-bold text-amber-700">
        <span className="text-amber-400">★</span>
        {avg.toFixed(1)}
        <span className="font-medium text-text-muted">({n})</span>
      </span>
    </span>
  );
}

export function ConnectBoard({
  profiles,
  needs,
  requests,
  signedIn,
  isProPlus,
  isClient,
  isRestricted,
  myUserId,
  portalMode = false,
  accent = "teal",
  defaultTab = "talent",
  loadError = null,
  savedBookmarkIds = [],
}: {
  profiles: ConnectProfile[];
  needs: ConnectNeed[];
  requests: ConnectRequestRow[];
  signedIn: boolean;
  isProPlus: boolean;
  isClient: boolean;
  isRestricted: boolean;
  myUserId?: string;
  portalMode?: boolean;
  accent?: "teal" | "slate";
  defaultTab?: Tab;
  loadError?: string | null;
  savedBookmarkIds?: string[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const slate = accent === "slate";
  const chipActive = slate ? "bg-client-accent text-white" : "bg-primary text-white";
  const chipIdle = slate ? "bg-client-surface text-client-accent" : "bg-teal-50 text-teal-900";
  const chipNavActive = slate ? "bg-client-accent text-white" : "bg-navy text-white";
  const actionBtn = slate ? "bg-client-accent hover:bg-client-header" : "bg-primary hover:bg-primary-dark";
  const [tab, setTab] = useState<Tab>(defaultTab);
  const [inboxFilter, setInboxFilter] = useState<"all" | "pending" | "accepted" | "declined">("all");
  const [query, setQuery] = useState("");
  const [skillFilter, setSkillFilter] = useState<string | null>(null);
  const [categoryFilter, setCategoryFilter] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [sort, setSort] = useState<SortMode>("featured");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [bookmarkBusyId, setBookmarkBusyId] = useState<string | null>(null);
  const [savedIds, setSavedIds] = useState(() => new Set(savedBookmarkIds));
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [compose, setCompose] = useState<{
    toUserId: string;
    targetProfileId?: string;
    targetNeedId?: string;
    label: string;
  } | null>(null);
  const [message, setMessage] = useState("Hi. I'd like to connect on CLIVORA.");
  const [contactSubject, setContactSubject] = useState("Connect introduction");
  const [contactAvailability, setContactAvailability] = useState("This week");
  const [jobsPage, setJobsPage] = useState(1);
  const [talentVisible, setTalentVisible] = useState(12);
  const [inboxVisible, setInboxVisible] = useState(12);
  const JOBS_PER_PAGE = 12;
  const PAGE_SIZE = 12;

  useEffect(() => {
    setTab(defaultTab);
  }, [defaultTab]);

  useEffect(() => {
    setSavedIds(new Set(savedBookmarkIds));
  }, [savedBookmarkIds]);

  useEffect(() => {
    const raw = String(searchParams.get("tab") ?? "").toLowerCase();
    if (raw === "talent" || raw === "jobs" || raw === "inbox") {
      setTab(raw);
    }
  }, [searchParams]);

  function selectTab(next: Tab) {
    setTab(next);
    const params = new URLSearchParams(searchParams.toString());
    params.set("tab", next);
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  }

  const pendingIncoming = useMemo(
    () => requests.filter((r) => r.to_user_id === myUserId && r.status === "pending").length,
    [requests, myUserId],
  );

  const filteredInbox = useMemo(() => {
    if (inboxFilter === "all") return requests;
    return requests.filter((r) => r.status === inboxFilter);
  }, [requests, inboxFilter]);

  const popularSkills = useMemo(() => {
    const counts = new Map<string, number>();
    for (const p of profiles) {
      for (const s of skillsList(p.skills)) {
        const key = s.trim();
        if (!key) continue;
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
    }
    for (const n of needs) {
      for (const s of skillsList(n.skills)) {
        const key = s.trim();
        if (!key) continue;
        counts.set(key, (counts.get(key) ?? 0) + 1);
      }
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([s]) => s);
  }, [profiles, needs]);

  const filteredProfiles = useMemo(() => {
    const q = query.trim().toLowerCase();
    let list = profiles.filter((p) => {
      if (skillFilter) {
        const skills = skillsList(p.skills).map((s) => s.toLowerCase());
        if (!skills.some((s) => s === skillFilter.toLowerCase())) return false;
      }
      const hay = [
        p.display_title,
        p.headline,
        p.bio ? stripPortfolioMeta(p.bio) : "",
        p.location_label,
        p.rate_band,
        ...skillsList(p.skills),
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      if (categoryFilter && !matchesCategory(hay, categoryFilter)) return false;
      if (!q) return true;
      return hay.includes(q);
    });
    if (sort === "rate") {
      list = [...list].sort((a, b) => (b.rate_band || "").localeCompare(a.rate_band || ""));
    } else if (sort === "newest") {
      list = [...list].sort((a, b) =>
        String(b.updated_at || b.created_at || "").localeCompare(
          String(a.updated_at || a.created_at || ""),
        ),
      );
    } else if (sort === "rating") {
      list = [...list].sort((a, b) => {
        const score =
          Number(b.reputation_score ?? 0) - Number(a.reputation_score ?? 0) ||
          Number(b.avg_rating ?? 0) - Number(a.avg_rating ?? 0) ||
          Number(b.review_count ?? 0) - Number(a.review_count ?? 0);
        return score;
      });
    } else {
      list = [...list].sort((a, b) => {
        const verified = Number(!!b.is_verified) - Number(!!a.is_verified);
        if (verified !== 0) return verified;
        return Number(b.reputation_score ?? 0) - Number(a.reputation_score ?? 0);
      });
    }
    return list;
  }, [profiles, query, skillFilter, categoryFilter, sort]);

  const filteredNeeds = useMemo(() => {
    const q = query.trim().toLowerCase();
    let list = needs.filter((n) => {
      if (skillFilter) {
        const skills = skillsList(n.skills).map((s) => s.toLowerCase());
        if (!skills.some((s) => s === skillFilter.toLowerCase())) return false;
      }
      const hay = [n.title, n.summary, n.budget_band, ...skillsList(n.skills)]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      if (categoryFilter && !matchesCategory(hay, categoryFilter)) return false;
      if (!q) return true;
      return hay.includes(q);
    });
    list = [...list].sort((a, b) => {
      const aDirect = a.is_direct_client ? 1 : 0;
      const bDirect = b.is_direct_client ? 1 : 0;
      if (aDirect !== bDirect) return bDirect - aDirect;
      if (sort === "newest") {
        return String(b.created_at || "").localeCompare(String(a.created_at || ""));
      }
      return 0;
    });
    return list;
  }, [needs, query, skillFilter, categoryFilter, sort]);

  async function sendRequest(e: FormEvent) {
    e.preventDefault();
    if (!compose) return;
    setError(null);
    setOk(null);
    if (!signedIn) {
      router.push(`/signup?next=${encodeURIComponent("/edition")}`);
      return;
    }
    if (!isProPlus) {
      router.push("/edition");
      return;
    }
    if (isRestricted) {
      setError("Your account is restricted. Contact support to restore Connect posting.");
      return;
    }
    setBusyId(compose.toUserId);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      if (compose.toUserId === user.id) throw new Error("You cannot contact yourself");
      const { error: err } = await supabase.rpc("connect_send_request", {
        p_to_user_id: compose.toUserId,
        p_target_profile_id: compose.targetProfileId || null,
        p_target_need_id: compose.targetNeedId || null,
        p_message: [
          contactSubject.trim() ? `Subject: ${contactSubject.trim()}` : "",
          message.trim() || "I'd like to connect on CLIVORA.",
          contactAvailability.trim()
            ? `\nAvailability to chat: ${contactAvailability.trim()}`
            : "",
          "\n- Sent via CLIVORA Contact (emails unlock after mutual accept)",
        ]
          .filter(Boolean)
          .join("\n"),
      });
      if (err) throw err;
      setOk(`Request sent (−${CONNECT_CREDIT_COSTS.contact} credit). Contact unlocks after they accept.`);
      setCompose(null);
      router.refresh();
    } catch (err) {
      setError(parseConnectCreditError(err).message);
    } finally {
      setBusyId(null);
    }
  }

  async function respond(requestId: string, accept: boolean) {
    setBusyId(requestId);
    setError(null);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Sign in required");
      const { error: err } = await supabase.rpc("connect_respond_request", {
        p_request_id: requestId,
        p_accept: accept,
      });
      if (err) throw err;
      setOk(accept ? "Accepted - you can message each other now." : "Request declined.");
      router.refresh();
    } catch (err) {
      setError(parseConnectCreditError(err).message);
    } finally {
      setBusyId(null);
    }
  }

  function contactGate(action: () => void) {
    if (!signedIn) {
      router.push(`/signup?next=${encodeURIComponent("/edition")}`);
      return;
    }
    if (!isProPlus) {
      router.push("/edition");
      return;
    }
    if (isRestricted) {
      setError("Your account is restricted from Connect actions.");
      return;
    }
    action();
  }

  async function onToggleBookmark({
    targetId,
    targetType,
    title,
    meta,
  }: {
    targetId: string;
    targetType: BookmarkTargetType;
    title?: string | null;
    meta?: Record<string, unknown>;
  }) {
    if (!signedIn) {
      router.push(`/login?next=${encodeURIComponent(pathname || "/connect")}`);
      return;
    }
    const wasSaved = savedIds.has(targetId);
    setError(null);
    setOk(null);
    setBookmarkBusyId(targetId);
    setSavedIds((prev) => {
      const next = new Set(prev);
      if (wasSaved) next.delete(targetId);
      else next.add(targetId);
      return next;
    });
    try {
      await toggleBookmark({ targetId, targetType, title, meta, saved: wasSaved });
      setOk(wasSaved ? "Removed from bookmarks." : "Saved to bookmarks.");
      router.refresh();
    } catch (err) {
      setSavedIds((prev) => {
        const next = new Set(prev);
        if (wasSaved) next.add(targetId);
        else next.delete(targetId);
        return next;
      });
      setError(err instanceof Error ? err.message : "Could not update bookmark.");
    } finally {
      setBookmarkBusyId(null);
    }
  }

  return (
    <div className="space-y-6">
      {!portalMode && (
        <ConnectActions signedIn={signedIn} isProPlus={isProPlus} isClient={isClient} />
      )}

      <div className="rounded-2xl border border-border bg-surface p-4 shadow-sm sm:p-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="relative flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={
                portalMode && isClient
                  ? "Search by skill, name, or keyword…"
                  : tab === "jobs"
                    ? "Search jobs, skills, budget…"
                    : "Search talent, skills, location…"
              }
              className={cn(
                "w-full rounded-xl border border-border bg-white py-2.5 pl-10 pr-3 text-sm outline-none focus:ring-2",
                slate ? "ring-client-accent" : "ring-primary",
              )}
            />
          </div>
          {portalMode && isClient && (
            <button
              type="button"
              className={cn("rounded-xl px-5 py-2.5 text-sm font-bold text-white", actionBtn)}
            >
              Search
            </button>
          )}
          {portalMode && (
            <div className="flex rounded-xl bg-background p-1">
              {(
                [
                  { id: "talent" as const, label: "Talent", icon: Users },
                  { id: "jobs" as const, label: "Jobs", icon: Briefcase },
                  { id: "inbox" as const, label: "Inbox", icon: MessageSquare },
                ] as const
              ).map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => selectTab(t.id)}
                  className={cn(
                    "inline-flex flex-1 items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-bold sm:flex-none",
                    tab === t.id ? chipNavActive : "text-text-secondary hover:text-navy",
                  )}
                >
                  <t.icon className="h-3.5 w-3.5" />
                  {t.label}
                  {t.id === "inbox" && pendingIncoming > 0 && (
                    <span className="rounded-full bg-amber-500 px-1.5 text-[10px] text-white">
                      {pendingIncoming}
                    </span>
                  )}
                </button>
              ))}
            </div>
          )}
          {!portalMode && (
          <div className="flex rounded-xl bg-background p-1">
            {(
              [
                { id: "talent" as const, label: "Talent", icon: Users },
                { id: "jobs" as const, label: "Jobs", icon: Briefcase },
                { id: "inbox" as const, label: "Inbox", icon: MessageSquare },
              ] as const
            ).map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => selectTab(t.id)}
                className={cn(
                  "inline-flex flex-1 items-center justify-center gap-1.5 rounded-lg px-3 py-2 text-xs font-bold sm:flex-none",
                  tab === t.id ? "bg-navy text-white" : "text-text-secondary hover:text-navy",
                )}
              >
                <t.icon className="h-3.5 w-3.5" />
                {t.label}
                {t.id === "inbox" && pendingIncoming > 0 && (
                  <span className="rounded-full bg-amber-500 px-1.5 text-[10px] text-white">
                    {pendingIncoming}
                  </span>
                )}
              </button>
            ))}
          </div>
          )}
        </div>

        {tab !== "inbox" && (
          <div className="mt-3 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => setCategoryFilter(null)}
              className={cn(
                "rounded-lg px-2.5 py-1 text-xs font-semibold",
                !categoryFilter ? chipNavActive : "bg-background text-text-secondary",
              )}
            >
              All categories
            </button>
            {CATEGORIES.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setCategoryFilter(categoryFilter === c ? null : c)}
                className={cn(
                  "rounded-lg px-2.5 py-1 text-xs font-semibold",
                  categoryFilter === c ? chipNavActive : chipIdle,
                )}
              >
                {c}
              </button>
            ))}
          </div>
        )}

        {popularSkills.length > 0 && tab !== "inbox" && (
          <div className="mt-3 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => setSkillFilter(null)}
              className={cn(
                "rounded-lg px-2.5 py-1 text-xs font-semibold",
                !skillFilter ? chipNavActive : "bg-background text-text-secondary",
              )}
            >
              All skills
            </button>
            {popularSkills.map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => setSkillFilter(skillFilter === s ? null : s)}
                className={cn(
                  "rounded-lg px-2.5 py-1 text-xs font-semibold",
                  skillFilter === s ? chipActive : "bg-background text-text-secondary",
                )}
              >
                {s}
              </button>
            ))}
          </div>
        )}

        {tab !== "inbox" && (query.trim() || categoryFilter || skillFilter || sort !== "featured") && (
          <div className="mt-3 flex flex-wrap items-center gap-2 rounded-xl border border-border bg-background px-3 py-2 text-xs">
            <span className="font-bold text-navy">Applied filters</span>
            {query.trim() && (
              <button
                type="button"
                onClick={() => setQuery("")}
                className="rounded-lg bg-white px-2 py-1 font-semibold text-text-secondary hover:text-navy"
              >
                Search: {query.trim()} ×
              </button>
            )}
            {categoryFilter && (
              <button
                type="button"
                onClick={() => setCategoryFilter(null)}
                className="rounded-lg bg-white px-2 py-1 font-semibold text-text-secondary hover:text-navy"
              >
                Category: {categoryFilter} ×
              </button>
            )}
            {skillFilter && (
              <button
                type="button"
                onClick={() => setSkillFilter(null)}
                className="rounded-lg bg-white px-2 py-1 font-semibold text-text-secondary hover:text-navy"
              >
                Skill: {skillFilter} ×
              </button>
            )}
            {sort !== "featured" && (
              <button
                type="button"
                onClick={() => setSort("featured")}
                className="rounded-lg bg-white px-2 py-1 font-semibold text-text-secondary hover:text-navy"
              >
                Sort: {sort === "rating" ? "Top rated" : sort === "rate" ? "Rate" : "Newest"} ×
              </button>
            )}
            <button
              type="button"
              onClick={() => {
                setQuery("");
                setCategoryFilter(null);
                setSkillFilter(null);
                setSort("featured");
              }}
              className="ml-auto rounded-lg bg-navy px-2 py-1 font-bold text-white"
            >
              Clear all
            </button>
          </div>
        )}

        <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-text-secondary">
          <span className="rounded-lg bg-primary/10 px-2.5 py-1 font-semibold text-primary-dark">
            {filteredProfiles.length} freelancers
          </span>
          <span className="rounded-lg bg-client-surface px-2.5 py-1 font-semibold text-client-accent">
            {filteredNeeds.length} open jobs
          </span>
          <span className="rounded-lg bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-800">
            $0 platform fee
          </span>
          {tab !== "inbox" && (
            <label className="ml-auto inline-flex items-center gap-1.5 font-semibold text-navy">
              Sort
              <select
                value={sort}
                onChange={(e) => setSort(e.target.value as SortMode)}
                className="rounded-lg border border-border bg-white px-2 py-1 text-xs"
              >
                <option value="featured">Featured</option>
                {tab === "talent" && <option value="rating">Top rated</option>}
                <option value="newest">Newest</option>
                {tab === "talent" && <option value="rate">Rate</option>}
              </select>
            </label>
          )}
          {!isProPlus && (
            <Link
              href={signedIn ? "/edition" : `/signup?next=${encodeURIComponent("/edition")}`}
              className="rounded-lg bg-amber-100 px-2.5 py-1 font-semibold text-amber-900"
            >
              {signedIn
                ? `Upgrade to contact · ${site.pricing.proPlusMonthlyLabel}/mo`
                : `Buy Pro Plus · ${site.pricing.proPlusMonthlyLabel}/mo`}
            </Link>
          )}
        </div>
      </div>

      {(error || ok) && (
        <p
          className={cn(
            "rounded-xl px-4 py-3 text-sm",
            error ? "bg-error/10 text-error" : "bg-primary/10 text-primary-dark",
          )}
        >
          {error || ok}
        </p>
      )}

      {compose && (
        <form
          onSubmit={sendRequest}
          className="space-y-3 rounded-2xl border border-primary/30 bg-gradient-to-br from-primary/10 via-white to-teal-50 p-5 shadow-sm"
        >
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-sm font-bold text-navy">Contact {compose.label}</p>
              <p className="mt-1 text-xs text-text-secondary">
                Private Connect request (−{CONNECT_CREDIT_COSTS.contact} credit). Emails stay hidden
                until both sides accept - safer than open marketplaces.
              </p>
            </div>
            <span className="rounded-full bg-primary/15 px-2.5 py-1 text-[10px] font-bold uppercase text-primary-dark">
              Secure contact
            </span>
          </div>
          <label className="block text-xs font-semibold text-text-secondary">
            Subject
            <input
              value={contactSubject}
              onChange={(e) => setContactSubject(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm"
              placeholder="Why you're reaching out"
            />
          </label>
          <label className="block text-xs font-semibold text-text-secondary">
            Message
            <textarea
              required
              rows={4}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm"
              placeholder="Introduce yourself, relevant wins, and what you want to discuss…"
            />
          </label>
          <div className="flex flex-wrap gap-2">
            {(
              [
                ["Fit", "Hi - I saw your listing and think we're a strong fit for this brief."],
                ["Ready", "Quick intro: I deliver similar work and can start this week."],
                ["Scope", "I'd love to clarify scope and propose a clear milestone plan."],
              ] as const
            ).map(([label, text]) => (
              <button
                key={label}
                type="button"
                onClick={() => setMessage(text)}
                className="rounded-full border border-dashed border-primary/30 bg-white px-3 py-1 text-[11px] font-semibold text-primary-dark hover:bg-primary/5"
              >
                Template: {label}
              </button>
            ))}
          </div>
          <label className="block text-xs font-semibold text-text-secondary">
            When can you chat?
            <select
              value={contactAvailability}
              onChange={(e) => setContactAvailability(e.target.value)}
              className="mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm"
            >
              {["Today", "This week", "Next week", "Flexible"].map((o) => (
                <option key={o} value={o}>
                  {o}
                </option>
              ))}
            </select>
          </label>
          <p className="text-[11px] text-text-muted">
            After mutual accept you can message freely. Taking deals off-platform to avoid fees
            violates CLIVORA policy.
          </p>
          <div className="flex flex-wrap gap-2">
            <button
              type="submit"
              disabled={!!busyId}
              className="rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
            >
              {busyId ? "Sending…" : "Send Connect request"}
            </button>
            <button
              type="button"
              onClick={() => setCompose(null)}
              className="rounded-xl border border-border px-4 py-2.5 text-sm font-semibold"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {tab === "talent" && (
        <section className="space-y-4">
          <div className="flex items-end justify-between gap-3">
            <div>
              <h2 className="font-display text-xl font-extrabold text-navy">Top freelancers</h2>
              <p className="text-sm text-text-secondary">
                Verified listings from the CLIVORA network
              </p>
            </div>
            {signedIn && isProPlus && !isClient && (
              <Link href="/app/connect/manage" className="text-sm font-semibold text-primary">
                Edit my profile →
              </Link>
            )}
          </div>
          {filteredProfiles.length === 0 ? (
            <Empty
              text="No talent matches yet. Try another search or publish your listing."
              ctaHref={
                signedIn
                  ? isProPlus
                    ? "/app/connect/manage"
                    : "/edition"
                  : `/signup?next=${encodeURIComponent("/edition")}`
              }
              ctaLabel={
                signedIn
                  ? isProPlus
                    ? "Publish my listing"
                    : `Buy Pro Plus · ${site.pricing.proPlusMonthlyLabel}/mo`
                  : `Buy Pro Plus · ${site.pricing.proPlusMonthlyLabel}/mo`
              }
            />
          ) : portalMode && isClient ? (
            <div className="space-y-4">
              {filteredProfiles.slice(0, talentVisible).map((p) => (
                <article
                  key={p.id}
                  className="flex flex-col gap-4 rounded-2xl border border-border bg-surface p-5 shadow-sm transition hover:border-client-accent/30 lg:flex-row lg:items-center"
                >
                  <div className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-xl font-bold text-primary">
                    {p.avatar_url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={p.avatar_url} alt="" className="h-full w-full object-cover" />
                    ) : (
                      (p.display_title || "F").charAt(0)
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <h3 className="font-bold text-navy">{p.display_title || "Freelancer"}</h3>
                      {p.is_verified && (
                        <span className="inline-flex items-center gap-1 rounded-lg bg-primary/10 px-2 py-0.5 text-[10px] font-bold uppercase text-primary-dark">
                          <ShieldCheck className="h-3 w-3" /> Verified
                        </span>
                      )}
                    </div>
                    {p.location_label && (
                      <p className="mt-0.5 inline-flex items-center gap-1 text-xs text-text-muted">
                        <MapPin className="h-3 w-3" />
                        {p.location_label}
                      </p>
                    )}
                    <p className="mt-1 text-sm font-medium text-text-primary">
                      {p.headline || p.display_title}
                    </p>
                    <p className="mt-1 line-clamp-2 text-sm text-text-secondary">
                      {stripPortfolioMeta(p.bio)}
                    </p>
                    {(() => {
                      const meta = parsePortfolioMeta(p.bio);
                      const prs = meta.projects || [];
                      if (!prs.length) return null;
                      const verifiedCount = prs.filter((pr) => pr.isVerified).length;
                      return (
                        <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                          <span className="inline-flex items-center gap-1 rounded-md bg-teal-50 px-2 py-0.5 text-[10px] font-bold text-teal-800 border border-teal-200">
                            {prs.length} Project{prs.length === 1 ? "" : "s"}
                          </span>
                          {verifiedCount > 0 && (
                            <span className="inline-flex items-center gap-1 rounded-md bg-emerald-50 px-2 py-0.5 text-[10px] font-bold text-emerald-800 border border-emerald-200">
                              ✓ {verifiedCount} Verified
                            </span>
                          )}
                        </div>
                      );
                    })()}
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {skillsList(p.skills)
                        .slice(0, 5)
                        .map((s) => (
                          <span
                            key={s}
                            className="rounded-lg bg-background px-2 py-0.5 text-[11px] text-text-secondary"
                          >
                            {s}
                          </span>
                        ))}
                    </div>
                  </div>
                  <div className="shrink-0 text-center lg:text-right">
                    <TrustStars rating={p.avg_rating} count={p.review_count} />
                    {Number(p.completion_rate ?? 0) > 0 && (
                      <p className="mt-1 text-xs font-semibold text-success">
                        {Number(p.completion_rate).toFixed(0)}% job success
                      </p>
                    )}
                    <p className="mt-2 font-display text-lg font-extrabold text-navy">
                      {p.rate_band || "$25 / hr"}
                    </p>
                    <div className="mt-3 flex flex-wrap justify-center gap-2 lg:justify-end">
                      <button
                        type="button"
                        className={cn("rounded-xl px-4 py-2 text-sm font-semibold text-white", actionBtn)}
                        onClick={() =>
                          contactGate(() =>
                            setCompose({
                              toUserId: p.user_id,
                              targetProfileId: p.id,
                              label: p.display_title || "freelancer",
                            }),
                          )
                        }
                      >
                        View profile
                      </button>
                      <button
                        type="button"
                        disabled={bookmarkBusyId === p.user_id}
                        onClick={() =>
                          void onToggleBookmark({
                            targetId: p.user_id,
                            targetType: "freelancer",
                            title: p.display_title || p.headline || "Freelancer",
                            meta: {
                              profile_id: p.id,
                              headline: p.headline,
                              location_label: p.location_label,
                            },
                          })
                        }
                        className={cn(
                          "rounded-xl border px-4 py-2 text-sm font-semibold disabled:opacity-60",
                          savedIds.has(p.user_id)
                            ? "border-client-accent/30 bg-client-surface text-client-accent"
                            : "border-border text-navy",
                        )}
                      >
                        {savedIds.has(p.user_id) ? "Unsave" : "Save"}
                      </button>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {filteredProfiles.slice(0, talentVisible).map((p) => (
                <article
                  key={p.id}
                  className="flex flex-col rounded-2xl border border-border bg-surface p-5 shadow-sm transition hover:border-primary/40"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex min-w-0 items-start gap-3">
                      <div className="flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary/10 text-lg font-bold text-primary">
                        {p.avatar_url ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={p.avatar_url} alt="" className="h-full w-full object-cover" />
                        ) : (
                          (p.display_title || "F").charAt(0)
                        )}
                      </div>
                      <div className="min-w-0">
                      <h3 className="font-bold text-navy">{p.display_title || "Freelancer"}</h3>
                      {p.location_label && (
                        <p className="mt-0.5 inline-flex items-center gap-1 text-xs text-text-muted">
                          <MapPin className="h-3 w-3" />
                          {p.location_label}
                        </p>
                      )}
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      {p.is_verified && (
                        <span className="inline-flex items-center gap-1 rounded-lg bg-primary/10 px-2 py-0.5 text-[10px] font-bold uppercase text-primary-dark">
                          <ShieldCheck className="h-3 w-3" /> Verified
                        </span>
                      )}
                      <TrustStars rating={p.avg_rating} count={p.review_count} />
                    </div>
                  </div>
                  <p
                    className={cn(
                      "mt-2 text-sm text-text-secondary",
                      expandedId === p.id ? "" : "line-clamp-2",
                    )}
                  >
                    {p.headline || p.bio || "Available on CLIVORA Connect"}
                  </p>
                  {(p.bio || p.headline) && (
                    <button
                      type="button"
                      className="mt-1 text-xs font-semibold text-primary"
                      onClick={() => setExpandedId(expandedId === p.id ? null : p.id)}
                    >
                      {expandedId === p.id ? "Show less" : "Full profile"}
                    </button>
                  )}
                  {expandedId === p.id && p.bio && p.headline && (
                    <p className="mt-2 text-sm text-text-secondary">
                      {stripPortfolioMeta(p.bio)}
                    </p>
                  )}
                  {(() => {
                    const meta = parsePortfolioMeta(p.bio);
                    const prs = meta.projects || [];
                    if (!prs.length) return null;
                    const verifiedCount = prs.filter((pr) => pr.isVerified).length;
                    return (
                      <div className="mt-2 flex flex-wrap items-center gap-1.5">
                        <span className="inline-flex items-center gap-1 rounded-md bg-teal-50 px-2 py-0.5 text-[10px] font-bold text-teal-800 border border-teal-200">
                          {prs.length} Project{prs.length === 1 ? "" : "s"}
                        </span>
                        {verifiedCount > 0 && (
                          <span className="inline-flex items-center gap-1 rounded-md bg-emerald-50 px-2 py-0.5 text-[10px] font-bold text-emerald-800 border border-emerald-200">
                            ✓ {verifiedCount} Verified
                          </span>
                        )}
                      </div>
                    );
                  })()}
                  <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-text-muted">
                    {memberSinceLabel(p.created_at) && (
                      <span>Member since {memberSinceLabel(p.created_at)}</span>
                    )}
                    {Number(p.completion_rate ?? 0) > 0 && (
                      <span>{Number(p.completion_rate).toFixed(0)}% jobs completed</span>
                    )}
                    {Number(p.profile_completeness ?? 0) >= 80 && (
                      <span className="font-semibold text-primary-dark">Strong profile</span>
                    )}
                  </div>
                  {p.rate_band && (
                    <p className="mt-2 text-sm font-extrabold text-navy">{p.rate_band}</p>
                  )}
                  {p.availability && (
                    <p className="text-xs font-medium text-success">{p.availability}</p>
                  )}
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    {skillsList(p.skills)
                      .slice(0, 6)
                      .map((s) => (
                        <button
                          key={s}
                          type="button"
                          onClick={() => setSkillFilter(s)}
                          className="rounded-lg bg-background px-2 py-0.5 text-[11px] text-text-secondary hover:bg-primary/10 hover:text-primary-dark"
                        >
                          {s}
                        </button>
                      ))}
                  </div>
                  <button
                    type="button"
                    disabled={p.user_id === myUserId}
                    onClick={() =>
                      contactGate(() =>
                        setCompose({
                          toUserId: p.user_id,
                          targetProfileId: p.id,
                          label: p.display_title || "freelancer",
                        }),
                      )
                    }
                    className="mt-4 rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-40"
                  >
                    Contact
                  </button>
                  <button
                    type="button"
                    disabled={bookmarkBusyId === p.user_id}
                    onClick={() =>
                      void onToggleBookmark({
                        targetId: p.user_id,
                        targetType: "freelancer",
                        title: p.display_title || p.headline || "Freelancer",
                        meta: {
                          profile_id: p.id,
                          headline: p.headline,
                          location_label: p.location_label,
                        },
                      })
                    }
                    className={cn(
                      "mt-2 rounded-xl border px-4 py-2.5 text-sm font-semibold disabled:opacity-60",
                      savedIds.has(p.user_id)
                        ? "border-primary/30 bg-primary/10 text-primary-dark"
                        : "border-border text-navy",
                    )}
                  >
                    {savedIds.has(p.user_id) ? "Unsave" : "Save"}
                  </button>
                </article>
              ))}
            </div>
          )}
          {filteredProfiles.length > talentVisible && (
            <div className="flex justify-center pt-2">
              <button
                type="button"
                onClick={() => setTalentVisible((n) => n + PAGE_SIZE)}
                className="rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-bold text-navy hover:border-primary/40"
              >
                Load more talent ({filteredProfiles.length - talentVisible} left)
              </button>
            </div>
          )}
        </section>
      )}

      {tab === "jobs" && (
        <section className="space-y-4">
          <div className="flex items-end justify-between gap-3">
            <div>
              <h2 className="font-display text-xl font-extrabold text-navy">Open jobs</h2>
              <p className="text-sm text-text-secondary">Client briefs looking for freelancers</p>
            </div>
            {isClient ? (
              <Link
                href={signedIn ? "/app/connect/manage" : `/signup?next=${encodeURIComponent("/app/connect/manage")}`}
                className="text-sm font-semibold text-primary hover:underline"
              >
                Post a job (Free) →
              </Link>
            ) : signedIn && isProPlus ? (
              <Link href="/app/connect/manage" className="text-sm font-semibold text-primary hover:underline">
                Post a need →
              </Link>
            ) : null}
          </div>
          {filteredNeeds.length === 0 ? (
            <Empty
              text={
                isClient
                  ? "No open jobs yet. Post a job to reach verified freelancers."
                  : "No open jobs match. You can also post a need for peer help."
              }
              ctaHref={
                signedIn
                  ? isClient
                    ? "/app/connect/manage"
                    : isProPlus
                      ? "/app/connect/manage"
                      : "/edition"
                  : isClient
                    ? `/signup?next=${encodeURIComponent("/app/connect/manage")}`
                    : `/signup?next=${encodeURIComponent("/edition")}`
              }
              ctaLabel={
                isClient
                  ? "Post a job (100% Free)"
                  : signedIn && isProPlus
                    ? "Post a need"
                    : `Get Pro Plus · ${site.pricing.proPlusMonthlyLabel}/mo`
              }
            />
          ) : (
            <>
            <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-text-muted">
              <span>
                Showing{" "}
                {Math.min(filteredNeeds.length, (jobsPage - 1) * JOBS_PER_PAGE + 1)}-
                {Math.min(filteredNeeds.length, jobsPage * JOBS_PER_PAGE)} of{" "}
                {filteredNeeds.length} jobs
              </span>
              <span>Page {jobsPage}</span>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {filteredNeeds
                .slice((jobsPage - 1) * JOBS_PER_PAGE, jobsPage * JOBS_PER_PAGE)
                .map((n) => (
                <article
                  key={n.id}
                  className="rounded-2xl border border-border bg-surface p-5 shadow-sm transition hover:border-primary/40 flex flex-col justify-between"
                >
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <div>
                        {n.company_name && (
                          <span className="text-[11px] font-bold text-teal-700 uppercase tracking-wider block mb-0.5">
                            {n.company_name} {n.location ? `· ${n.location}` : ""}
                          </span>
                        )}
                        <h3 className="font-bold text-navy text-base">{n.title || "Job"}</h3>
                      </div>
                      <div className="flex items-center gap-1.5 shrink-0">
                        {n.is_direct_client && (
                          <span className="rounded-lg bg-amber-500/10 border border-amber-500/25 px-2 py-0.5 text-[10px] font-extrabold uppercase text-amber-600">
                            🌟 Direct Client
                          </span>
                        )}
                        <span className="rounded-lg bg-teal-50 border border-teal-200 px-2 py-0.5 text-[10px] font-bold uppercase text-teal-800">
                          {n.job_id ? "$0 Fee" : "Open"}
                        </span>
                      </div>
                    </div>
                    <p
                      className={cn(
                        "mt-2 text-sm text-text-secondary leading-relaxed",
                        expandedId === n.id ? "" : "line-clamp-3",
                      )}
                    >
                      {n.summary || "Details in Connect"}
                    </p>
                    {n.summary && n.summary.length > 140 && (
                      <button
                        type="button"
                        className="mt-1 text-xs font-semibold text-primary hover:underline"
                        onClick={() => setExpandedId(expandedId === n.id ? null : n.id)}
                      >
                        {expandedId === n.id ? "Show less" : "Full description"}
                      </button>
                    )}
                    {n.budget_band && (
                      <p className="mt-2 text-sm font-extrabold text-navy font-mono">
                        Budget: {n.budget_band}
                      </p>
                    )}
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {skillsList(n.skills)
                        .slice(0, 6)
                        .map((s) => (
                          <button
                            key={s}
                            type="button"
                            onClick={() => setSkillFilter(s)}
                            className="rounded-lg bg-background px-2 py-0.5 text-[11px] text-text-secondary hover:bg-primary/10 hover:text-primary-dark"
                          >
                            {s}
                          </button>
                        ))}
                    </div>
                  </div>

                  <div className="mt-5 pt-3 border-t border-slate-100 flex flex-wrap items-center justify-between gap-2">
                    <Link
                      href={
                        n.job_id
                          ? `/app/connect/apply?job_id=${encodeURIComponent(n.job_id)}&mode=proposal`
                          : `/app/connect/apply?needId=${encodeURIComponent(n.id)}&to=${encodeURIComponent(n.client_user_id)}&mode=proposal`
                      }
                      className={cn(
                        "rounded-xl bg-teal-700 hover:bg-teal-800 px-4 py-2 text-xs font-bold text-white shadow-xs transition-colors",
                        n.client_user_id === myUserId && "pointer-events-none opacity-40",
                      )}
                    >
                      {n.job_id ? "Apply ($0 Fee)" : "Apply to Job"}
                    </Link>
                    <button
                      type="button"
                      disabled={bookmarkBusyId === n.id}
                      onClick={() =>
                        void onToggleBookmark({
                          targetId: n.id,
                          targetType: "job",
                          title: n.title || "Job",
                          meta: {
                            budget_band: n.budget_band,
                            client_user_id: n.client_user_id,
                          },
                        })
                      }
                      className={cn(
                        "rounded-xl border px-4 py-2.5 text-sm font-semibold disabled:opacity-60",
                        savedIds.has(n.id)
                          ? "border-primary/30 bg-primary/10 text-primary-dark"
                          : "border-border text-navy",
                      )}
                    >
                      {savedIds.has(n.id) ? "Unsave" : "Save"}
                    </button>
                    {signedIn &&
                      isProPlus &&
                      !isClient &&
                      myUserId &&
                      n.client_user_id !== myUserId && (
                      <Link
                        href={`/app/connect/apply?needId=${encodeURIComponent(n.id)}&to=${encodeURIComponent(n.client_user_id)}&mode=proposal`}
                        className="rounded-xl border border-primary/30 bg-primary/10 px-4 py-2.5 text-sm font-semibold text-primary-dark hover:bg-primary/20"
                      >
                        Submit proposal
                      </Link>
                    )}
                  </div>
                  {signedIn &&
                    isProPlus &&
                    isClient &&
                    myUserId &&
                    n.client_user_id === myUserId && (
                    <ConnectTrust
                      myUserId={myUserId}
                      peerId={n.client_user_id}
                      needId={n.id}
                      mode="jobs"
                    />
                  )}
                </article>
              ))}
            </div>
            {filteredNeeds.length > JOBS_PER_PAGE && (
              <div className="flex flex-wrap items-center justify-center gap-2">
                <button
                  type="button"
                  disabled={jobsPage <= 1}
                  onClick={() => setJobsPage((p) => Math.max(1, p - 1))}
                  className="rounded-xl border border-border px-3 py-2 text-sm font-semibold disabled:opacity-40"
                >
                  Previous
                </button>
                {Array.from({
                  length: Math.min(8, Math.ceil(filteredNeeds.length / JOBS_PER_PAGE)),
                }).map((_, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setJobsPage(i + 1)}
                    className={cn(
                      "h-9 w-9 rounded-xl text-sm font-bold",
                      jobsPage === i + 1
                        ? "bg-primary text-white"
                        : "border border-border text-navy",
                    )}
                  >
                    {i + 1}
                  </button>
                ))}
                <button
                  type="button"
                  disabled={jobsPage >= Math.ceil(filteredNeeds.length / JOBS_PER_PAGE)}
                  onClick={() =>
                    setJobsPage((p) =>
                      Math.min(Math.ceil(filteredNeeds.length / JOBS_PER_PAGE), p + 1),
                    )
                  }
                  className="rounded-xl border border-border px-3 py-2 text-sm font-semibold disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            )}
            </>
          )}
        </section>
      )}

      {tab === "inbox" && (
        <section className="space-y-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 className="font-display text-xl font-extrabold text-navy">Connect inbox</h2>
              <p className="text-sm text-text-secondary">
                Accept to reveal emails. Decline to keep privacy. No escrow claims.
              </p>
            </div>
            {signedIn && requests.length > 0 && (
              <div className="flex flex-wrap gap-1.5">
                {(
                  [
                    { id: "all" as const, label: "All" },
                    { id: "pending" as const, label: "Pending" },
                    { id: "accepted" as const, label: "Accepted" },
                    { id: "declined" as const, label: "Declined" },
                  ] as const
                ).map((f) => (
                  <button
                    key={f.id}
                    type="button"
                    onClick={() => {
                      setInboxFilter(f.id);
                      setInboxVisible(PAGE_SIZE);
                    }}
                    className={cn(
                      "rounded-lg px-2.5 py-1 text-xs font-semibold",
                      inboxFilter === f.id ? chipNavActive : "bg-background text-text-secondary",
                    )}
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            )}
          </div>

          {(error || loadError) && (
            <div
              role="alert"
              className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-900"
            >
              {error || loadError}
            </div>
          )}
          {ok && (
            <div
              role="status"
              className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900"
            >
              {ok}
            </div>
          )}

          {!signedIn ? (
            <Empty
              text="Sign in to see Connect requests."
              ctaHref="/login?next=/connect?tab=inbox"
              ctaLabel="Sign in"
              icon={Inbox}
            />
          ) : filteredInbox.length === 0 ? (
            <Empty
              text={
                inboxFilter === "all"
                  ? "No requests yet. Contact talent or apply to jobs to start."
                  : `No ${inboxFilter} requests.`
              }
              icon={Inbox}
            />
          ) : (
            <>
            <ul className="space-y-3">
              {filteredInbox.slice(0, inboxVisible).map((r) => {
                const incoming = r.to_user_id === myUserId;
                const peerName = incoming ? r.from_name || r.from_email : r.to_name || r.to_email;
                const peerEmail = incoming ? r.from_email : r.to_email;
                const revealed = r.status === "accepted" && r.revealed_at;
                const responding = busyId === r.id;
                return (
                  <li
                    key={r.id}
                    className={cn(
                      "rounded-2xl border bg-surface p-4 shadow-sm transition",
                      r.status === "pending" && incoming
                        ? "border-amber-200 ring-1 ring-amber-100"
                        : "border-border",
                    )}
                  >
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <span
                            className={cn(
                              "rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide",
                              incoming ? "bg-sky-100 text-sky-800" : "bg-violet-100 text-violet-800",
                            )}
                          >
                            {incoming ? "Incoming" : "Outgoing"}
                          </span>
                          <span
                            className={cn(
                              "rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide",
                              r.status === "accepted"
                                ? "bg-emerald-100 text-emerald-800"
                                : r.status === "pending"
                                  ? "bg-amber-100 text-amber-800"
                                  : "bg-slate-100 text-slate-600",
                            )}
                          >
                            {r.status}
                          </span>
                          {r.created_at && (
                            <span className="text-xs text-text-muted">
                              {new Date(r.created_at).toLocaleString()}
                            </span>
                          )}
                        </div>
                        <p className="mt-2 font-bold text-navy">
                          {peerName || "CLIVORA user"}
                        </p>
                        <p className="mt-1 text-sm leading-relaxed text-text-secondary">{r.message}</p>
                        {revealed && peerEmail && (
                          <p className="mt-3 break-all rounded-xl bg-emerald-50 px-3 py-2 text-sm font-semibold text-emerald-900">
                            Contact unlocked: {peerEmail}
                          </p>
                        )}
                        {r.status === "pending" && !incoming && (
                          <p className="mt-2 text-xs text-text-muted">
                            Waiting for them to accept before emails unlock.
                          </p>
                        )}
                      </div>
                      {incoming && r.status === "pending" && (
                        <div className="flex shrink-0 gap-2">
                          <button
                            type="button"
                            disabled={!!busyId}
                            onClick={() => respond(r.id, true)}
                            className="inline-flex items-center gap-1.5 rounded-xl bg-primary px-3 py-2 text-xs font-bold text-white disabled:opacity-60"
                          >
                            {responding ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <Check className="h-3.5 w-3.5" />
                            )}
                            Accept
                          </button>
                          <button
                            type="button"
                            disabled={!!busyId}
                            onClick={() => respond(r.id, false)}
                            className="inline-flex items-center gap-1.5 rounded-xl border border-border bg-white px-3 py-2 text-xs font-bold text-navy disabled:opacity-60"
                          >
                            {responding ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <X className="h-3.5 w-3.5" />
                            )}
                            Decline
                          </button>
                        </div>
                      )}
                    </div>
                    {r.status === "accepted" && myUserId && (
                      <ConnectTrust
                        requestId={r.id}
                        myUserId={myUserId}
                        peerId={incoming ? r.from_user_id : r.to_user_id}
                        needId={r.target_need_id}
                        clientUserId={
                          r.target_need_id
                            ? r.to_user_id
                            : r.target_profile_id
                              ? r.from_user_id
                              : myUserId
                        }
                        freelancerUserId={
                          r.target_need_id
                            ? r.from_user_id
                            : r.target_profile_id
                              ? r.to_user_id
                              : incoming
                                ? r.from_user_id
                                : r.to_user_id
                        }
                        mode="accepted"
                      />
                    )}
                  </li>
                );
              })}
            </ul>
            {filteredInbox.length > inboxVisible && (
              <div className="flex justify-center">
                <button
                  type="button"
                  onClick={() => setInboxVisible((n) => n + PAGE_SIZE)}
                  className="rounded-xl border border-border bg-surface px-4 py-2.5 text-sm font-bold text-navy"
                >
                  Load more ({filteredInbox.length - inboxVisible} left)
                </button>
              </div>
            )}
            </>
          )}
        </section>
      )}

      <div className="rounded-2xl border border-dashed border-navy/20 bg-navy/[0.03] p-5">
        <div className="flex items-start gap-3">
          <Sparkles className="mt-0.5 h-5 w-5 text-primary" />
          <div>
            <p className="font-bold text-navy">Why Connect beats open marketplaces</p>
            <p className="mt-1 text-sm text-text-secondary">
              $0 platform fees on your deals (no Upwork-style Connect tokens), private contact until
              mutual accept, direct invoicing after you match, star ratings on talent cards, and the same CRM
              after you hire. Pro Plus includes monthly Connect credits plus unlimited clients, projects,
              and invoices.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function Empty({
  text,
  ctaHref,
  ctaLabel,
  icon: Icon = Users,
}: {
  text: string;
  ctaHref?: string;
  ctaLabel?: string;
  icon?: typeof Users;
}) {
  return (
    <div className="rounded-2xl border border-dashed border-border bg-surface p-8 text-center">
      <Icon className="mx-auto h-8 w-8 text-text-muted" />
      <p className="mt-3 text-sm text-text-secondary">{text}</p>
      {ctaHref && ctaLabel && (
        <Link
          href={ctaHref}
          className="mt-4 inline-flex rounded-xl bg-amber-500 px-4 py-2.5 text-sm font-bold text-navy"
        >
          {ctaLabel}
        </Link>
      )}
    </div>
  );
}
