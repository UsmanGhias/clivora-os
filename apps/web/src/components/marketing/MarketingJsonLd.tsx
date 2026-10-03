import { site } from "@/lib/site";

/** Structured data for public pages of this deployment. */
export function MarketingJsonLd() {
  const website = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: site.name,
    url: site.url,
    description: site.shortDescription,
  };
  const software = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "CLIVORA Community",
    applicationCategory: "BusinessApplication",
    operatingSystem: "Web, Android",
    license: "https://www.gnu.org/licenses/agpl-3.0.html",
    codeRepository: site.repoUrl,
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  };
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify([website, software]) }}
    />
  );
}
