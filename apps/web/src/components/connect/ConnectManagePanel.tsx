"use client";

import { FormEvent, KeyboardEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  CheckCircle2,
  Lightbulb,
  ListChecks,
  Plus,
  Sparkles,
  Trash2,
  X,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { CONNECT_CREDIT_COSTS, parseConnectCreditError } from "@/lib/connect-credits";
import {
  encodeBioWithMeta,
  parseHourlyFromRateBand,
  parsePortfolioMeta,
  stripPortfolioMeta,
  type PortfolioCertificate,
  type PortfolioProject,
} from "@/lib/connect-portfolio";
import { cn } from "@/lib/utils";
import Link from "next/link";

type ProfileRow = {
  id?: string;
  display_title: string;
  headline: string;
  bio: string;
  skills: string;
  additionalSkills: string;
  rate_band: string;
  hourlyRate: string;
  availability: string;
  location_label: string;
  is_listed: boolean;
  education: string;
  experienceYears: string;
  languages: string;
  projects: PortfolioProject[];
  certificates: PortfolioCertificate[];
  avg_rating?: number;
  review_count?: number;
  profile_completeness?: number;
};

function computeCompleteness(l: ProfileRow): number {
  let score = 0;
  if (l.display_title.trim()) score += 12;
  if (l.headline.trim()) score += 10;
  if (l.bio.trim()) score += 12;
  if (l.skills.split(",").map((s) => s.trim()).filter(Boolean).length > 0) score += 12;
  if (l.additionalSkills.split(",").map((s) => s.trim()).filter(Boolean).length > 0) score += 6;
  if (l.rate_band.trim() || l.hourlyRate.trim()) score += 10;
  if (l.availability.trim()) score += 8;
  if (l.location_label.trim()) score += 8;
  if (l.projects.some((p) => p.title.trim())) score += 10;
  if (l.certificates.some((c) => c.name.trim())) score += 6;
  if (l.education.trim()) score += 6;
  return Math.min(100, score);
}

type NeedRow = {
  id: string;
  title: string;
  summary: string;
  skills: string;
  budget_band: string;
  is_open: boolean;
  moderation_status?: string | null;
};

const BUDGET_OPTIONS = [
  "Under $500",
  "$500-$1,000",
  "$1,000-$2,500",
  "$2,500-$5,000",
  "$5,000+",
  "Hourly / TBD",
];

const SKILL_SUGGESTIONS = [
  "React",
  "Next.js",
  "TypeScript",
  "UI/UX",
  "Mobile",
  "API",
  "WordPress",
  "SEO",
];

function SkillChips({
  value,
  onChange,
  placeholder = "Add a skill and press Enter",
  maxSkills,
  hint,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  maxSkills?: number;
  hint?: string;
}) {
  const skills = value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const [draft, setDraft] = useState("");
  const atMax = maxSkills != null && skills.length >= maxSkills;

  function add(skill: string) {
    const s = skill.trim();
    if (!s || atMax) return;
    if (skills.some((x) => x.toLowerCase() === s.toLowerCase())) {
      setDraft("");
      return;
    }
    onChange([...skills, s].join(", "));
    setDraft("");
  }

  function remove(skill: string) {
    onChange(skills.filter((s) => s !== skill).join(", "));
  }

  function onKey(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      add(draft.replace(/,/g, ""));
    } else if (e.key === "Backspace" && !draft && skills.length) {
      remove(skills[skills.length - 1]);
    }
  }

  return (
    <div>
      <div className="flex flex-wrap gap-1.5 rounded-xl border border-border bg-white px-2 py-2">
        {skills.map((s) => (
          <span
            key={s}
            className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary-dark"
          >
            {s}
            <button type="button" onClick={() => remove(s)} aria-label={`Remove ${s}`}>
              <X className="h-3 w-3" />
            </button>
          </span>
        ))}
        {!atMax && (
          <input
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={onKey}
            placeholder={skills.length ? "Add another…" : placeholder}
            className="min-w-[120px] flex-1 border-0 bg-transparent px-1 py-1 text-sm outline-none"
          />
        )}
      </div>
      {(hint || maxSkills != null) && (
        <p className="mt-1 text-[11px] text-text-muted">
          {hint ||
            (maxSkills != null
              ? `${skills.length}/${maxSkills} verified skills`
              : null)}
        </p>
      )}
      {!atMax && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {SKILL_SUGGESTIONS.filter(
            (s) => !skills.some((x) => x.toLowerCase() === s.toLowerCase()),
          )
            .slice(0, 6)
            .map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => add(s)}
                className="rounded-full border border-dashed border-border px-2.5 py-0.5 text-[11px] font-semibold text-text-secondary hover:border-primary/40 hover:text-primary"
              >
                + {s}
              </button>
            ))}
        </div>
      )}
    </div>
  );
}

function statusPill(n: NeedRow) {
  const mod = (n.moderation_status || "").toLowerCase();
  if (mod === "draft") return { label: "Draft", tone: "gray" as const };
  if (!n.is_open) return { label: "Closed", tone: "amber" as const };
  if (mod === "pending") return { label: "Pending review", tone: "blue" as const };
  if (mod === "rejected") return { label: "Rejected", tone: "red" as const };
  return { label: "Open", tone: "green" as const };
}

const toneClass = {
  gray: "bg-slate-100 text-slate-600",
  amber: "bg-amber-100 text-amber-800",
  blue: "bg-sky-100 text-sky-800",
  red: "bg-red-100 text-red-700",
  green: "bg-emerald-100 text-emerald-800",
};

export function ConnectManagePanel() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [accountType, setAccountType] = useState("freelancer");
  const [plan, setPlan] = useState("free");
  const [restricted, setRestricted] = useState(false);
  const [listing, setListing] = useState<ProfileRow>({
    display_title: "",
    headline: "",
    bio: "",
    skills: "",
    additionalSkills: "",
    rate_band: "",
    hourlyRate: "",
    availability: "Available now",
    location_label: "",
    is_listed: true,
    education: "",
    experienceYears: "",
    languages: "",
    projects: [{ title: "", url: "", description: "" }],
    certificates: [{ name: "", issuer: "", year: "" }],
  });
  const [need, setNeed] = useState({
    title: "",
    summary: "",
    skills: "",
    budget_band: BUDGET_OPTIONS[1],
  });
  const [needs, setNeeds] = useState<NeedRow[]>([]);

  async function reloadNeeds(userId: string) {
    const supabase = createClient();
    const { data: needRows } = await supabase
      .from("connect_need_posts")
      .select("id, title, summary, skills, budget_band, is_open, moderation_status")
      .eq("client_user_id", userId)
      .order("created_at", { ascending: false });
    setNeeds(
      (needRows ?? []).map((n) => ({
        id: n.id,
        title: n.title ?? "",
        summary: n.summary ?? "",
        skills: Array.isArray(n.skills) ? n.skills.join(", ") : String(n.skills ?? ""),
        budget_band: n.budget_band ?? "",
        is_open: !!n.is_open,
        moderation_status: n.moderation_status,
      })),
    );
  }

  useEffect(() => {
    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        router.replace("/login?next=/app/connect/manage");
        return;
      }
      const { data: profile } = await supabase
        .from("profiles")
        .select("account_type, subscription_plan, name, is_blocked, is_restricted")
        .eq("id", user.id)
        .maybeSingle();
      if (profile?.is_blocked) {
        router.replace("/blocked");
        return;
      }
      const p = (profile?.subscription_plan ?? "free").toLowerCase();
      const plus = p === "pro_plus" || p === "plus" || p === "proplus";
      if (!plus) {
        router.replace("/edition");
        return;
      }
      setRestricted(profile?.is_restricted === true);
      setAccountType((profile?.account_type ?? "freelancer").toLowerCase());
      setPlan(profile?.subscription_plan ?? "free");

      const { data: cp } = await supabase
        .from("connect_profiles")
        .select(
          "id, display_title, headline, bio, skills, rate_band, availability, location_label, is_listed, avg_rating, review_count, profile_completeness",
        )
        .eq("user_id", user.id)
        .maybeSingle();
      if (cp) {
        const meta = parsePortfolioMeta(cp.bio);
        const visibleBio = stripPortfolioMeta(cp.bio);
        const skillsArr = Array.isArray(cp.skills)
          ? cp.skills.map(String)
          : String(cp.skills ?? "")
              .split(",")
              .map((s) => s.trim())
              .filter(Boolean);
        const verified = skillsArr.slice(0, 5);
        const leftover = skillsArr.slice(5);
        const hourly =
          meta.hourlyRate != null
            ? String(meta.hourlyRate)
            : String(parseHourlyFromRateBand(cp.rate_band) ?? "");
        setListing({
          id: cp.id,
          display_title: cp.display_title ?? "",
          headline: cp.headline ?? "",
          bio: visibleBio,
          skills: verified.join(", "),
          additionalSkills: [
            ...(meta.additionalSkills ?? []),
            ...leftover,
          ].join(", "),
          rate_band: cp.rate_band ?? "",
          hourlyRate: hourly,
          availability: cp.availability ?? "Available now",
          location_label: cp.location_label ?? "",
          is_listed: !!cp.is_listed,
          education: meta.education ?? "",
          experienceYears:
            meta.experienceYears != null ? String(meta.experienceYears) : "",
          languages: (meta.languages ?? []).join(", "),
          projects:
            meta.projects && meta.projects.length
              ? meta.projects
              : [{ title: "", url: "", description: "" }],
          certificates:
            meta.certificates && meta.certificates.length
              ? meta.certificates
              : [{ name: "", issuer: "", year: "" }],
          avg_rating: Number(cp.avg_rating ?? 0),
          review_count: Number(cp.review_count ?? 0),
          profile_completeness: Number(cp.profile_completeness ?? 0),
        });
      } else if (profile?.name) {
        setListing((s) => ({ ...s, display_title: profile.name as string }));
      }

      await reloadNeeds(user.id);
      setLoading(false);
    })();
  }, [router]);

  async function saveListing(e: FormEvent) {
    e.preventDefault();
    if (restricted) {
      setError("Your account is restricted from publishing.");
      return;
    }
    setSaving(true);
    setError(null);
    setMessage(null);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const skills = listing.skills
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
      .slice(0, 5);
    const additionalSkills = listing.additionalSkills
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    const hourlyNum = Number(listing.hourlyRate.replace(/[^0-9.]/g, "")) || null;
    const rateBand =
      listing.rate_band.trim() ||
      (hourlyNum ? `$${hourlyNum}/hr` : "");
    const bio = encodeBioWithMeta(listing.bio, {
      hourlyRate: hourlyNum,
      additionalSkills,
      projects: listing.projects,
      certificates: listing.certificates,
      languages: listing.languages
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
      education: listing.education,
      experienceYears: Number(listing.experienceYears) || null,
    });
    const payload = {
      user_id: user.id,
      display_title: listing.display_title.trim(),
      headline: listing.headline.trim(),
      bio,
      skills,
      rate_band: rateBand,
      availability: listing.availability.trim(),
      location_label: listing.location_label.trim(),
      is_listed: listing.is_listed,
      account_type: accountType,
      updated_at: new Date().toISOString(),
    };
    const firstPublish = listing.is_listed && !listing.id;
    // Draft upsert first so credit eligibility / PROFILE_INCOMPLETE can resolve
    // before connect_publish_profile spends credits (mobile parity).
    const draftPayload = {
      ...payload,
      is_listed: firstPublish && accountType === "freelancer" ? false : listing.is_listed,
    };
    const { error: draftErr } = listing.id
      ? await supabase.from("connect_profiles").update(draftPayload).eq("id", listing.id)
      : await supabase.from("connect_profiles").upsert(draftPayload, { onConflict: "user_id" });
    if (draftErr) {
      setSaving(false);
      setError(draftErr.message);
      return;
    }
    if (firstPublish && accountType === "freelancer") {
      const { error: rpcErr } = await supabase.rpc("connect_publish_profile", {
        p_headline: listing.headline.trim() || listing.display_title.trim(),
        p_bio: stripPortfolioMeta(bio),
        p_skills: skills,
        p_rate: hourlyNum || Number(String(rateBand).replace(/[^0-9.]/g, "")) || 0,
      });
      if (rpcErr) {
        setSaving(false);
        setError(parseConnectCreditError(rpcErr).message);
        return;
      }
    }
    setSaving(false);
    setMessage(
      firstPublish
        ? `Profile published (−${CONNECT_CREDIT_COSTS.publish_profile} credits). It is now listed on Connect.`
        : "Profile saved. Editing an active listing is free.",
    );
  }

  async function createNeed(asDraft: boolean) {
    if (restricted) {
      setError("Your account is restricted from posting jobs.");
      return;
    }
    if (!need.title.trim() || !need.summary.trim()) {
      setError("Title and summary are required.");
      return;
    }
    const isClientUser = accountType === "client";
    if (!isClientUser && !asDraft) {
      const openCount = needs.filter(
        (n) =>
          n.is_open &&
          (n.moderation_status || "").toLowerCase() !== "draft" &&
          (n.moderation_status || "").toLowerCase() !== "rejected",
      ).length;
      if (openCount >= 1) {
        setError(
          "Freelancers may only have one open need at a time. Close or archive your current need first.",
        );
        return;
      }
    }
    setSaving(true);
    setError(null);
    setMessage(null);
    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return;
    const skills = need.skills
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    if (asDraft) {
      const { error: err } = await supabase.from("connect_need_posts").insert({
        client_user_id: user.id,
        title: need.title.trim(),
        summary: need.summary.trim(),
        skills,
        budget_band: need.budget_band.trim(),
        is_open: false,
        moderation_status: "draft",
      });
      setSaving(false);
      if (err) {
        setError(err.message);
        return;
      }
      setMessage("Draft saved. Publish when you are ready.");
      setNeed({ title: "", summary: "", skills: "", budget_band: BUDGET_OPTIONS[1] });
      await reloadNeeds(user.id);
      return;
    }

    const { error: err } = await supabase.rpc("connect_publish_need", {
      p_title: need.title.trim(),
      p_summary: need.summary.trim(),
      p_skills: skills,
      p_budget_band: need.budget_band.trim(),
    });
    setSaving(false);
    if (err) {
      setError(parseConnectCreditError(err).message);
      return;
    }

    // Direct Job Syndication: Also publish into public connect_jobs with top client priority
    try {
      const cleanTitle = need.title.trim();
      const slugBase = cleanTitle
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, "")
        .replace(/[\s_]+/g, "-")
        .slice(0, 50);
      const seoSlug = `${slugBase}-${user.id.slice(0, 6)}-${Date.now()}`;

      // Extract salary figures from budget band
      let salaryMin: number | null = null;
      let salaryMax: number | null = null;
      const numMatches = need.budget_band.match(/\$?(\d[\d,]*)/g);
      if (numMatches && numMatches.length > 0) {
        salaryMin = parseInt(numMatches[0].replace(/[$,]/g, ""), 10) || null;
        if (numMatches.length > 1) {
          salaryMax = parseInt(numMatches[1].replace(/[$,]/g, ""), 10) || null;
        }
      }

      const { data: prof } = await supabase
        .from("profiles")
        .select("name, company, email")
        .eq("id", user.id)
        .maybeSingle();

      const companyName = prof?.company || prof?.name || (isClientUser ? "Verified Client" : "Clivora Member");

      await supabase.from("connect_jobs").insert({
        title: cleanTitle,
        company_name: companyName,
        company_email: prof?.email || user.email || null,
        description: need.summary.trim(),
        category: "software-development",
        tags: skills.length > 0 ? skills : ["remote"],
        salary_min: salaryMin,
        salary_max: salaryMax,
        currency: "USD",
        location: "Remote",
        job_type: "contract",
        source: "manual",
        source_id: `clivora-post-${user.id.slice(0, 8)}-${Date.now()}`,
        posted_by: user.id,
        seo_slug: seoSlug,
        status: "published",
        is_public: true,
      });
    } catch (e) {
      console.warn("Public job syndication notice:", e);
    }

    setMessage(
      `${accountType === "client" ? "Job" : "Need"} successfully published! It is live on the Remote Jobs board and Connect Marketplace.`,
    );
    setNeed({ title: "", summary: "", skills: "", budget_band: BUDGET_OPTIONS[1] });
    await reloadNeeds(user.id);
  }

  if (loading) {
    return (
      <div className="flex min-h-[40vh] items-center justify-center text-sm text-text-secondary">
        Loading Connect…
      </div>
    );
  }

  const isClient = accountType === "client";
  const postTitle = isClient ? "Post a job" : "Post a need";
  const tips = isClient
    ? [
        "Clear titles get 2× more proposals",
        "List must-have skills as chips",
        "Set a realistic budget band",
        "Save drafts before publishing",
      ]
    : [
        "Describe the help you need clearly",
        "Skills help matching freelancers",
        "Budget sets expectations early",
        "Draft first, publish when ready",
      ];

  return (
    <div className="space-y-6 pb-10">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.14em] text-primary">
            Connect · {isClient ? "Client" : "Freelancer"}
          </p>
          <h1 className="mt-1 font-display text-2xl font-extrabold text-navy sm:text-3xl">
            Manage Connect
          </h1>
          <p className="mt-2 max-w-2xl text-sm text-text-secondary">
            {isClient
              ? "Post jobs, review freelancers, and keep your hiring pipeline moving."
              : "Keep your listing sharp - and post a need when you want peer help. Title, rate, skills, and availability show on the marketplace."}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="rounded-full bg-primary/10 px-3 py-1.5 text-xs font-bold uppercase tracking-wide text-primary">
            {plan}
          </span>
          <Link
            href="/app/connect"
            className="rounded-xl border border-border bg-surface px-3 py-2 text-sm font-semibold text-navy hover:bg-slate-50"
          >
            ← Browse Connect
          </Link>
        </div>
      </div>

      <div className="space-y-8">
        <p className="text-sm text-text-secondary">
          Keep your listing sharp - title, rate, skills, location, and availability show on the
          public marketplace.
        </p>

        {restricted && (
          <p className="rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-900">
            Restricted account: you can view Connect but cannot publish until an admin lifts the
            restriction.
          </p>
        )}

        {!isClient && (
          <form
            onSubmit={saveListing}
            className="space-y-3 rounded-2xl border border-border bg-surface p-5 shadow-sm"
          >
            <h2 className="font-display text-lg font-bold text-navy">Freelancer profile</h2>
            {(() => {
              const pct = computeCompleteness(listing);
              return (
                <div className="rounded-xl bg-background px-3 py-2">
                  <div className="flex items-center justify-between text-xs font-semibold text-navy">
                    <span>Profile completeness · {pct}%</span>
                    <span className="text-text-muted">
                      {(listing.review_count ?? 0) > 0
                        ? `★ ${Number(listing.avg_rating ?? 0).toFixed(1)} (${listing.review_count})`
                        : "No reviews yet"}
                    </span>
                  </div>
                  <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-border">
                    <div
                      className="h-full rounded-full bg-primary transition-all"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })()}
            <input
              required
              placeholder="Display title (e.g. Full-stack developer)"
              value={listing.display_title}
              onChange={(e) => setListing({ ...listing, display_title: e.target.value })}
              className="w-full rounded-xl border border-border px-3 py-2.5"
            />
            <input
              required
              placeholder="Headline"
              value={listing.headline}
              onChange={(e) => setListing({ ...listing, headline: e.target.value })}
              className="w-full rounded-xl border border-border px-3 py-2.5"
            />
            <textarea
              placeholder="Bio - what you deliver, industries, tools"
              value={listing.bio}
              onChange={(e) => setListing({ ...listing, bio: e.target.value })}
              className="w-full rounded-xl border border-border px-3 py-2.5"
              rows={4}
            />
            <div>
              <p className="mb-1.5 text-xs font-semibold uppercase text-text-muted">
                Verified skills (max 5)
              </p>
              <SkillChips
                value={listing.skills}
                onChange={(skills) => setListing({ ...listing, skills })}
                maxSkills={5}
                hint="These are your top marketplace skills - pick carefully."
              />
            </div>
            <div>
              <p className="mb-1.5 text-xs font-semibold uppercase text-text-muted">
                Additional skills
              </p>
              <SkillChips
                value={listing.additionalSkills}
                onChange={(additionalSkills) => setListing({ ...listing, additionalSkills })}
                placeholder="Extra skills (not verified badges)"
              />
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <input
                placeholder="Hourly rate (USD) e.g. 45"
                value={listing.hourlyRate}
                onChange={(e) => setListing({ ...listing, hourlyRate: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
                inputMode="decimal"
              />
              <input
                placeholder="Rate band label (e.g. $40-60/hr)"
                value={listing.rate_band}
                onChange={(e) => setListing({ ...listing, rate_band: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
              />
              <input
                placeholder="Location (e.g. Remote · City)"
                value={listing.location_label}
                onChange={(e) => setListing({ ...listing, location_label: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
              />
              <input
                placeholder="Availability"
                value={listing.availability}
                onChange={(e) => setListing({ ...listing, availability: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
              />
              <input
                placeholder="Years of experience"
                value={listing.experienceYears}
                onChange={(e) => setListing({ ...listing, experienceYears: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
                inputMode="numeric"
              />
              <input
                placeholder="Languages (comma-separated)"
                value={listing.languages}
                onChange={(e) => setListing({ ...listing, languages: e.target.value })}
                className="w-full rounded-xl border border-border px-3 py-2.5"
              />
            </div>
            <input
              placeholder="Education (e.g. BS CS - NUST)"
              value={listing.education}
              onChange={(e) => setListing({ ...listing, education: e.target.value })}
              className="w-full rounded-xl border border-border px-3 py-2.5"
            />

            <div className="space-y-3 rounded-xl border border-dashed border-border bg-background/60 p-4">
              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-bold text-navy">Portfolio projects</p>
                <button
                  type="button"
                  onClick={() =>
                    setListing({
                      ...listing,
                      projects: [
                        ...listing.projects,
                        {
                          title: "",
                          url: "",
                          description: "",
                          coverImage: "",
                          skills: [],
                          completionDate: "",
                          isVerified: false,
                        },
                      ].slice(0, 12),
                    })
                  }
                  className="inline-flex items-center gap-1 text-xs font-semibold text-primary"
                >
                  <Plus className="h-3.5 w-3.5" /> Add project
                </button>
              </div>
              {listing.projects.map((p, i) => (
                <div key={i} className="space-y-2.5 rounded-xl border border-border bg-white p-3.5 shadow-2xs">
                  <div className="flex items-center justify-between gap-2 border-b border-slate-100 pb-2">
                    <span className="text-xs font-bold text-navy">Project #{i + 1}</span>
                    <button
                      type="button"
                      aria-label="Remove project"
                      onClick={() =>
                        setListing({
                          ...listing,
                          projects: listing.projects.filter((_, j) => j !== i),
                        })
                      }
                      className="text-text-muted hover:text-error transition"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>

                  <div className="grid gap-2 sm:grid-cols-2">
                    <input
                      placeholder="Project title *"
                      value={p.title}
                      onChange={(e) => {
                        const projects = [...listing.projects];
                        projects[i] = { ...p, title: e.target.value };
                        setListing({ ...listing, projects });
                      }}
                      className="rounded-lg border border-border px-2.5 py-2 text-sm"
                    />
                    <input
                      placeholder="Live / Demo URL (e.g. https://...)"
                      value={p.url || ""}
                      onChange={(e) => {
                        const projects = [...listing.projects];
                        projects[i] = { ...p, url: e.target.value };
                        setListing({ ...listing, projects });
                      }}
                      className="rounded-lg border border-border px-2.5 py-2 text-sm"
                    />
                  </div>

                  <div className="grid gap-2 sm:grid-cols-2">
                    <input
                      placeholder="Cover Image URL (optional)"
                      value={p.coverImage || ""}
                      onChange={(e) => {
                        const projects = [...listing.projects];
                        projects[i] = { ...p, coverImage: e.target.value };
                        setListing({ ...listing, projects });
                      }}
                      className="rounded-lg border border-border px-2.5 py-2 text-sm"
                    />
                    <input
                      placeholder="Tech Stack / Skills (e.g. Next.js, Postgres)"
                      value={(p.skills || []).join(", ")}
                      onChange={(e) => {
                        const projects = [...listing.projects];
                        projects[i] = {
                          ...p,
                          skills: e.target.value.split(",").map((s) => s.trim()).filter(Boolean),
                        };
                        setListing({ ...listing, projects });
                      }}
                      className="rounded-lg border border-border px-2.5 py-2 text-sm"
                    />
                  </div>

                  <div className="flex flex-wrap items-center gap-4 pt-0.5">
                    <input
                      placeholder="Year (e.g. 2026)"
                      value={p.completionDate || ""}
                      onChange={(e) => {
                        const projects = [...listing.projects];
                        projects[i] = { ...p, completionDate: e.target.value };
                        setListing({ ...listing, projects });
                      }}
                      className="w-36 rounded-lg border border-border px-2.5 py-1.5 text-xs"
                    />
                    <label className="flex items-center gap-1.5 text-xs font-semibold text-text-secondary cursor-pointer">
                      <input
                        type="checkbox"
                        checked={Boolean(p.isVerified)}
                        onChange={(e) => {
                          const projects = [...listing.projects];
                          projects[i] = { ...p, isVerified: e.target.checked };
                          setListing({ ...listing, projects });
                        }}
                        className="rounded border-border text-primary focus:ring-primary h-3.5 w-3.5"
                      />
                      <span>✓ Verified CLIVORA Project</span>
                    </label>
                  </div>

                  <textarea
                    placeholder="Deliverables, business outcome, and architectural role..."
                    value={p.description || ""}
                    onChange={(e) => {
                      const projects = [...listing.projects];
                      projects[i] = { ...p, description: e.target.value };
                      setListing({ ...listing, projects });
                    }}
                    rows={2}
                    className="w-full rounded-lg border border-border px-2.5 py-2 text-sm"
                  />
                </div>
              ))}
            </div>

            <div className="space-y-3 rounded-xl border border-dashed border-border bg-background/60 p-4">
              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-bold text-navy">Certificates</p>
                <button
                  type="button"
                  onClick={() =>
                    setListing({
                      ...listing,
                      certificates: [
                        ...listing.certificates,
                        { name: "", issuer: "", year: "" },
                      ].slice(0, 12),
                    })
                  }
                  className="inline-flex items-center gap-1 text-xs font-semibold text-primary"
                >
                  <Plus className="h-3.5 w-3.5" /> Add certificate
                </button>
              </div>
              {listing.certificates.map((c, i) => (
                <div key={i} className="grid gap-2 sm:grid-cols-[1.2fr_1fr_0.6fr_auto]">
                  <input
                    placeholder="Certificate name"
                    value={c.name}
                    onChange={(e) => {
                      const certificates = [...listing.certificates];
                      certificates[i] = { ...c, name: e.target.value };
                      setListing({ ...listing, certificates });
                    }}
                    className="rounded-lg border border-border px-2.5 py-2 text-sm"
                  />
                  <input
                    placeholder="Issuer"
                    value={c.issuer || ""}
                    onChange={(e) => {
                      const certificates = [...listing.certificates];
                      certificates[i] = { ...c, issuer: e.target.value };
                      setListing({ ...listing, certificates });
                    }}
                    className="rounded-lg border border-border px-2.5 py-2 text-sm"
                  />
                  <input
                    placeholder="Year"
                    value={c.year || ""}
                    onChange={(e) => {
                      const certificates = [...listing.certificates];
                      certificates[i] = { ...c, year: e.target.value };
                      setListing({ ...listing, certificates });
                    }}
                    className="rounded-lg border border-border px-2.5 py-2 text-sm"
                  />
                  <button
                    type="button"
                    aria-label="Remove certificate"
                    onClick={() =>
                      setListing({
                        ...listing,
                        certificates: listing.certificates.filter((_, j) => j !== i),
                      })
                    }
                    className="text-text-muted hover:text-error"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
            </div>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={listing.is_listed}
                onChange={(e) => setListing({ ...listing, is_listed: e.target.checked })}
              />
              Listed publicly
            </label>
            <button
              type="submit"
              disabled={saving || restricted}
              className="rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
            >
              {saving ? "Saving…" : "Save profile"}
            </button>
          </form>
        )}

        {(() => {
          const openNeedCount = needs.filter(
            (n) =>
              n.is_open &&
              (n.moderation_status || "").toLowerCase() !== "draft" &&
              (n.moderation_status || "").toLowerCase() !== "rejected",
          ).length;
          const freelancerNeedBlocked = !isClient && openNeedCount >= 1;
          return (
        <div className="grid gap-6 lg:grid-cols-[1fr_280px]">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              void createNeed(false);
            }}
            className="space-y-4 rounded-2xl border border-border bg-surface p-5 shadow-sm"
          >
            <div className="flex items-start gap-3">
              <span
                className={cn(
                  "flex h-10 w-10 items-center justify-center rounded-xl",
                  isClient ? "bg-slate-100 text-slate-700" : "bg-primary/10 text-primary",
                )}
              >
                <Sparkles className="h-5 w-5" />
              </span>
              <div>
                <h2 className="font-display text-lg font-bold text-navy">{postTitle}</h2>
                <p className="text-sm text-text-secondary">
                  {isClient
                    ? "Reach Pro Plus freelancers on CLIVORA Connect."
                    : freelancerNeedBlocked
                      ? "You already have one open need. Close it before posting another."
                      : "Freelancers may post only one open need at a time."}
                </p>
              </div>
            </div>

            {freelancerNeedBlocked ? (
              <p className="rounded-xl bg-amber-50 px-4 py-3 text-sm text-amber-900">
                Limit reached: close your open need below, then you can post a new one.
              </p>
            ) : (
              <>
            <label className="block text-sm font-semibold text-navy">
              Title
              <input
                required
                placeholder={isClient ? "e.g. Build a Next.js dashboard" : "e.g. Need UI review"}
                value={need.title}
                onChange={(e) => setNeed({ ...need, title: e.target.value })}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
              />
            </label>

            <label className="block text-sm font-semibold text-navy">
              Description
              <textarea
                required
                placeholder="What do you need delivered?"
                value={need.summary}
                onChange={(e) => setNeed({ ...need, summary: e.target.value })}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
                rows={5}
              />
            </label>

            <div>
              <p className="mb-1.5 text-sm font-semibold text-navy">Skills</p>
              <SkillChips
                value={need.skills}
                onChange={(skills) => setNeed({ ...need, skills })}
              />
            </div>

            <label className="block text-sm font-semibold text-navy">
              Budget
              <select
                value={need.budget_band}
                onChange={(e) => setNeed({ ...need, budget_band: e.target.value })}
                className="mt-1 w-full rounded-xl border border-border px-3 py-2.5 font-normal"
              >
                {BUDGET_OPTIONS.map((b) => (
                  <option key={b} value={b}>
                    {b}
                  </option>
                ))}
              </select>
            </label>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                disabled={saving || restricted}
                onClick={() => void createNeed(true)}
                className="rounded-xl border border-border bg-white px-4 py-2.5 text-sm font-semibold text-navy hover:border-primary/40 disabled:opacity-60"
              >
                Save draft
              </button>
              <button
                type="submit"
                disabled={saving || restricted}
                className={cn(
                  "rounded-xl px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60",
                  isClient ? "bg-slate-800 hover:bg-slate-900" : "bg-primary hover:bg-primary-dark",
                )}
              >
                {saving ? "Posting…" : "Publish"}
              </button>
            </div>
              </>
            )}
          </form>

          <aside className="space-y-4">
            <div
              className={cn(
                "rounded-2xl border p-5 shadow-sm",
                isClient
                  ? "border-slate-200 bg-slate-50"
                  : "border-teal-100 bg-gradient-to-br from-teal-50 to-white",
              )}
            >
              <div className="flex items-center gap-2">
                <Lightbulb
                  className={cn("h-5 w-5", isClient ? "text-slate-600" : "text-primary")}
                />
                <h3 className="font-bold text-navy">Tips for better results</h3>
              </div>
              <ul className="mt-3 space-y-2">
                {tips.map((t) => (
                  <li key={t} className="flex items-start gap-2 text-sm text-text-secondary">
                    <CheckCircle2
                      className={cn(
                        "mt-0.5 h-4 w-4 shrink-0",
                        isClient ? "text-slate-500" : "text-primary",
                      )}
                    />
                    {t}
                  </li>
                ))}
              </ul>
            </div>
            <div className="rounded-2xl border border-border bg-surface p-4 text-sm text-text-secondary">
              <p className="flex items-center gap-2 font-semibold text-navy">
                <ListChecks className="h-4 w-4 text-primary" />
                Credit note
              </p>
              <p className="mt-2">
                Publishing costs {CONNECT_CREDIT_COSTS.publish_need} Connect credits. Drafts are
                free.
              </p>
            </div>
          </aside>
        </div>
          );
        })()}

        {needs.length > 0 && (
          <div className="space-y-3">
            <h2 className="font-display text-lg font-bold text-navy">
              {isClient ? "Your posted jobs" : "Your needs"}
            </h2>
            <ul className="space-y-2">
              {needs.map((n) => {
                const pill = statusPill(n);
                return (
                  <li
                    key={n.id}
                    className="rounded-xl border border-border bg-surface px-4 py-3 shadow-sm"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <p className="font-semibold text-navy">{n.title}</p>
                      <span
                        className={cn(
                          "rounded-full px-2.5 py-0.5 text-[10px] font-bold",
                          toneClass[pill.tone],
                        )}
                      >
                        {pill.label}
                      </span>
                    </div>
                    <p className="mt-1 text-sm text-text-secondary line-clamp-2">{n.summary}</p>
                    <div className="mt-2 flex flex-wrap items-center gap-2 text-xs text-text-muted">
                      {n.budget_band && <span>{n.budget_band}</span>}
                      {n.skills && <span>· {n.skills}</span>}
                      {n.is_open && (
                        <button
                          type="button"
                          className="ml-auto rounded-lg border border-border px-2.5 py-1 font-semibold text-navy hover:border-primary/40"
                          onClick={async () => {
                            const supabase = createClient();
                            await supabase
                              .from("connect_need_posts")
                              .update({
                                is_open: false,
                                updated_at: new Date().toISOString(),
                              })
                              .eq("id", n.id);
                            const {
                              data: { user },
                            } = await supabase.auth.getUser();
                            if (user) await reloadNeeds(user.id);
                            setMessage("Need closed. You can post a new one.");
                          }}
                        >
                          Close
                        </button>
                      )}
                      {!n.is_open &&
                        (n.moderation_status || "").toLowerCase() === "draft" && (
                        <button
                          type="button"
                          className="ml-auto rounded-lg bg-primary px-2.5 py-1 font-semibold text-white"
                          onClick={async () => {
                            setSaving(true);
                            setError(null);
                            setMessage(null);
                            const supabase = createClient();
                            const skills = (n.skills || "")
                              .split(",")
                              .map((s) => s.trim())
                              .filter(Boolean);
                            const { error: err } = await supabase.rpc("connect_publish_need", {
                              p_title: n.title,
                              p_summary: n.summary,
                              p_skills: skills,
                              p_budget_band: n.budget_band || "",
                            });
                            setSaving(false);
                            if (err) {
                              setError(parseConnectCreditError(err).message);
                              return;
                            }
                            // Close the draft row so we don't keep two copies
                            await supabase
                              .from("connect_need_posts")
                              .update({
                                moderation_status: "archived",
                                is_open: false,
                                updated_at: new Date().toISOString(),
                              })
                              .eq("id", n.id);
                            const {
                              data: { user },
                            } = await supabase.auth.getUser();
                            if (user) await reloadNeeds(user.id);
                            setMessage(
                              `${isClient ? "Job" : "Need"} published (−${CONNECT_CREDIT_COSTS.publish_need} credits).`,
                            );
                          }}
                        >
                          Publish draft
                        </button>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
          </div>
        )}

        {error && <p className="rounded-lg bg-error/10 px-3 py-2 text-sm text-error">{error}</p>}
        {message && (
          <p className="rounded-lg bg-primary/10 px-3 py-2 text-sm text-primary-dark">{message}</p>
        )}
      </div>
    </div>
  );
}
