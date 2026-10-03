import type { Metadata } from "next";
import { LegalPageShell } from "@/components/legal/LegalPageShell";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Community and Enterprise editions",
  description: "What CLIVORA Community includes, and what the Enterprise edition adds.",
};

export default function EditionPage() {
  return (
    <LegalPageShell
      title="Community and Enterprise"
      description="This deployment runs CLIVORA Community, the open-source edition."
      lastUpdated="October 2026"
    >
      <p>
        CLIVORA Community is free and open source under the GNU Affero General Public License v3.0. Every
        feature in it is unlocked: there are no paid tiers, usage limits or upgrade prompts.
      </p>
      <h2>Included in Community</h2>
      <ul>
        <li>Clients and CRM, projects, tasks, milestones and contracts</li>
        <li>Quotes, invoices, recurring invoices, credits, expenses and payment records</li>
        <li>Timesheets, calendar, notes, messages and file vault</li>
        <li>Job board and Connect private hiring, with mutual-accept contact sharing</li>
        <li>Offline-first Android app with durable sync and conflict review</li>
      </ul>
      <h2>Added in Enterprise</h2>
      <ul>
        <li>Admin console: user moderation, platform statistics and API keys</li>
        <li>Billing and subscriptions: payment gateways and app store purchases</li>
        <li>Integrations: ERP sync, automation webhooks and email campaigns</li>
        <li>AI features: statement-of-work generation, proposal drafting and an in-app assistant</li>
      </ul>
      <p>
        Source code, documentation and issue tracking are on{" "}
        <a href={site.repoUrl}>GitHub</a>.
      </p>
    </LegalPageShell>
  );
}
