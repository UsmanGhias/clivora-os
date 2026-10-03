import Link from "next/link";
import { marketing } from "@/lib/marketing";
import { site } from "@/lib/site";

export function MarketingFooter() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-slate-200 bg-white">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:grid-cols-2 lg:grid-cols-4">
        <div className="lg:col-span-1">
          <Link href="/" className="inline-flex flex-col">
            <span className="font-display text-xl font-extrabold text-navy">{marketing.brand.name}</span>
            <span className="text-xs font-semibold tracking-widest text-text-secondary">
              {marketing.brand.productLine}
            </span>
          </Link>
          <p className="mt-4 text-sm text-text-secondary">{marketing.footer.blurb}</p>
        </div>
        {Object.entries(marketing.footer.columns).map(([title, links]) => (
          <div key={title}>
            <p className="text-sm font-semibold text-navy">{title}</p>
            <ul className="mt-3 space-y-2">
              {links.map((link) => (
                <li key={link.label}>
                  <Link href={link.href} className="text-sm text-text-secondary hover:text-navy">
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-slate-100 py-6 text-center text-xs text-text-secondary">
        © {year} {site.company.name}. Built on{" "}
        <a href={site.repoUrl} className="underline">
          CLIVORA Community
        </a>
        , licensed under AGPL-3.0.
      </div>
    </footer>
  );
}
