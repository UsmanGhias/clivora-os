import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getProfile, isClientAccount } from "@/lib/profile";
import { redirect } from "next/navigation";

/** Client Updates feed, mirrors Flutter /client-activity */
export default async function ActivityPage() {
  const profile = await getProfile();
  if (!isClientAccount(profile)) redirect("/app");

  const supabase = await createClient();
  const uid = profile?.id ?? "";
  let rows: Array<{
    id: string;
    title?: string | null;
    body?: string | null;
    kind?: string | null;
    created_at?: string | null;
    is_read?: boolean | null;
  }> = [];

  try {
    const { data } = await supabase
      .from("notifications")
      .select("id, title, body, kind, created_at, is_read")
      .eq("user_uid", uid)
      .order("created_at", { ascending: false })
      .limit(40);
    if (data) rows = data;
  } catch {
    rows = [];
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-2xl font-extrabold text-navy">Updates</h1>
        <p className="text-sm text-text-secondary">
          Activity from freelancers you work with across messages, projects, and invoices.
        </p>
      </div>

      {rows.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-border bg-client-surface p-8 text-center">
          <p className="font-semibold text-navy">No updates yet</p>
          <p className="mt-2 text-sm text-text-secondary">
            When freelancers share invoices, projects, or messages, they show up here.
          </p>
          <Link href="/app/messages" className="mt-4 inline-block text-sm font-semibold text-client-accent">
            Open messages →
          </Link>
        </div>
      ) : (
        <ul className="space-y-2">
          {rows.map((r) => (
            <li
              key={r.id}
              className={`rounded-xl border px-4 py-3 ${
                r.is_read ? "border-border bg-surface" : "border-client-accent/30 bg-client-surface"
              }`}
            >
              <p className="font-semibold text-navy">{r.title || "Update"}</p>
              <p className="mt-1 text-sm text-text-secondary">{r.body}</p>
              <p className="mt-1 text-xs text-text-muted">
                {r.kind || "info"}
                {r.created_at ? ` · ${new Date(r.created_at).toLocaleString()}` : ""}
              </p>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
