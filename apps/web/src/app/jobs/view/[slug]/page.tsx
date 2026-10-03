import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { site } from "@/lib/site";
import { cleanText } from "@/lib/clean-text";
import { JobStructuredDescription } from "@/components/jobs/JobStructuredDescription";
import { DirectClientContactCard } from "@/components/jobs/DirectClientContactCard";
import { formatGoogleJobsHtml } from "@/lib/job-formatter";
import { getLanguageBadge } from "@/lib/job-languages";
import {
  MapPin,
  Clock,
  DollarSign,
  Briefcase,
  Globe,
  ShieldCheck,
  CheckCircle2,
  Sparkles,
  ArrowLeft,
  Lock,
  Send,
  Building2,
} from "lucide-react";

type Props = {
  params: Promise<{ slug: string }>;
};

const EXCLUDED_TAGS = new Set([
  "hackernews",
  "who-is-hiring",
  "arbeitnow",
  "remotive",
  "source",
  "external",
]);

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const supabase = await createClient();
  const { data: job } = await supabase
    .from("connect_jobs")
    .select("*")
    .eq("seo_slug", slug)
    .single();

  if (!job) return {};

  const cleanJobTitle = cleanText(job.title);
  const cleanCompany = cleanText(job.company_name);
  // Third-party listings indexed from other job boards are not original content and the
  // employer is not on CLIVORA, so they are kept out of search and never claim $0-fee terms.
  const isExternal = Boolean(
    job.source_url || (job.source && job.source !== "client" && job.source !== "clivora"),
  );
  const title = isExternal
    ? `${cleanJobTitle} at ${cleanCompany} | Remote listing`
    : `${cleanJobTitle} at ${cleanCompany} | CLIVORA ($0 Fee)`;
  const description = isExternal
    ? `${cleanJobTitle} at ${cleanCompany}. Remote role listed from an external job board; apply through the employer's own application page.`
    : `Apply directly for ${cleanJobTitle} at ${cleanCompany}. Direct client communication with 100% earnings and $0 platform fees on CLIVORA.`;

  return {
    title,
    description,
    robots: { index: false, follow: false },
    alternates: { canonical: `${site.url}/jobs/view/${slug}` },
    openGraph: {
      title,
      description,
      type: "article",
      publishedTime: job.created_at,
    },
  };
}

function formatSalary(min?: number, max?: number, currency: string = "USD") {
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

export default async function JobViewPage({ params }: Props) {
  const { slug } = await params;

  const supabase = await createClient();
  const { data: job } = await supabase
    .from("connect_jobs")
    .select("*")
    .eq("seo_slug", slug)
    .single();

  if (!job || !job.is_public || job.status !== "published") {
    notFound();
  }

  const cleanJobTitle = cleanText(job.title);
  const cleanCompany = cleanText(job.company_name);
  const cleanLocation = cleanText(job.location || "Remote");
  const cleanDescription = cleanText(job.description);
  const displayTags = (job.tags || [])
    .filter((t: string) => !EXCLUDED_TAGS.has(t.toLowerCase()))
    .slice(0, 8);

  const companyInitials = getInitials(cleanCompany);
  const avatarGradient = getAvatarGradient(cleanCompany);
  const langBadge = getLanguageBadge(job.language);

  // Schema.org JSON-LD for Google Jobs
  const googleDescription = formatGoogleJobsHtml(job.description);
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "JobPosting",
    title: cleanJobTitle,
    description: googleDescription,
    datePosted: job.created_at,
    validThrough: new Date(new Date(job.created_at).getTime() + 60 * 24 * 60 * 60 * 1000).toISOString(),
    employmentType: job.job_type ? (job.job_type === "full_time" ? "FULL_TIME" : job.job_type === "contract" ? "CONTRACTOR" : "PART_TIME") : "FULL_TIME",
    directApply: !(job.source_url || (job.source && job.source !== "client" && job.source !== "clivora")),
    identifier: {
      "@type": "PropertyValue",
      name: cleanCompany || "CLIVORA",
      value: job.id,
    },
    hiringOrganization: {
      "@type": "Organization",
      name: cleanCompany,
      sameAs: job.company_domain ? `https://${cleanText(job.company_domain)}` : undefined,
      logo: `${site.url}/icons/icon-512.png`,
    },
    jobLocation: {
      "@type": "Place",
      address: {
        "@type": "PostalAddress",
        addressLocality: cleanLocation,
        addressCountry: "US",
      },
    },
    applicantLocationRequirements: {
      "@type": "Country",
      name: "Worldwide",
    },
    jobLocationType: "TELECOMMUTE",
    ...(job.salary_min && {
      baseSalary: {
        "@type": "MonetaryAmount",
        currency: job.currency || "USD",
        value: {
          "@type": "QuantitativeValue",
          minValue: job.salary_min,
          ...(job.salary_max && { maxValue: job.salary_max }),
          unitText: "YEAR",
        },
      },
    }),
  };

  const breadcrumbsJsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        position: 1,
        name: "Remote Jobs",
        item: `${site.url}/jobs`,
      },
      {
        "@type": "ListItem",
        position: 2,
        name: job.category || "General",
        item: `${site.url}/jobs/${job.category || "general"}`,
      },
      {
        "@type": "ListItem",
        position: 3,
        name: cleanJobTitle,
        item: `${site.url}/jobs/view/${slug}`,
      },
    ],
  };

  const isExternal = Boolean(job.source_url || (job.source && job.source !== "client" && job.source !== "clivora"));
  const sourceDomain = job.source_url
    ? (() => {
        try {
          return new URL(job.source_url).hostname.replace("www.", "");
        } catch {
          return null;
        }
      })()
    : null;

  return (
    <main className="min-h-screen bg-slate-50/50 py-10">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbsJsonLd) }}
      />

      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        {/* Back navigation */}
        <div className="mb-6">
          <Link
            href="/jobs"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-500 transition-colors hover:text-teal-700"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to all jobs
          </Link>
        </div>

        <div className="grid gap-8 lg:grid-cols-3 lg:gap-10">
          {/* Main Job Body */}
          <div className="space-y-6 lg:col-span-2">
            {/* Header Card */}
            <div className="rounded-3xl border border-slate-200/90 bg-white p-7 shadow-xs">
              <div className="flex flex-col gap-5 sm:flex-row sm:items-start">
                <div
                  className={`flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br ${avatarGradient} text-xl font-bold text-white shadow-sm`}
                >
                  {companyInitials}
                </div>

                <div className="space-y-2.5">
                  <div className="flex flex-wrap items-center gap-2">
                    {isExternal ? (
                      <>
                        <span className="inline-flex items-center gap-1 rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700 border border-slate-200">
                          <Globe className="h-3.5 w-3.5 text-slate-500" />
                          Curated Remote Opportunity {sourceDomain ? `· ${sourceDomain}` : ""}
                        </span>
                        <span className="inline-flex items-center gap-1 rounded-full bg-teal-50 px-3 py-1 text-xs font-bold text-teal-800 border border-teal-200">
                          <Sparkles className="h-3 w-3 text-teal-600" />
                          $0 Platform Fee
                        </span>
                      </>
                    ) : (
                      <>
                        <span className="inline-flex items-center gap-1 rounded-full bg-teal-50 px-3 py-1 text-xs font-bold text-teal-800 border border-teal-200">
                          <Sparkles className="h-3 w-3 text-teal-600" />
                          CLIVORA Client Project
                        </span>
                        <span className="inline-flex items-center gap-1 rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-800 border border-emerald-200">
                          <ShieldCheck className="h-3.5 w-3.5 text-emerald-600" />
                          Direct Client Communication
                        </span>
                      </>
                    )}
                    <span
                      className={`inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs font-bold ${langBadge.className}`}
                      title={`Language: ${langBadge.label}`}
                    >
                      <span>{langBadge.flag}</span>
                      <span>{langBadge.label}</span>
                    </span>
                  </div>

                  <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900">
                    {cleanJobTitle}
                  </h1>

                  <p className="text-base font-semibold text-slate-700">
                    {cleanCompany}
                  </p>

                  <div className="flex flex-wrap items-center gap-x-6 gap-y-2 pt-2 text-xs font-medium text-slate-500">
                    <div className="flex items-center gap-1.5">
                      <MapPin className="h-4 w-4 text-slate-400" />
                      <span>{cleanLocation}</span>
                    </div>
                    <div className="flex items-center gap-1.5 font-bold text-emerald-700">
                      <DollarSign className="h-4 w-4 text-emerald-600" />
                      <span>{formatSalary(job.salary_min, job.salary_max, job.currency)}</span>
                    </div>
                    {job.job_type && (
                      <div className="flex items-center gap-1.5 capitalize">
                        <Briefcase className="h-4 w-4 text-slate-400" />
                        <span>{job.job_type.replace("_", " ")}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-1.5">
                      <Clock className="h-4 w-4 text-slate-400" />
                      <span>Posted {new Date(job.created_at).toLocaleDateString()}</span>
                    </div>
                  </div>

                  {displayTags.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 pt-3">
                      {displayTags.map((tag: string) => (
                        <Link
                          key={tag}
                          href={`/jobs/${job.category}/${tag}`}
                          className="rounded-lg bg-slate-100 px-3 py-1 text-xs font-medium text-slate-600 hover:bg-slate-200 transition-colors"
                        >
                          {cleanText(tag)}
                        </Link>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Provenance Notice */}
            {isExternal ? (
              <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4 text-xs text-slate-600 flex items-start gap-3">
                <Globe className="h-4 w-4 text-slate-500 shrink-0 mt-0.5" />
                <p className="leading-relaxed">
                  <strong>Curated Remote Listing:</strong> This opportunity was indexed from{" "}
                  {sourceDomain ? (
                    <span className="font-semibold text-slate-900">{sourceDomain}</span>
                  ) : (
                    "an official employer career portal"
                  )}
                  . You can submit your proposal directly to the employer or manage the engagement through your free Clivora workspace with $0 platform deal fees.
                </p>
              </div>
            ) : (
              <div className="rounded-2xl border border-teal-200 bg-teal-50/50 p-4 text-xs text-teal-900 flex items-start gap-3">
                <ShieldCheck className="h-4 w-4 text-teal-600 shrink-0 mt-0.5" />
                <p className="leading-relaxed">
                  <strong>CLIVORA Client Project:</strong> This contract is posted by a verified client on the Clivora network. Apply directly inside Clivora, track deliverables with milestones, and keep 100% of your earnings.
                </p>
              </div>
            )}

            {/* Description Sections */}
            <div className="space-y-6">
              <JobStructuredDescription rawDescription={job.description} />
            </div>
          </div>

          {/* Sticky Sidebar */}
          <div className="lg:col-span-1">
            <div className="sticky top-20 space-y-6">
              <DirectClientContactCard
                jobId={job.id}
                jobTitle={cleanJobTitle}
                companyName={cleanCompany}
                companyDomain={job.company_domain}
                companyEmail={job.company_email}
                sourceUrl={job.source_url}
                location={cleanLocation}
                salaryText={formatSalary(job.salary_min, job.salary_max, job.currency)}
              />

            </div>
          </div>
        </div>
      </div>
    </main>
  );
}
