import type { Metadata } from "next";
import { LegalPageShell } from "@/components/legal/LegalPageShell";
import { site } from "@/lib/site";

export const metadata: Metadata = { title: "Privacy policy" };

/** Template: operators must replace this page with their own policy before going live. */
export default function PrivacyPage() {
  return (
    <LegalPageShell title="Privacy policy" description={`How ${site.company.name} handles personal data.`} lastUpdated="Template">
      <p>
        <strong>Operators: replace this page</strong> (<code>src/app/privacy/page.tsx</code>) with your own policy
        before opening this deployment to users. CLIVORA is software; the organisation running this deployment is the
        data controller and is responsible for this policy.
      </p>
      <p>A complete policy should state:</p>
      <ul>
        <li>What personal data you collect: account details, client and invoice records, messages and uploaded files.</li>
        <li>Where it is stored: the Supabase project and storage buckets this deployment uses, and their region.</li>
        <li>Who you share it with, including any email, push notification or analytics providers you enable.</li>
        <li>How long you keep it, and how users can export or delete their data.</li>
        <li>How to contact you: {site.company.privacyEmail}.</li>
      </ul>
    </LegalPageShell>
  );
}
