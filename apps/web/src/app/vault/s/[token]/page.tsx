import { createClient } from "@/lib/supabase/server";
import { isFeatureEnabled } from "@/lib/feature-flags";
import Link from "next/link";

// Read-only view of a vault share link.
//
// vault_lookup_share_by_token returns nothing for a token that is unknown,
// expired, or out of downloads, and never returns the storage path. Spending a
// download happens on click, in /api/vault/share/[token]/download.

export default async function VaultSharePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  const vaultOn =
    (await isFeatureEnabled("vault_cloud")) || (await isFeatureEnabled("phase5_vault_cloud"));

  if (!vaultOn) {
    return (
      <main className="mx-auto max-w-lg px-4 py-16 text-center">
        <h1 className="text-xl font-extrabold">Vault share unavailable</h1>
        <p className="mt-2 text-sm text-slate-600">Cloud vault sharing is not enabled.</p>
      </main>
    );
  }

  const supabase = await createClient();
  const { data: rows, error } = await supabase.rpc("vault_lookup_share_by_token", {
    p_token: token,
  });
  const link = Array.isArray(rows) ? rows[0] : rows;

  if (error || !link) {
    return (
      <main className="mx-auto max-w-lg px-4 py-16 text-center">
        <h1 className="text-xl font-extrabold">Link unavailable</h1>
        <p className="mt-2 text-sm text-slate-600">
          This share link is invalid, has expired, or has reached its download limit.
        </p>
        <Link href="/" className="mt-6 inline-block text-sm font-bold text-primary underline">
          Back to CLIVORA
        </Link>
      </main>
    );
  }

  const remaining =
    typeof link.max_downloads === "number" &&
    link.max_downloads > 0 &&
    typeof link.download_count === "number"
      ? link.max_downloads - link.download_count
      : null;

  return (
    <main className="mx-auto max-w-lg px-4 py-16">
      <h1 className="text-xl font-extrabold">Shared vault file</h1>
      <p className="mt-2 text-sm text-slate-600">{link.file_name || "File"}</p>
      {link.expires_at ? (
        <p className="mt-1 text-xs text-slate-500">
          Expires {new Date(link.expires_at).toLocaleString()}
        </p>
      ) : null}
      {remaining !== null ? (
        <p className="mt-1 text-xs text-slate-500">
          {remaining} download{remaining === 1 ? "" : "s"} left
        </p>
      ) : null}
      <a
        href={`/api/vault/share/${encodeURIComponent(token)}/download`}
        className="mt-6 inline-flex rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white"
      >
        Download
      </a>
    </main>
  );
}
