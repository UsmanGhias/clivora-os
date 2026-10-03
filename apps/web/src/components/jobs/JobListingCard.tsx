"use client";

import { site } from "@/lib/site";
import { useState } from "react";
import Link from "next/link";
import { cleanText } from "@/lib/clean-text";
import { getLanguageBadge } from "@/lib/job-languages";
import { getJobExecutiveSummary } from "@/lib/job-formatter";
import {
  MapPin,
  Clock,
  DollarSign,
  Briefcase,
  ChevronRight,
  ShieldCheck,
  Globe,
  CheckCircle2,
  Share2,
  Check,
  Star,
  ExternalLink,
} from "lucide-react";

export interface JobCardData {
  id: string;
  title: string;
  company_name: string;
  company_domain?: string | null;
  category?: string;
  language?: string | null;
  tags?: string[];
  salary_min?: number | null;
  salary_max?: number | null;
  currency?: string;
  location?: string;
  job_type?: string;
  seo_slug: string;
  created_at: string;
  description?: string;
  source?: string;
  source_url?: string;
  posted_by?: string | null;
}

const EXCLUDED_TAGS = new Set([
  "hackernews",
  "who-is-hiring",
  "arbeitnow",
  "remotive",
  "source",
  "external",
  "others",
  "general",
  "it",
]);

function isValidTag(tag: string): boolean {
  const t = tag.toLowerCase().trim();
  if (t.length < 2 || t.length > 25) return false;
  if (EXCLUDED_TAGS.has(t)) return false;
  if (t.startsWith("dr ") || t.startsWith("sg-") || t.startsWith("siege")) return false;
  if (t.includes("cotation") || t.includes("rifseep") || t.includes("dsda") || t.includes("ccit")) return false;
  if (/^\d+$/.test(t)) return false;
  return true;
}

function formatSalary(min?: number | null, max?: number | null, currency: string = "USD") {
  if (!min && !max) return "Competitive Pay";
  const curr = currency || "USD";
  if (min && !max) return `From ${min.toLocaleString()} ${curr}`;
  if (!min && max) return `Up to ${max.toLocaleString()} ${curr}`;
  return `${min?.toLocaleString()} - ${max?.toLocaleString()} ${curr}`;
}

function getInitials(name: string): string {
  const clean = cleanText(name).trim();
  if (!clean) return "CL";
  const parts = clean.split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return clean.slice(0, 2).toUpperCase();
}

function getAvatarGradient(name: string): string {
  const gradients = [
    "from-teal-500 to-emerald-600",
    "from-blue-600 to-cyan-600",
    "from-indigo-600 to-violet-600",
    "from-slate-700 to-slate-900",
    "from-emerald-600 to-teal-700",
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash += name.charCodeAt(i);
  return gradients[Math.abs(hash) % gradients.length];
}

export function JobListingCard({
  job,
  isFeatured = false,
}: {
  job: JobCardData;
  isFeatured?: boolean;
}) {
  const [copied, setCopied] = useState(false);
  const displayTags = (job.tags || [])
    .filter(isValidTag)
    .slice(0, 5);

  const companyInitials = getInitials(job.company_name);
  const avatarGradient = getAvatarGradient(job.company_name);
  const langBadge = getLanguageBadge(job.language);
  const salaryText = formatSalary(job.salary_min, job.salary_max, job.currency);
  const cleanTitle = cleanText(job.title).replace(/\s*-\s*\d{3,6}$/, "").trim();
  const cleanCompany = cleanText(job.company_name);
  const cleanLocation = cleanText(job.location || "Remote");
  const jobUrl = `${site.url}/jobs/view/${job.seo_slug}`;
  const isDirectClientJob = job.source === "manual" || !!job.posted_by;

  const handleShare = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    const targetUrl = typeof window !== "undefined" ? `${window.location.origin}/jobs/view/${job.seo_slug}` : jobUrl;

    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({
          title: `${cleanTitle} at ${cleanCompany}`,
          text: `Check out this remote opportunity on CLIVORA ($0 Platform Fee): ${cleanTitle} at ${cleanCompany}`,
          url: targetUrl,
        });
        return;
      } catch {
        // Fallback to clipboard if user dismissed or cancelled share dialog
      }
    }

    try {
      await navigator.clipboard.writeText(targetUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback
    }
  };

  return (
    <div
      className={`group relative flex h-full flex-col justify-between gap-5 rounded-2xl border bg-white p-5 sm:p-6 shadow-xs transition-all hover:-translate-y-0.5 hover:shadow-md ${
        isFeatured || isDirectClientJob
          ? "border-teal-500 ring-2 ring-teal-500/20 bg-gradient-to-br from-teal-50/20 via-white to-slate-50/30"
          : "border-slate-200 hover:border-teal-500/80"
      }`}
    >
      <div className="flex flex-col sm:flex-row items-start gap-4">
        {/* Company Initial Avatar */}
        <div
          className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br ${avatarGradient} text-base font-bold text-white shadow-xs`}
        >
          {companyInitials}
        </div>

        <div className="flex-1 space-y-2.5">
          {/* Header row: Title + Language badge + Category badge */}
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/jobs/view/${job.seo_slug}`}
              className="text-base sm:text-lg font-bold text-slate-900 transition-colors group-hover:text-teal-700"
            >
              {cleanTitle}
            </Link>

            {/* Language Badge */}
            <span
              className={`inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-[11px] font-bold ${langBadge.className}`}
              title={`Spoken Language: ${langBadge.label}`}
            >
              <span>{langBadge.flag}</span>
              <span>{langBadge.nativeLabel}</span>
            </span>

            {/* Category */}
            {job.category && (
              <span className="rounded-md bg-slate-100 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-slate-600">
                {job.category.replace("-", " ")}
              </span>
            )}

            {isDirectClientJob && (
              <span className="inline-flex items-center gap-1 rounded-md bg-gradient-to-r from-teal-700 to-emerald-700 px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider text-white shadow-xs">
                <Star className="h-3 w-3 fill-amber-300 text-amber-300" />
                Direct Client Job
              </span>
            )}

            {isFeatured && !isDirectClientJob && (
              <span className="rounded-md bg-teal-600 px-2 py-0.5 text-[10px] font-black uppercase tracking-wider text-white shadow-xs">
                Featured
              </span>
            )}
          </div>

          {/* Company + Domain + Trust */}
          <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-slate-600">
            <span className="font-bold text-slate-900">{cleanCompany}</span>
            {job.company_domain && (
              <>
                <span className="text-slate-300">&bull;</span>
                <span className="font-mono text-slate-500">{job.company_domain}</span>
              </>
            )}
            <span className="text-slate-300">&bull;</span>
            <span className="inline-flex items-center gap-1 text-teal-700 font-semibold">
              <ShieldCheck className="h-3.5 w-3.5 text-teal-600" />
              Verified Deal - $0 Fee
            </span>
          </div>

          {/* Executive Summary */}
          {job.description && (
            <p className="text-xs text-slate-600 line-clamp-2 leading-relaxed">
              {getJobExecutiveSummary(job.description, 170)}
            </p>
          )}

          {/* Meta Information Badges */}
          <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-slate-500">
            <div className="flex items-center gap-1">
              <MapPin className="h-3.5 w-3.5 text-slate-400" />
              <span>{cleanLocation}</span>
            </div>

            <div className="flex items-center gap-1 font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200/60">
              <DollarSign className="h-3.5 w-3.5 text-emerald-600" />
              <span>{salaryText}</span>
            </div>

            {job.job_type && (
              <div className="flex items-center gap-1 capitalize">
                <Briefcase className="h-3.5 w-3.5 text-slate-400" />
                <span>{job.job_type.replace("_", " ")}</span>
              </div>
            )}

            <div className="flex items-center gap-1">
              <Clock className="h-3.5 w-3.5 text-slate-400" />
              <span>{new Date(job.created_at).toLocaleDateString()}</span>
            </div>
          </div>

          {/* Tech stack tags */}
          {displayTags.length > 0 && (
            <div className="flex flex-wrap gap-1.5 pt-0.5">
              {displayTags.map((tag) => (
                <span
                  key={tag}
                  className="rounded-md bg-slate-100 px-2 py-0.5 text-[11px] font-medium text-slate-600"
                >
                  {cleanText(tag)}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Action CTA Row */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-3.5">
        <button
          type="button"
          onClick={handleShare}
          className="inline-flex items-center gap-1.5 rounded-xl border border-slate-200 bg-white px-3.5 py-1.5 text-xs font-bold text-slate-700 shadow-2xs transition-colors hover:bg-slate-50 hover:text-navy hover:border-slate-300 active:scale-95"
          title="Share or copy job link"
        >
          {copied ? (
            <>
              <Check className="h-3.5 w-3.5 text-emerald-600" />
              <span className="text-emerald-700 font-bold">Link Copied!</span>
            </>
          ) : (
            <>
              <Share2 className="h-3.5 w-3.5 text-slate-500" />
              <span>Share</span>
            </>
          )}
        </button>

        <Link
          href={`/jobs/view/${job.seo_slug}`}
          className="inline-flex items-center gap-1.5 rounded-xl bg-teal-600 px-4 py-1.5 text-xs font-bold text-white shadow-2xs transition-all hover:bg-teal-700 active:scale-95"
        >
          <span>View & Apply</span>
          <ChevronRight className="h-3.5 w-3.5" />
        </Link>
      </div>
    </div>
  );
}
