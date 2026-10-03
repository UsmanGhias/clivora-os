import { site } from "@/lib/site";

type NavChild = { label: string; href: string; external?: boolean };
const noChildren: NavChild[] = [];

/** Navigation and footer for the public pages of a CLIVORA Community deployment. */
export const marketing = {
  brand: {
    name: site.name,
    productLine: "FREELANCER OS",
    badge: "Open source · Web + Android",
    tagline: "Run client work from one open-source workspace.",
    description: site.description,
  },
  nav: {
    links: [
      { label: "Main Platform", href: "https://clivora.io", external: true, badge: "clivora.io", children: noChildren },
      { label: "Jobs", href: "/jobs", children: noChildren },
      { label: "Connect", href: "/connect", children: noChildren },
      { label: "Community edition", href: "/edition", children: noChildren },
      { label: "GitHub", href: site.repoUrl, external: true, children: noChildren },
    ],
    cta: { label: "Create account", href: "/signup" },
    login: { label: "Log in", href: "/login" },
    locale: "EN",
  },
  connect: {
    body: "Connect is a private hiring board. Clients post needs, freelancers apply with a cover letter and bid, and contact details are shared only after both sides accept. Once matched, the hire becomes a project with tasks, milestones and invoices.",
    primaryCta: { label: "I want to hire", href: "/signup?role=client&next=/connect" },
    secondaryCta: { label: "I want work", href: "/signup?role=freelancer&next=/connect" },
  },
  footer: {
    blurb: "CLIVORA Community: open-source CRM, projects, invoices, timesheets and private hiring for freelancers and clients. Licensed under AGPL-3.0.",
    columns: {
      Product: [
        { label: "Official Clivora (clivora.io)", href: "https://clivora.io" },
        { label: "Jobs", href: "/jobs" },
        { label: "Connect", href: "/connect" },
        { label: "Sign in", href: "/login" },
      ],
      Project: [
        { label: "Source code", href: site.repoUrl },
        { label: "Community vs Enterprise", href: "/edition" },
        { label: "Report an issue", href: `${site.repoUrl}/issues` },
      ],
      Legal: [
        { label: "Privacy", href: "/privacy" },
        { label: "Terms", href: "/terms" },
      ],
    },
  },
} as const;

export type MarketingConfig = typeof marketing;
