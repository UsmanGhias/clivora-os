/**
 * Canonical public origin for auth redirects, OAuth callbacks and links.
 * Set NEXT_PUBLIC_SITE_URL to the address your deployment is served from.
 */
export function getPublicSiteUrl(): string {
  const raw = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  if (raw) {
    const withScheme = raw.startsWith("http") ? raw : `https://${raw}`;
    return withScheme.replace(/\/+$/, "");
  }
  const vercel = process.env.VERCEL_URL?.trim();
  if (vercel) {
    const withScheme = vercel.startsWith("http") ? vercel : `https://${vercel}`;
    return withScheme.replace(/\/+$/, "");
  }
  if (process.env.NODE_ENV === "production") {
    return "https://demo.clivora.io";
  }
  return "http://localhost:3000";
}
