import React from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { site } from "@/lib/site";
import { JobListingCard, type JobCardData } from "@/components/jobs/JobListingCard";
import { Building2 } from "lucide-react";
import {
  VALID_CATEGORY_SLUGS,
  formatCategoryTitle,
} from "@/lib/job-categories";

export const revalidate = 3600;

type Props = {
  params: Promise<{ category: string; skill: string }>;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { category, skill } = await params;
  if (!VALID_CATEGORY_SLUGS.includes(category)) return {};

  const decodedSkill = decodeURIComponent(skill);
  const catTitle = formatCategoryTitle(category);
  const skillTitle = formatCategoryTitle(decodedSkill);

  const title = `Remote ${skillTitle} Jobs in ${catTitle} - $0 Fee | CLIVORA`;
  const description = `Find top remote ${skillTitle} jobs in ${catTitle}. Direct client communication with zero platform fees on CLIVORA.`;

  return {
    title,
    description,
    // Programmatic skill pages repeat one template with a filtered job list; keep them
    // out of the index so the site is judged on its original content.
    robots: { index: false, follow: true },
    alternates: { canonical: `${site.url}/jobs/${category}/${skill}` },
    openGraph: { title, description },
  };
}

export default async function CategorySkillPage({ params }: Props) {
  const { category, skill } = await params;

  if (!VALID_CATEGORY_SLUGS.includes(category)) {
    notFound();
  }

  const decodedSkill = decodeURIComponent(skill);

  const supabase = await createClient();
  const { data: jobs } = await supabase
    .from("connect_jobs")
    .select("*")
    .eq("is_public", true)
    .eq("status", "published")
    .eq("category", category)
    .contains("tags", [decodedSkill])
    .order("created_at", { ascending: false })
    .limit(50);

  const catName = formatCategoryTitle(category);
  const skillName = formatCategoryTitle(decodedSkill);
  const jobList = (jobs || []) as JobCardData[];

  return (
    <main className="min-h-screen bg-slate-50/50 py-10">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="mb-6 flex items-center gap-2 text-xs font-semibold text-slate-500">
          <Link href="/jobs" className="hover:text-teal-700">All Jobs</Link>
          <span>/</span>
          <Link href={`/jobs/${category}`} className="hover:text-teal-700">{catName}</Link>
          <span>/</span>
          <span className="text-slate-900">{skillName}</span>
        </div>

        <div className="mb-8">
          <h1 className="text-3xl font-extrabold tracking-tight text-slate-900 sm:text-4xl">
            Remote {skillName} Jobs <span className="text-teal-600"> - $0 Fee</span>
          </h1>
          <p className="mt-3 text-base text-slate-600">
            Browse remote opportunities for {skillName} specialists in {catName}. Zero commission, direct client contracts.
          </p>
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
              <h3 className="mt-3 text-base font-semibold text-slate-900">No {skillName} jobs found</h3>
              <p className="mt-1 text-sm text-slate-500">
                Explore other skills in {catName} or browse all categories.
              </p>
              <Link
                href={`/jobs/${category}`}
                className="mt-4 inline-flex items-center gap-1 rounded-xl bg-teal-600 px-4 py-2 text-xs font-semibold text-white hover:bg-teal-700"
              >
                Browse {catName}
              </Link>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
