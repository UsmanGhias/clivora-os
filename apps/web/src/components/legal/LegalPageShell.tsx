import Link from "next/link";
import { ChevronRight, Home } from "lucide-react";
import { MarketingNav } from "@/components/marketing/MarketingNav";
import { MarketingFooter } from "@/components/marketing/MarketingFooter";
import { site } from "@/lib/site";

interface LegalPageShellProps {
  children: React.ReactNode;
  title: string;
  description?: string;
  lastUpdated?: string;
}

/** Light legal chrome aligned with the marketing site with breadcrumb schema. */
export function LegalPageShell({
  children,
  title,
  description,
  lastUpdated = "September 13, 2026",
}: LegalPageShellProps) {
  const breadcrumbSchema = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        "position": 1,
        name: "Home",
        item: site.url,
      },
      {
        "@type": "ListItem",
        "position": 2,
        name: title,
        item: site.url,
      },
    ],
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-navy">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }}
      />
      <MarketingNav variant="light" />

      <main className="mx-auto max-w-4xl px-6 py-14 lg:py-16">
        <nav
          aria-label="Breadcrumb"
          className="mb-6 flex items-center gap-1.5 text-xs text-slate-500"
        >
          <Link
            href="/"
            className="inline-flex items-center gap-1 transition-colors hover:text-navy"
          >
            <Home className="h-3.5 w-3.5" />
            <span>Home</span>
          </Link>
          <ChevronRight className="h-3 w-3 text-slate-400" />
          <span className="font-semibold text-slate-800">{title}</span>
        </nav>

        <div className="mb-10">
          <p className="text-xs font-bold uppercase tracking-[0.16em] text-primary">
            {site.company.name}
          </p>
          <h1 className="mt-3 font-display text-3xl font-extrabold text-navy sm:text-4xl">
            {title}
          </h1>
          {description ? (
            <p className="mt-3 max-w-2xl text-base leading-relaxed text-slate-600">
              {description}
            </p>
          ) : null}
          <p className="mt-3 text-sm text-slate-400">Last updated: {lastUpdated}</p>
        </div>

        <article className="legal-prose rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-10">
          {children}
        </article>
      </main>

      <MarketingFooter />
    </div>
  );
}
