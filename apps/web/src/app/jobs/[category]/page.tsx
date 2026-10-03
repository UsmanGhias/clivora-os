import React from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { site } from "@/lib/site";
import { JobListingCard, type JobCardData } from "@/components/jobs/JobListingCard";
import { ArrowLeft, Building2, Globe } from "lucide-react";
import {
  VALID_CATEGORY_SLUGS,
  formatCategoryTitle,
  getCategoryById,
} from "@/lib/job-categories";
import { JOB_LANGUAGES } from "@/lib/job-languages";

export const revalidate = 3600;

export function generateStaticParams() {
  return VALID_CATEGORY_SLUGS.map((category) => ({ category }));
}

type Props = {
  params: Promise<{ category: string }>;
  searchParams?: Promise<{ lang?: string }>;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { category } = await params;
  if (!VALID_CATEGORY_SLUGS.includes(category)) return {};

  const title = `${formatCategoryTitle(category)} Remote Jobs - $0 Fee | CLIVORA`;
  const description = `Find the best remote ${formatCategoryTitle(category)} jobs. Apply directly with $0 platform fees.`;

  return {
    title,
    description,
    alternates: { canonical: `${site.url}/jobs/${category}` },
    openGraph: { title, description },
  };
}

export default async function CategoryPage({ params, searchParams }: Props) {
  const { category } = await params;
  const sp = searchParams ? await searchParams : undefined;
  const lang = (sp?.lang || "all").toLowerCase();

  if (!VALID_CATEGORY_SLUGS.includes(category)) {
    notFound();
  }

  const supabase = await createClient();
  let query = supabase
    .from("connect_jobs")
    .select("*")
    .eq("is_public", true)
    .eq("status", "published")
    .eq("category", category)
    .order("created_at", { ascending: false });

  if (lang !== "all") {
    query = query.eq("language", lang);
  }

  const { data: jobs } = await query.limit(50);

  const titleName = formatCategoryTitle(category);
  const catObj = getCategoryById(category);
  const jobList = (jobs || []) as JobCardData[];

  return (
    <main className="min-h-screen bg-slate-50/50 py-10">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mb-6">
          <Link
            href="/jobs"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 transition-colors hover:text-teal-700"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to all jobs
          </Link>
        </div>

        <div className="mb-8">
          <h1 className="text-3xl font-extrabold tracking-tight text-slate-900 sm:text-4xl">
            {titleName} Remote Jobs <span className="text-teal-600"> - $0 Fee</span>
          </h1>
          <p className="mt-3 text-base text-slate-600 max-w-3xl">
            {catObj?.description ||
              `Browse remote opportunities in ${titleName}. Apply directly, negotiate privately, and keep 100% of your earnings.`}
          </p>

          {/* Language Division Strip */}
          <div className="mt-6 flex flex-wrap items-center gap-2 rounded-2xl border border-slate-200/90 bg-white p-3 shadow-2xs">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400 pl-1">
              Language Division:
            </span>
            {JOB_LANGUAGES.map((item) => {
              const isSelected = lang === item.code;
              const href =
                item.code === "all"
                  ? `/jobs/${category}`
                  : `/jobs/${category}?lang=${item.code}`;
              return (
                <Link
                  key={item.code}
                  href={href}
                  className={`inline-flex items-center gap-1.5 rounded-xl px-3 py-1 text-xs font-semibold transition-all ${
                    isSelected
                      ? "bg-teal-700 text-white shadow-2xs"
                      : "border border-slate-200 bg-slate-50 text-slate-700 hover:border-teal-300 hover:bg-teal-50"
                  }`}
                >
                  <span>{item.flag}</span>
                  <span>{item.nativeLabel}</span>
                </Link>
              );
            })}
          </div>
        </div>

        <div className="space-y-4">
          {jobList.length > 0 ? (
            jobList.map((job, idx) => (
              <React.Fragment key={job.id}>
                <JobListingCard job={job} isFeatured={idx === 0} />

              </React.Fragment>
            ))
          ) : (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-12 text-center">
              <Building2 className="mx-auto h-10 w-10 text-slate-400" />
              <h3 className="mt-3 text-base font-semibold text-slate-900">
                No {titleName} jobs found in this language
              </h3>
              <p className="mt-1 text-sm text-slate-500">
                Try selecting &quot;All Languages&quot; to see all open positions in this category.
              </p>
              <Link
                href={`/jobs/${category}`}
                className="mt-4 inline-flex items-center gap-1 rounded-xl bg-teal-600 px-4 py-2 text-xs font-semibold text-white hover:bg-teal-700"
              >
                View All {titleName} Jobs
              </Link>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
