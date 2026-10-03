import type { Metadata } from "next";
import { LegalPageShell } from "@/components/legal/LegalPageShell";
import { site } from "@/lib/site";

export const metadata: Metadata = { title: "Terms of service" };

/** Template: operators must replace this page with their own terms before going live. */
export default function TermsPage() {
  return (
    <LegalPageShell title="Terms of service" description={`Terms for using ${site.name}.`} lastUpdated="Template">
      <p>
        <strong>Operators: replace this page</strong> (<code>src/app/terms/page.tsx</code>) with your own terms before
        opening this deployment to users.
      </p>
      <p>
        The CLIVORA software is licensed under the GNU Affero General Public License v3.0. If you modify it and let
        users interact with it over a network, the licence requires you to offer them the source code of your modified
        version. The source of the unmodified project is at <a href={site.repoUrl}>{site.repoUrl}</a>.
      </p>
    </LegalPageShell>
  );
}
