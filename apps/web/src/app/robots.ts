import type { MetadataRoute } from "next";

/**
 * Robots exclusion standard for demo.clivora.io.
 * Completely disallows indexing to prevent duplicate content or search cannibalization
 * with the primary production domain (clivora.io).
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      disallow: "/",
    },
  };
}
