import React, { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { site } from "@/lib/site";
import { cleanText } from "@/lib/clean-text";
import { JobFilterBar } from "@/components/jobs/JobFilterBar";
import { JobListingCard, type JobCardData } from "@/components/jobs/JobListingCard";
import {
  Briefcase,
  Building2,
  Sparkles,
  Plus,
  Search,
} from "lucide-react";

export const metadata: Metadata = {
  title: "Remote Jobs Marketplace - $0 Platform Fee | CLIVORA",
  description:
    "Explore curated remote career opportunities and freelance contracts. Direct client relationships, milestone verification, and $0 platform commissions.",
  alternates: { canonical: `${site.url}/jobs` },
  openGraph: {
    title: "Remote Jobs Marketplace - $0 Platform Fee | CLIVORA",
    description:
      "Explore curated remote opportunities with direct client communication and zero platform fees.",
  },
};

interface SearchParamsProps {
  q?: string;
  lang?: string;
  category?: string;
  tech?: string;
  type?: string;
  page?: string;
}

export default async function JobsIndexPage({
  searchParams,
}: {
  searchParams?: Promise<SearchParamsProps>;
}) {
  const sp = searchParams ? await searchParams : undefined;
  const q = (sp?.q || "").trim();
  const lang = (sp?.lang || "all").toLowerCase();
  const category = sp?.category || "all";
  const tech = (sp?.tech || "all").toLowerCase();
  const jobType = (sp?.type || "all").toLowerCase();
  const page = Math.max(parseInt(sp?.page || "1", 10) || 1, 1);
  const perPage = 20;

  const supabase = await createClient();
  let query = supabase
    .from("connect_jobs")
    .select("*", { count: "exact" })
    .eq("is_public", true)
    .eq("status", "published")
    .order("created_at", { ascending: false });

  if (lang !== "all") {
    query = query.eq("language", lang);
  }

  if (category !== "all") {
    query = query.eq("category", category);
  }

  if (jobType !== "all") {
    query = query.eq("job_type", jobType);
  }

  if (tech !== "all") {
    query = query.contains("tags", [tech]);
  }

  if (q) {
    query = query.or(`title.ilike.%${q}%,description.ilike.%${q}%,company_name.ilike.%${q}%`);
  }

  const { data: jobs, count } = await query.range((page - 1) * perPage, page * perPage - 1);
  const totalJobs = count || 0;
  let jobList = (jobs || []) as JobCardData[];

  // On page 1: Prioritize genuine client-posted jobs at the very top of the board
  if (page === 1) {
    try {
      let clientQuery = supabase
        .from("connect_jobs")
        .select("*")
        .eq("is_public", true)
        .eq("status", "published")
        .or("source.eq.manual,posted_by.not.is.null")
        .order("created_at", { ascending: false })
        .limit(10);

      if (lang !== "all") clientQuery = clientQuery.eq("language", lang);
      if (category !== "all") clientQuery = clientQuery.eq("category", category);

      const { data: clientJobs } = await clientQuery;
      if (clientJobs && clientJobs.length > 0) {
        const clientIds = new Set(clientJobs.map((j) => j.id));
        jobList = [
          ...(clientJobs as JobCardData[]),
          ...jobList.filter((j) => !clientIds.has(j.id)),
        ];
      }
    } catch {
      // fallback cleanly to regular list
    }
  }

  // Ensure any client postings in the current batch sit on top
  jobList.sort((a, b) => {
    const aClient = a.source === "manual" || !!a.posted_by;
    const bClient = b.source === "manual" || !!b.posted_by;
    if (aClient && !bClient) return -1;
    if (!aClient && bClient) return 1;
    return 0;
  });

  // Helper to build pagination URL
  const buildPageUrl = (targetPage: number) => {
    const p = new URLSearchParams();
    if (q) p.set("q", q);
    if (lang !== "all") p.set("lang", lang);
    if (category !== "all") p.set("category", category);
    if (tech !== "all") p.set("tech", tech);
    if (jobType !== "all") p.set("type", jobType);
    p.set("page", String(targetPage));
    return `/jobs?${p.toString()}`;
  };

  return (
    <main className="min-h-screen bg-gradient-to-b from-slate-50 via-white to-slate-50 py-10">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Marketplace Sub-Navigation Bridge */}
        <div className="flex justify-center mb-6">
          <div className="inline-flex flex-wrap items-center justify-center gap-1 rounded-2xl bg-slate-100/90 p-1 border border-slate-200/80 shadow-xs">
            <Link
              href="/jobs"
              className="inline-flex items-center gap-2 rounded-xl bg-white px-4 py-2 text-xs font-bold text-slate-900 shadow-xs"
            >
              <Briefcase className="h-3.5 w-3.5 text-teal-600" />
              Remote Jobs ({totalJobs > 0 ? totalJobs.toLocaleString() : "Thousands"})
            </Link>
            <Link
              href="/connect?tab=talent"
              className="inline-flex items-center gap-2 rounded-xl px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 transition-colors"
            >
              <Building2 className="h-3.5 w-3.5 text-slate-400" />
              Hire Talent
            </Link>
            <Link
              href="/connect"
              className="inline-flex items-center gap-2 rounded-xl px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 transition-colors"
            >
              <Sparkles className="h-3.5 w-3.5 text-teal-500" />
              Connect Hub
            </Link>
            <Link
              href="/app/connect/manage"
              className="inline-flex items-center gap-1.5 rounded-xl bg-teal-600 px-3.5 py-2 text-xs font-bold text-white shadow-xs hover:bg-teal-700 transition-colors"
            >
              <Plus className="h-3.5 w-3.5" />
              Post a Job (Free)
            </Link>
          </div>
        </div>

        {/* Top Announcement Badge */}
        <div className="flex justify-center">
          <div className="inline-flex items-center gap-2 rounded-full border border-teal-200/80 bg-teal-50/90 px-4 py-1.5 text-xs font-semibold text-teal-800 shadow-sm backdrop-blur">
            <Sparkles className="h-3.5 w-3.5 text-teal-600 animate-pulse" />
            <span>FOUNDER LAUNCH: 100% Free Access & $0 Platform Fees</span>
          </div>
        </div>

        {/* Hero Section */}
        <div className="mt-6 text-center">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl lg:text-6xl">
            Browse Remote Jobs <span className="text-teal-600"> - $0 Fee</span>
          </h1>
          <p className="mx-auto mt-4 max-w-2xl text-base sm:text-lg text-slate-600">
            Direct opportunities from high-growth companies and startups worldwide. 
            Negotiate directly, get paid on milestones, and keep 100% of what you earn.
          </p>

          {/* Action CTAs */}
          <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
            <a
              href="#job-search-filters"
              className="inline-flex items-center gap-2 rounded-2xl bg-navy px-6 py-3 text-xs sm:text-sm font-bold text-white shadow-sm hover:bg-navy/90 transition-all active:scale-98"
            >
              <Search className="h-4 w-4 text-teal-400" />
              <span>Browse {totalJobs > 0 ? `${totalJobs.toLocaleString()}+` : ""} Opportunities</span>
            </a>
            <Link
              href="/app/connect/manage"
              className="inline-flex items-center gap-2 rounded-2xl border border-teal-300 bg-teal-50 px-6 py-3 text-xs sm:text-sm font-bold text-teal-900 shadow-xs hover:bg-teal-100 hover:border-teal-400 transition-all active:scale-98"
            >
              <Plus className="h-4 w-4 text-teal-700" />
              <span>Post a Remote Job (Free)</span>
            </Link>
          </div>

          {/* Quick Value Metrics */}
          <div className="mx-auto mt-8 grid max-w-3xl grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-xl border border-slate-200/80 bg-white/80 p-3 shadow-xs backdrop-blur">
              <p className="text-xl font-bold text-slate-900">{totalJobs > 0 ? totalJobs.toLocaleString() : "Thousands"}</p>
              <p className="text-xs font-medium text-slate-500">Active Roles</p>
            </div>
            <div className="rounded-xl border border-teal-200/80 bg-teal-50/60 p-3 shadow-xs">
              <p className="text-xl font-bold text-teal-700">$0</p>
              <p className="text-xs font-medium text-teal-600">Platform Fees</p>
            </div>
            <div className="rounded-xl border border-slate-200/80 bg-white/80 p-3 shadow-xs backdrop-blur">
              <p className="text-xl font-bold text-slate-900">Direct</p>
              <p className="text-xs font-medium text-slate-500">Client Contact</p>
            </div>
            <div className="rounded-xl border border-slate-200/80 bg-white/80 p-3 shadow-xs backdrop-blur">
              <p className="text-xl font-bold text-slate-900">100%</p>
              <p className="text-xs font-medium text-slate-500">You Keep</p>
            </div>
          </div>
        </div>

        {/* Search, Language Division & Rich Filters with Suspense */}
        <div className="mt-10">
          <Suspense fallback={<div className="h-32 rounded-2xl bg-slate-100 animate-pulse" />}>
            <JobFilterBar />
          </Suspense>
        </div>

        {/* Results Header */}
        <div className="mt-8 flex items-center justify-between border-b border-slate-200/80 pb-3">
          <p className="text-sm font-bold text-slate-700">
            Showing {totalJobs.toLocaleString()} {totalJobs === 1 ? "Opportunity" : "Opportunities"}
          </p>
          <span className="text-xs text-slate-500">
            Page {page} of {Math.max(1, Math.ceil(totalJobs / perPage))}
          </span>
        </div>

        {/* Job Listings Grid */}
        <div className="mt-6 space-y-4">
          {jobList.length > 0 ? (
            jobList.map((job, idx) => {
              const isFirstCard = page === 1 && idx === 0;
              return (
                <React.Fragment key={job.id}>
                  {isFirstCard && (
                    <div className="mb-1 flex items-center justify-between">
                      <span className="text-xs font-bold uppercase tracking-wider text-teal-700">
                        Top Spotlight Opportunity (All Information Visible)
                      </span>
                      <span className="text-xs text-slate-500 font-medium">100% Retained Earnings</span>
                    </div>
                  )}
                  <JobListingCard job={job} isFeatured={isFirstCard} />

                </React.Fragment>
              );
            })
          ) : (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center">
              <Building2 className="mx-auto h-10 w-10 text-slate-400" />
              <h3 className="mt-3 text-base font-semibold text-slate-900">No jobs match your filter</h3>
              <p className="mt-1 text-sm text-slate-500">
                Try selecting a different language, clearing tags, or expanding your search terms.
              </p>
              <Link
                href="/jobs"
                className="mt-4 inline-flex items-center gap-1 rounded-xl bg-teal-600 px-4 py-2 text-xs font-semibold text-white hover:bg-teal-700"
              >
                Reset All Filters
              </Link>
            </div>
          )}
        </div>

        {/* Pagination */}
        {totalJobs > perPage && (
          <div className="mt-10 flex justify-center gap-3">
            {page > 1 && (
              <Link
                href={buildPageUrl(page - 1)}
                className="rounded-xl border border-slate-300 bg-white px-5 py-2.5 text-xs font-bold text-slate-700 shadow-2xs hover:bg-slate-50"
              >
                &larr; Previous Page
              </Link>
            )}
            {page * perPage < totalJobs && (
              <Link
                href={buildPageUrl(page + 1)}
                className="rounded-xl border border-teal-600 bg-teal-600 px-5 py-2.5 text-xs font-bold text-white shadow-2xs hover:bg-teal-700"
              >
                Next Page &rarr;
              </Link>
            )}
          </div>
        )}
      </div>
    </main>
  );
}
