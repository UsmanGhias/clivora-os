import { getPublicSiteUrl } from "@/lib/site-url";
import { productManifest } from "@/config/product";

/**
 * Identity of this CLIVORA deployment. Set the NEXT_PUBLIC_* variables in
 * .env.local (see .env.example) instead of editing this file.
 */
const contactEmail = process.env.NEXT_PUBLIC_CONTACT_EMAIL || "support@example.com";

export const site = {
  name: process.env.NEXT_PUBLIC_SITE_NAME || "Clivora",
  tagline: "Open-source Freelancer OS",
  shortDescription:
    "Open-source Freelancer OS: clients, projects, invoices, timesheets and private hiring on web and Android.",
  metaDescription:
    "CLIVORA Community is an open-source Freelancer OS for running client work: CRM, projects, milestone invoices, timesheets and a private hiring board, on web and Android.",
  description:
    "CLIVORA Community is an open-source Freelancer OS. Run clients, projects, quotes, milestone invoices and timesheets from one account on web and Android, and hire or get hired on a private board where contact details are shared only after both sides accept.",
  url: getPublicSiteUrl(),
  repoUrl: "https://github.com/UsmanGhias/clivora-os",
  appPackage: "org.codcrafters.clivora.community",
  appVersion: productManifest.versions.android,
  webVersion: productManifest.versions.web,
  company: {
    name: process.env.NEXT_PUBLIC_OPERATOR_NAME || "This CLIVORA deployment",
    url: getPublicSiteUrl(),
    email: contactEmail,
    supportEmail: contactEmail,
    privacyEmail: contactEmail,
    legalEmail: contactEmail,
  },
  /** The Community edition has no paid tiers; kept for components that render plan copy. */
  pricing: {
    proMonthlyUsd: 0,
    proMonthlyLabel: "Free",
    proPlusMonthlyUsd: 0,
    proPlusMonthlyLabel: "Free",
    proListLabel: "Free",
    proPlusListLabel: "Free",
    billingNote: "Community edition: every feature included, no paid tiers.",
    earlyAccessNote: "Every feature is included in the Community edition.",
  },
  freeLimits: {
    clients: Number.POSITIVE_INFINITY,
    projects: Number.POSITIVE_INFINITY,
    invoicesPerMonth: Number.POSITIVE_INFINITY,
    templates: Number.POSITIVE_INFINITY,
    fileVaultMb: Number(process.env.NEXT_PUBLIC_VAULT_LIMIT_MB || 1024),
  },
  proLimits: { fileVaultGb: 5 },
  proPlusLimits: { fileVaultGb: 50 },
  social: { github: "https://github.com/UsmanGhias/clivora-os" },
  playStoreUrl: process.env.NEXT_PUBLIC_PLAY_STORE_URL || "",
  /** Custom scheme handled by Android MainActivity */
  appDeepLinkScheme: "clivora",
  appStoreUrl: "#",
  proCheckoutUrl: "/edition",
} as const;

export const legalLinks = {
  privacy: "/privacy",
  terms: "/terms",
  cookies: "/privacy",
  disclaimer: "/terms",
  sitemap: "/",
  deleteAccount: "/privacy",
  dataSafety: "/privacy",
  support: "/edition",
  about: "/edition",
  contact: "/edition",
} as const;
